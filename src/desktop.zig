const std = @import("std");
const builtin = @import("builtin");
const zecsi = @import("zecsi/zecsi.zig");
const Allocator = std.mem.Allocator;
const game = zecsi.game;
const log = zecsi.log;
const r = zecsi.raylib;
const ZecsiAllocator = zecsi.ZecsiAllocator;
const gameConfig = @import("game_config.zig");
const myGame = @import("game.zig");

const updateWindowSizeEveryNthFrame = 30;

fn compError(comptime fmt: []const u8, args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}

pub fn main() anyerror!void {
    var zalloc = ZecsiAllocator{};
    //init allocator
    const allocator = zalloc.allocator();
    defer {
        log.info("free memory...", .{});
        if (zalloc.deinit()) {
            log.err("memory leaks detected!", .{});
        }
    }

    const exePath = try std.fs.selfExePathAlloc(allocator);
    const cwd = std.fs.path.dirname(exePath).?;
    defer allocator.free(exePath);
    log.info("current path: {s}", .{cwd});

    //remove to prevent resizing of window
    if (gameConfig.resizable) r.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    var frame: usize = 0;
    var lastWindowSize: struct { w: i32 = 0, h: i32 = 0 } = .{};

    // game start/stop
    log.info("starting game [{d}x{d}]", .{
        gameConfig.windowSize.width,
        gameConfig.windowSize.height,
    });
    try game.init(allocator, .{
        .gameName = gameConfig.name,
        .cwd = cwd,
        .initialWindowSize = .{
            .width = gameConfig.windowSize.width,
            .height = gameConfig.windowSize.height,
        },
    });
    defer {
        log.info("stopping game...", .{});
        game.deinit();
    }

    // if (builtin.mode == .Debug and builtin.os.tag == .macos) r.SetWindowPosition(500, -1000);
    try myGame.start(game.getECS());

    r.SetTargetFPS(60);

    while (!r.WindowShouldClose()) {
        if (frame % updateWindowSizeEveryNthFrame == 0) {
            const newW = r.GetScreenWidth();
            const newH = r.GetScreenHeight();
            if (newW != lastWindowSize.w or newH != lastWindowSize.h) {
                log.debug("changed screen size {d}x{x}", .{ newW, newH });
                game.setWindowSize(newW, newH);
                lastWindowSize.w = newW;
                lastWindowSize.h = newH;
            }
        }
        frame += 1;
        try game.mainLoop();
    }
}
