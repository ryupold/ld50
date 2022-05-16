const std = @import("std");
const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const AssetLink = zecsi.assets.AssetLink;
const r = zecsi.raylib;
const player = @import("player_system.zig");

pub const Ending = enum { disqualified, timeIsUp, complete };

pub fn isGameOver(ecs: *ECS) bool {
    return ecs.getSystem(GameScoreSystem).?.gameOver;
}

pub const GameScoreSystem = struct {
    const Self = @This();
    ecs: *ECS,
    gameOver: bool = false,
    finishTextBuffer: [4096]u8 = std.mem.zeroes([4096]u8),

    pub fn init(ecs: *ECS) !Self {
        return Self{ .ecs = ecs };
    }

    pub fn deinit(_: *Self) void {}

    pub fn finish(self: *Self, ending: Ending) void {
        if (self.gameOver) return;
        log.info("GAME OVER", .{});
        self.gameOver = true;
        const p = self.ecs.getSystem(player.PlayerSystem).?.player;
        const pla: *player.Player = self.ecs.getOnePtr(p, player.Player).?;

        switch (ending) {
            .disqualified => {
                log.debug("YOU GOT CAUGHT", .{});
                self.setText("YOU GOT CAUGHT", .{});
            },
            .timeIsUp => {
                log.debug("TIME IS UP", .{});
                self.setText("TIME IS UP\n{d} of {d} answers", .{ pla.solutionsWrittenDown, player.questionCount });
            },
            .complete => {
                log.debug("COMPLETE", .{});
                self.setText("You aced the test\n{d} of {d} answers", .{ pla.solutionsWrittenDown, player.questionCount });
            },
        }
    }

    pub fn after(self: *Self, _: f32) !void {
        if (self.gameOver) {
            r.ClearBackground(r.BLACK);
            r.DrawText(
                @ptrCast([*:0]const u8, &self.finishTextBuffer),
                @floatToInt(i32, self.ecs.window.size.x / 2 - 200),
                @floatToInt(i32, self.ecs.window.size.y / 2),
                40,
                r.GOLD,
            );

            r.DrawText(
                "press [R] to restart",
                @floatToInt(i32, self.ecs.window.size.x / 2 - 100),
                @floatToInt(i32, self.ecs.window.size.y / 2 + 100),
                20,
                r.GOLD,
            );
        }

        if (r.IsKeyReleased(.KEY_R)) {
            try self.ecs.getSystem(@import("player_system.zig").PlayerSystem).?.resetSystem();
            try self.ecs.getSystem(@import("teacher_system.zig").TeacherSystem).?.resetSystem();
            try self.ecs.getSystem(@import("class_room_system.zig").ClassRoomSystem).?.resetSystem();
            try self.ecs.getSystem(@import("clock_system.zig").ClockSystem).?.resetSystem();
            self.gameOver = false;
        }
    }

    fn setText(self: *Self, comptime fmt: []const u8, args: anytype) void {
        _ = std.fmt.bufPrintZ(&self.finishTextBuffer, fmt, args) catch |err| {
            log.err("ERROR: {?}", .{err});
            return;
        };
    }
};
