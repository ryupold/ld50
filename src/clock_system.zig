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
const drawTexture = @import("utils.zig").drawTexture;

pub const ClockConfig = struct {
    position: r.Vector2,
    size: f32,
    handSizeMax: f32,
    startStress: f32,
    stressFreq: f32,
    timeToEnd: f32,
};

pub const ClockSystem = struct {
    const Self = @This();
    ecs: *ECS,
    timePassed: Timer = .{ .time = 0, .repeat = false },
    clockBgTex: *AssetLink,
    clockHandTex: *AssetLink,
    configLink: *AssetLink,
    config: ClockConfig = undefined,

    pub fn init(ecs: *ECS) !Self {
        const ass = ecs.getSystem(AssetSystem).?;
        var system = Self{
            .ecs = ecs,
            .clockBgTex = try ass.loadTexture("assets/images/class/clock_background.png"),
            .clockHandTex = try ass.loadTexture("assets/images/class/clock_hand.png"),
            .configLink = try ass.loadJson("assets/data/clock_config.json"),
        };
        system.config = try system.configLink.asset.Json.as(ClockConfig);
        system.timePassed.time = system.config.timeToEnd;
        return system;
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, dt: f32) !void {
        try self.checkTimerConfig();
        if (self.timePassed.tick(dt)) {
            log.debug("TIME IS UP", .{});
        }

        self.drawClock();
    }

    fn drawClock(self: *Self) void {
        const pos = self.config.position;
        const rotation = self.timePassed.progress() * 360.0;
        const hand = self.clockHandTex.asset.Texture;
        const t = self.timePassed.progress();
        var size = self.config.size;
        var handSize = size;

        if (t < 1 and t > self.config.startStress) {
            const m = std.math;
            handSize = m.clamp(
                m.fabs(m.cos(t * self.config.stressFreq)) * self.config.handSizeMax,
                handSize,
                self.config.handSizeMax,
            );
        } else if (t >= 1) {
            handSize = self.config.handSizeMax;
        }

        const handTint = if (t < 0.33)
            r.WHITE.lerp(r.GREEN, t * 3)
        else if (t < 0.66)
            r.GREEN.lerp(r.ORANGE, (t - 0.33) * 3)
        else
            r.ORANGE.lerp(r.RED, (t - 0.66) * 3);

        const dest: r.Rectangle = .{
            .x = pos.x,
            .y = pos.y,
            .width = size,
            .height = size,
        };
        drawTexture(self.clockBgTex.asset.Texture, dest);
        const srcW = @intToFloat(f32, hand.width);
        const srcH = @intToFloat(f32, hand.height);
        r.DrawTexturePro(
            hand,
            .{
                .x = 0,
                .y = 0,
                .width = srcW,
                .height = srcH,
            },
            .{
                .x = pos.x,
                .y = pos.y,
                .width = handSize,
                .height = handSize,
            },
            .{ .x = handSize / 2, .y = handSize / 2 },
            rotation,
            handTint,
        );
    }

    fn checkTimerConfig(self: *Self) !void {
        const needsUpdate = try self.configLink.check();
        if (needsUpdate) {
            self.config = self.configLink.asset.Json.as(ClockConfig) catch |err| {
                log.err("cannot load clock config: {?}", .{err});
                return;
            };
            self.timePassed.time = self.config.timeToEnd;
            self.timePassed.reset();
        }
    }
};
