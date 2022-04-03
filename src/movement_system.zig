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
                    const currentPos = mover.currentPos(self.grid);
                    var direction = targetF32.sub(mover.currentWorldPos).normalize();
                    var nextCell: GridPosition = self.grid.toGridPosition(
                        mover.currentWorldPos.add(direction.scale(self.grid.cellSize())),
                    );
                    const cellDelta = nextCell.sub(currentPos);
                    nextCell = self.findFreeNextCell(currentPos, cellDelta);

                    direction = self.grid.toWorldPosition(nextCell).sub(mover.currentWorldPos).normalize();

                    mover.currentWorldPos = mover.currentWorldPos
                        .add(
                        direction.scale(std.math.min(dt * mover.speed, distance)),
                    );
                }
            }
        }
    }

    /// not gonna lie, but this is the weirdest path finding i ever implemented but it kinda works
    fn findFreeNextCell(self: *Self, currentPos: GridPosition, delta: GridPosition) GridPosition {
        var fixedDelta = delta;

        if (self.class.roomGrid.contains(currentPos.add(fixedDelta))) {
            fixedDelta = .{ .x = delta.x, .y = 0 };
        }
        if (self.class.roomGrid.contains(currentPos.add(fixedDelta))) {
            fixedDelta = .{ .x = 0, .y = delta.y };
            if (fixedDelta.eql(.{ .x = 0, .y = 0 }))
                fixedDelta = .{ .x = 0, .y = delta.x };
        }
        if (self.class.roomGrid.contains(currentPos.add(fixedDelta))) {
            fixedDelta = .{ .x = delta.x, .y = 0 };
            if (fixedDelta.eql(.{ .x = 0, .y = 0 }))
                fixedDelta = .{ .x = delta.y, .y = 0 };
        }
        if (self.class.roomGrid.contains(currentPos.add(fixedDelta))) {
            // log.debug("cannot go further (staying in {?})", .{currentPos});
            return currentPos;
        }
        return currentPos.add(fixedDelta);
    }
};
