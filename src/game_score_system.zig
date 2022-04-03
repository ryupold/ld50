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
    const Self = @This();
    ecs: *ECS,

    pub fn init(ecs: *ECS) !Self {
        return Self{ .ecs = ecs };
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(_: *Self, _: f32) !void {}

    pub fn finish(_: *Self) void {
        log.info("GAME OVER", .{});
    }
};
