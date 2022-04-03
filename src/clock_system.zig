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
const JsonObject = zecsi.assets.JsonObject;
const GameScoreSystem = @import("game_score_system.zig").GameScoreSystem;
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
    configModTime: i128 = -1,
    config: JsonObject(ClockConfig),

    pub fn init(ecs: *ECS) !Self {
        const ass = ecs.getSystem(AssetSystem).?;
        var system = Self{
            .ecs = ecs,
            .clockBgTex = try ass.loadTexture("assets/images/class/clock_background.png"),
            .clockHandTex = try ass.loadTexture("assets/images/class/clock_hand.png"),
            .config = try ass.loadJsonObject(ClockConfig, "assets/data/clock_config.json"),
        };
        // system.timePassed.time = system.config.get().timeToEnd;
        return system;
    }

    pub fn deinit(_: *Self) void {}

    pub fn update(self: *Self, dt: f32) !void {
        const config = self.checkTimerConfig();
        if (self.timePassed.tick(dt)) {
            log.debug("TIME IS UP", .{});
            self.ecs.getSystem(GameScoreSystem).?.finish();
        }

        self.drawClock(config);
    }

    fn drawClock(self: *Self, config: ClockConfig) void {
        const pos = config.position;
        const rotation = self.timePassed.progress() * 360.0;
        const hand = self.clockHandTex.asset.Texture;
        const t = self.timePassed.progress();
        var size = config.size;
        var handSize = size;

        if (t < 1 and t > config.startStress) {
            const m = std.math;
            handSize = m.clamp(
                m.fabs(m.cos(t * config.stressFreq)) * config.handSizeMax,
                handSize,
                config.handSizeMax,
            );
        } else if (t >= 1) {
            handSize = config.handSizeMax;
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

    fn checkTimerConfig(self: *Self) ClockConfig {
        const config = self.config.get();
        const needsUpdate = self.configModTime != self.config.modTime;
        if (needsUpdate) {
            self.configModTime = self.config.modTime;
            self.timePassed.time = config.timeToEnd;
            self.timePassed.reset();
        }
        return config;
    }
};
