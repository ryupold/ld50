const std = @import("std");
const Allocator = std.mem.Allocator;
const emsdk = @cImport({
    @cDefine("__EMSCRIPTEN__", "1");
    @cInclude("emscripten/emscripten.h");
});
const zecsi = @import("zecsi/main.zig");
const game = zecsi.game;
const log = zecsi.log;
const ZecsiAllocator = zecsi.ZecsiAllocator;
const gameConfig = @import("game_config.zig");
const myGame = @import("game.zig");
const r = zecsi.raylib;

////special entry point for Emscripten build, called from src/emscripten/entry.c
pub export fn emsc_main() callconv(.C) c_int {
    return safeMain() catch |err| {
        log.err("ERROR: {?}", .{err});
        return 1;
    };
}

pub export fn emsc_set_window_size(width: i32, height: i32) callconv(.C) void {
    if (gameConfig.resizable) {
        game.setWindowSize(width, height);
    } else {
        game.setWindowSize(gameConfig.windowSize.width, gameConfig.windowSize.height);
    }
}

fn safeMain() !c_int {
    var zalloc = ZecsiAllocator{};
    const allocator = zalloc.allocator();

    log.info("starting game [{d}x{d}]", .{
        gameConfig.windowSize.width,
        gameConfig.windowSize.height,
    });
    try game.init(allocator, .{
        .gameName = gameConfig.name,
        .cwd = "",
        .initialWindowSize = .{
            .width = gameConfig.windowSize.width,
            .height = gameConfig.windowSize.height,
        },
    });
    defer {
        log.info("stopping game...", .{});
        game.deinit();
    }

    try myGame.start(game.getECS());

    emsdk.emscripten_set_main_loop(gameLoop, 0, 1);
    log.info("after emscripten_set_main_loop", .{});

    log.info("CLEANUP", .{});
    if (zalloc.deinit()) {
        log.err("memory leaks detected!", .{});
        return 1;
    }
    return 0;
}

export fn gameLoop() callconv(.C) void {
    game.mainLoop() catch |err| {
        log.err("ERROR at start: {?}", .{err});
    };
}
