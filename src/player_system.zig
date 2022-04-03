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
const classRoom = @import("class_room_system.zig");
const ClassRoomSystem = classRoom.ClassRoomSystem;
const move = @import("movement_system.zig");
const MovementSystem = move.MovementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

pub const Player = struct {
    isAtHisDesk: bool = true,
    solutionsGathered: u32 = 0,
};

pub const PlayerSystem = struct {
    const Self = @This();
    ecs: *ECS,
    grid: *GridPlacementSystem,
    class: *ClassRoomSystem,
    playerTex: *AssetLink,
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

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, _: f32) !void {
        const goto: ?r.Vector2 =
            if (r.IsMouseButtonDown(0))
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
        const playerTable: *classRoom.StudentTable = self.ecs.getOnePtr(self.class.playerTable, classRoom.StudentTable).?;
        if (mover.currentPos(self.grid).eql(.{
            .x = playerTable.area.x,
            .y = playerTable.area.y + playerTable.area.height - 1,
        }) or mover.currentPos(self.grid).eql(.{
            .x = playerTable.area.x + playerTable.area.width - 1,
            .y = playerTable.area.y + playerTable.area.height - 1,
        })) {
            // mover.currentWorldPos = self.grid.toWorldPosition(.{ .x = playerTable.area.x, .y = playerTable.area.y + 1 });
            player.isAtHisDesk = true;
        } else {
            player.isAtHisDesk = false;
            self.drawPlayer();
        }
    }

    fn drawPlayer(self: *Self) void {
        var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
        const cs = self.grid.cellSize();
        drawTexture(self.playerTex.asset.Texture, .{
            .x = mover.currentWorldPos.x,
            .y = mover.currentWorldPos.y - cs / 2,
            .width = cs * 1,
            .height = cs * 1.5,
        });
    }
};
