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
const move = @import("movement_system.zig");
const MovementSystem = move.MovementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

pub const Player = struct {
    solutionsGathered: u32 = 0,
};

pub const PlayerSystem = struct {
    const Self = @This();
    ecs: *ECS,
    grid: *GridPlacementSystem,
    playerTex: *AssetLink,
    player: EntityID,
    previousTouchCount: i32 = 0,

    pub fn init(ecs: *ECS) !Self {
        var ass = ecs.getSystem(AssetSystem).?;

        var system = Self{
            .ecs = ecs,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .playerTex = try ass.loadTexture("assets/images/class/player.png"),
            .player = (try ecs.createEmpty()).id,
        };

        _ = try ecs.add(system.player, Player{});
        _ = try ecs.add(system.player, move.GridMover{ .currentWorldPos = r.Vector2.zero() });

        return system;
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, _: f32) !void {
        // self.updatePlayerPos();
        self.drawPlayer();

        const goto: ?r.Vector2 =
            if (r.IsMouseButtonDown(0))
            r.GetMousePosition()
        else if (r.GetTouchPointCount() == 1)
            r.GetTouchPosition(0)
        else
            null;

        if (goto) |target| {
            var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
            const clickPos = self.ecs.getSystem(CameraSystem).?.screenToWorld(target);
            mover.target = self.grid.toGridPosition(clickPos);
            // log.debug("MOVER, goto: {?}", .{mover.target});
        }

        self.previousTouchCount = r.GetTouchPointCount();
    }

    fn drawPlayer(self: *Self) void {
        var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;
        const cs = self.grid.cellSize();
        drawTexture(self.playerTex.asset.Texture, .{
            .x = mover.currentWorldPos.x,
            .y = mover.currentWorldPos.y,
            .width = cs,
            .height = cs,
        });
    }

    fn updatePlayerPos(self: *Self) void {
        // var player: *Player = self.ecs.getOnePtr(self.player, Player).?;
        // var mover: *move.GridMover = self.ecs.getOnePtr(self.player, move.GridMover).?;

        _ = self;
    }
};
