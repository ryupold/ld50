const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const GridPosition = zecsi.baseSystems.GridPosition;
const GridPlacementSystem = zecsi.baseSystems.GridPlacementSystem;
const classRoom = @import("class_room_system.zig");
const ClassRoomSystem = classRoom.ClassRoomSystem;
const move = @import("movement_system.zig");
const MovementSystem = move.MovementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

pub const questionCount: u32 = 7;

pub const Player = struct {
    gatheringInfo: Timer = .{ .repeat = false, .time = 5 },
    isAtHisDesk: bool = true,
    solutionsGathered: u32 = 0,
    solutionsWrittenDown: u32 = 0,
};

pub const PlayerSystem = struct {
    const Self = @This();
    ecs: *ECS,
    grid: *GridPlacementSystem,
    class: *ClassRoomSystem,
    playerTex: *AssetLink,
    gatheredSolutionsFrom: [1000]bool = [_]bool{false} ** 1000,
    player: EntityID,

    pub fn init(ecs: *ECS) !Self {
        var ass = ecs.getSystem(AssetSystem).?;

        var system = Self{
            .ecs = ecs,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .class = ecs.getSystem(ClassRoomSystem).?,
            .playerTex = try ass.loadTexture("assets/images/class/player.png"),
            .player = (try ecs.createEmpty()).id,
        };
        system.class.player = system.player;

        _ = try ecs.add(system.player, Player{});
        _ = try ecs.add(system.player, move.GridMover{ .currentWorldPos = r.Vector2.zero() });

        return system;
    }

    pub fn resetSystem(self: *Self) !void {
        self.ecs.getOnePtr(self.player, Player).?.* = .{};
        for(self.gatheredSolutionsFrom) |_, i| {
            self.gatheredSolutionsFrom[i] = false;
        }
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, dt: f32) !void {
        const goto: ?r.Vector2 =
            if (r.IsMouseButtonDown(.MOUSE_BUTTON_LEFT))
            r.GetMousePosition()
        else if (r.GetTouchPointCount() == 1)
            r.GetTouchPosition(0)
        else
            null;

        var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
        var player: *Player = self.ecs.getOnePtr(self.player, Player).?;
        if (goto) |target| {
            const clickPos = self.ecs.getSystem(CameraSystem).?.screenToWorld(target);
            mover.target = self.grid.toGridPosition(clickPos);
        }

        if (self.isPlayerAtHisTable()) {
            player.isAtHisDesk = true;
            if (player.solutionsGathered > 0) {
                player.solutionsWrittenDown += player.solutionsGathered;
                player.solutionsGathered = 0;
                log.debug("Written down: {d}", .{player.solutionsWrittenDown});
                if (player.solutionsWrittenDown == questionCount) {
                    self.ecs.getSystem(@import("game_score_system.zig").GameScoreSystem).?.finish(.complete);
                }
            }
        } else {
            player.isAtHisDesk = false;
            self.drawPlayer();

            const isAtStudentsTable = self.class.isAtStudentsTable(mover.currentPos(self.grid));
            if (isAtStudentsTable != null and !self.gatheredSolutionsFrom[isAtStudentsTable.?] and (player.solutionsGathered + player.solutionsWrittenDown) < questionCount) {
                if (player.gatheringInfo.tick(dt)) {
                    player.solutionsGathered = std.math.clamp(player.solutionsGathered + 1, 0, questionCount - player.solutionsWrittenDown);
                    self.gatheredSolutionsFrom[isAtStudentsTable.?] = true;
                    player.gatheringInfo.reset();
                    log.debug("Solutions gathered: {d}", .{player.solutionsGathered});
                }
                self.drawGatherInfoProgressbar(mover.currentWorldPos, player.gatheringInfo.progress());
            }
        }
    }

    fn drawGatherInfoProgressbar(_: *Self, playerPos: r.Vector2, progress: f32) void {
        const w: f32 = 30;
        const h: f32 = 15;
        _ = progress;

        r.DrawRectanglePro(.{
            .x = playerPos.x,
            .y = playerPos.y,
            .width = w,
            .height = h,
        }, r.Vector2{ .x = w / 2, .y = h * 4 }, 0, r.BLUE.set(.{ .a = 80 }));
        r.DrawRectanglePro(
            .{
                .x = playerPos.x,
                .y = playerPos.y,
                .width = w * progress,
                .height = h,
            },
            r.Vector2{ .x = w / 2, .y = h * 4 },
            0,
            r.YELLOW.set(.{ .a = 100 + @floatToInt(u8, progress * 100) }),
        );
    }

    fn isPlayerAtHisTable(self: *Self) bool {
        var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
        const playerTable: *classRoom.StudentTable = self.ecs.getOnePtr(self.class.playerTable, classRoom.StudentTable).?;
        if (mover.currentPos(self.grid).eql(.{
            .x = playerTable.area.x,
            .y = playerTable.area.y + playerTable.area.height - 1,
        }) or mover.currentPos(self.grid).eql(.{
            .x = playerTable.area.x + playerTable.area.width - 1,
            .y = playerTable.area.y + playerTable.area.height - 1,
        })) {
            return true;
        }
        return false;
    }

    fn drawPlayer(self: *Self) void {
        var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
        const cs = self.grid.cellSize();
        drawTexture(self.playerTex.asset.Texture2D, .{
            .x = mover.currentWorldPos.x,
            .y = mover.currentWorldPos.y - cs / 2,
            .width = cs * 1,
            .height = cs * 1.5,
        });
    }
};
