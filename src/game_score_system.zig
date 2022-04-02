const std = @import("std");
const zecsi = @import("zecsi/main.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = zecsi.assets.AssetLink;
const r = zecsi.raylib;

pub const GameScoreSystem = struct {
    ecs: *ECS,

    pub fn init(ecs: *ECS) !@This() {
        return @This(){ .ecs = ecs };
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(_: *@This(), _: f32) !void {}
};
