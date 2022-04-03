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
const move = @import("movement_system.zig");
const MovementSystem = move.MovementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

var random = std.rand.DefaultPrng.init(0);
const rng = random.random();

pub const Teacher = struct {
    nextCell: ?GridPosition = null,
    thinking: Timer = .{ .repeat = true, .time = 3 },
};

pub const TeacherSystem = struct {
    const Self = @This();
    ecs: *ECS,
    grid: *GridPlacementSystem,
    class: *ClassRoomSystem,
    teacherTex: *AssetLink,
    teacher: EntityID,

    pub fn init(ecs: *ECS) !Self {
        var ass = ecs.getSystem(AssetSystem).?;

        var system = Self{
            .ecs = ecs,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .class = ecs.getSystem(ClassRoomSystem).?,
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

        if (teacher.thinking.tick(dt)) {
            const gridPos = mover.currentPos(self.grid);
            mover.target = self.findNextFreeCell(gridPos, 4);
            log.debug("TEACHER, goto: {?}", .{mover.target});
        }
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
        var mover: *move.GridMover = self.ecs.getOnePtr(self.teacher, move.GridMover).?;
        const cs = self.grid.cellSize();
        drawTexture(self.teacherTex.asset.Texture, .{
            .x = mover.currentWorldPos.x,
            .y = mover.currentWorldPos.y,
            .width = cs,
            .height = cs,
        });
    }
};
