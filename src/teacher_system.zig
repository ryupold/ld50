const std = @import("std");
const zecsi = @import("zecsi/main.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const GridPosition = zecsi.baseSystems.GridPosition;
const GridPlacementSystem = zecsi.baseSystems.GridPlacementSystem;
const ClassRoomSystem = @import("class_room_system.zig").ClassRoomSystem;
const PlayerSystem = @import("player_system.zig").PlayerSystem;
const move = @import("movement_system.zig");
const MovementSystem = move.MovementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

var random = std.rand.DefaultPrng.init(1337);
const rng = random.random();

pub const LookDirection = enum { up, down, left, right };

pub const TeacherCone = struct {
    p0: r.Vector2 = r.Vector2.zero(),
    p1: r.Vector2 = r.Vector2.zero(),
    p2: r.Vector2 = r.Vector2.zero(),

    fn sees(self: @This(), origin: r.Vector2, p: r.Vector2) bool {
        const p0 = origin.add(self.p0);
        const p1 = origin.add(self.p1);
        const p2 = origin.add(self.p2);

        var s = (p0.x - p2.x) * (p.y - p2.y) - (p0.y - p2.y) * (p.x - p2.x);
        var t = (p1.x - p0.x) * (p.y - p0.y) - (p1.y - p0.y) * (p.x - p0.x);

        if ((s < 0) != (t < 0) and s != 0 and t != 0)
            return false;

        var d = (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x);
        return d == 0 or (d < 0) == (s + t <= 0);
    }
};

pub const Teacher = struct {
    alertness: f32 = 0,
    cone: TeacherCone = .{},
    looking: LookDirection = .down,
    nextCell: ?GridPosition = null,
    thinking: Timer = .{ .repeat = true, .time = 1 },
};

pub const TeacherSystem = struct {
    const Self = @This();
    ecs: *ECS,
    grid: *GridPlacementSystem,
    class: *ClassRoomSystem,
    playerSystem: *PlayerSystem,
    teacherTex: *AssetLink,
    teacher: EntityID,

    pub fn init(ecs: *ECS) !Self {
        var ass = ecs.getSystem(AssetSystem).?;

        var system = Self{
            .ecs = ecs,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .class = ecs.getSystem(ClassRoomSystem).?,
            .playerSystem = ecs.getSystem(PlayerSystem).?,
            .teacherTex = try ass.loadTexture("assets/images/class/teacher.png"),
            .teacher = (try ecs.createEmpty()).id,
        };

        _ = try ecs.add(system.teacher, Teacher{});
        _ = try ecs.add(system.teacher, move.GridMover{ .currentWorldPos = r.Vector2.zero() });

        return system;
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, dt: f32) !void {
        self.drawTeacher();

        var teacher: *Teacher = self.ecs.getOnePtr(self.teacher, Teacher).?;
        var mover: *move.GridMover = self.ecs.getOnePtr(self.teacher, move.GridMover).?;
        const seesPlayer = self.detectPlayer(dt);
        if (seesPlayer) {
            teacher.nextCell = null;
            mover.target = null;
        }

        if (teacher.thinking.tick(dt) and teacher.alertness == 0) {
            const gridPos = mover.currentPos(self.grid);
            mover.target = self.findNextFreeCell(gridPos, 4);
            if (mover.target) |target| {
                const delta = target.sub(gridPos);
                if (delta.x < 0) {
                    teacher.looking = .left;
                } else if (delta.x > 0) {
                    teacher.looking = .right;
                } else if (delta.y < 0) {
                    teacher.looking = .up;
                } else {
                    teacher.looking = .down;
                }
            }
            log.debug("TEACHER, goto: {?}", .{teacher.looking});
        }

        self.updateTeacherCone();
    }

    fn detectPlayer(self: *Self, dt: f32) bool {
        var teacher: *Teacher = self.ecs.getOnePtr(self.teacher, Teacher).?;
        var teacherMover: *move.GridMover = self.ecs.getOnePtr(self.teacher, move.GridMover).?;
        const player: *move.GridMover = self.ecs.getOnePtr(self.playerSystem.player, move.GridMover).?;

        const seesPlayer = teacher.cone.sees(
            teacherMover.currentWorldPos,
            player.currentWorldPos,
        );

        teacher.alertness = std.math.clamp(teacher.alertness + (if (seesPlayer) dt else -dt / 4), 0, 1);

        return seesPlayer;
    }

    fn updateTeacherCone(self: *Self) void {
        var teacher: *Teacher = self.ecs.getOnePtr(self.teacher, Teacher).?;
        //calc teacher cone
        const coneLength = 250;
        const arc = 270;
        const p1 = r.Vector2.zero();
        var p2 = r.Vector2.zero();
        var p3 = r.Vector2.zero();
        switch (teacher.looking) {
            .left => {
                p2 = .{ .x = -coneLength, .y = -arc / 2 };
                p3 = .{ .x = -coneLength, .y = arc / 2 };
            },
            .right => {
                p2 = .{ .x = coneLength, .y = arc / 2 };
                p3 = .{ .x = coneLength, .y = -arc / 2 };
            },
            .up => {
                p2 = .{ .x = arc / 2, .y = -coneLength };
                p3 = .{ .x = -arc / 2, .y = -coneLength };
            },
            .down => {
                p2 = .{ .x = -arc / 2, .y = coneLength };
                p3 = .{ .x = arc / 2, .y = coneLength };
            },
        }
        teacher.cone.p0 = p1;
        teacher.cone.p1 = p2;
        teacher.cone.p2 = p3;
    }

    fn findNextFreeCell(self: *Self, current: GridPosition, tryTimes: usize) ?GridPosition {
        const neighbours = current.crossNeigbours();

        var index = rng.intRangeLessThan(usize, 0, neighbours.len);
        var i: usize = 0;
        while (i < tryTimes) : (i += 1) {
            if (!self.class.roomGrid.contains(neighbours[index]))
                return neighbours[index];
            index = rng.intRangeLessThan(usize, 0, neighbours.len);
        }
        return null;
    }

    fn drawTeacher(self: *Self) void {
        var teacher: *Teacher = self.ecs.getOnePtr(self.teacher, Teacher).?;
        var mover: *move.GridMover = self.ecs.getOnePtr(self.teacher, move.GridMover).?;
        const cs = self.grid.cellSize();
        r.DrawTriangle(
            mover.currentWorldPos.add(teacher.cone.p0),
            mover.currentWorldPos.add(teacher.cone.p1),
            mover.currentWorldPos.add(teacher.cone.p2),
            (r.YELLOW.set(.{ .a = 30 }).lerp(r.RED.set(.{ .a = 50 }), teacher.alertness)),
        );

        drawTexture(self.teacherTex.asset.Texture, .{
            .x = mover.currentWorldPos.x,
            .y = mover.currentWorldPos.y,
            .width = cs,
            .height = cs,
        });
    }

    fn pointInsideTriangle(p: r.Vector2, p0: r.Vector2, p1: r.Vector2, p2: r.Vector2) bool {
        var s = (p0.x - p2.x) * (p.y - p2.y) - (p0.y - p2.y) * (p.x - p2.x);
        var t = (p1.x - p0.x) * (p.y - p0.y) - (p1.y - p0.y) * (p.x - p0.x);

        if ((s < 0) != (t < 0) and s != 0 and t != 0)
            return false;

        var d = (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x);
        return d == 0 or (d < 0) == (s + t <= 0);
    }
};
