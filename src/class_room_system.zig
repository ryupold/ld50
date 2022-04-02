const zecsi = @import("zecsi/main.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const r = zecsi.raylib;

pub const ClassRoomSystem = struct {
    ecs: *ECS,
    camera: ?*CameraSystem,
    assets: ?*AssetSystem,

    pub fn init(ecs: *ECS) !@This() {
        var system = @This(){
            .ecs = ecs,
            .assets = ecs.getSystem(AssetSystem),
            .camera = ecs.getSystem(CameraSystem),
        };

        return system;
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(_: *@This(), _: f32) !void {
        r.DrawText("LD #50", -80, 0, 50, r.RED);
    }
};
