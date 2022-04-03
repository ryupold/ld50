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
const r = zecsi.raylib;

pub const GridMover = struct {
    speed: f32 = 100,
    target: ?GridPosition = null,
    currentWorldPos: r.Vector2 = r.Vector2.zero(),

    pub fn currentPos(self: @This(), grid: *GridPlacementSystem) GridPosition {
        return grid.toGridPosition(self.currentWorldPos);
    }
};

pub const MovementSystem = struct {
    const Self = @This();
    pub const tolerance: f32 = 0.01;

    ecs: *ECS,
    grid: *GridPlacementSystem,
    class: *ClassRoomSystem,

    pub fn init(ecs: *ECS) !Self {
        var system = Self{
            .ecs = ecs,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .class = ecs.getSystem(ClassRoomSystem).?,
        };
        return system;
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, dt: f32) !void {
        var it = self.ecs.query(.{GridMover});
        while (it.next()) |e| {
            var mover: *GridMover = e.getData(self.ecs, GridMover).?;
            if (mover.target) |target| {
                const targetF32 = self.grid.toWorldPosition(target);
                const distance = mover.currentWorldPos.distanceTo(targetF32);
                if (distance <= tolerance) {
                    log.debug("target {?} reached at {?}", .{ mover.target, mover.currentWorldPos });
                    mover.target = null;
                } else {
                    mover.currentWorldPos = mover.currentWorldPos
                        .add(
                        targetF32
                            .sub(mover.currentWorldPos)
                            .normalize().scale(std.math.min(dt * mover.speed, distance)),
                    );
                }
            }
        }
    }
};
