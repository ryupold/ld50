const builtin = @import("builtin");
const zecsi = @import("zecsi/main.zig");
const ECS = zecsi.ECS;
const base = zecsi.baseSystems;
const raylib = zecsi.raylib;

const example = @import("tree_system.zig");
const StartScreenSystem = @import("start_screen_system.zig").StartScreenSystem;

pub fn start(ecs: *ECS) !void {
    const allocator = ecs.allocator;
    _ = allocator; //<-- use this allocator

    // these are some usefull base systems
    _ = try ecs.registerSystem(base.AssetSystem);
    _ = try ecs.registerSystem(base.GridPlacementSystem);
    var cameraSystem = try ecs.registerSystem(base.CameraSystem);
    cameraSystem.initMouseDrag(base.CameraMouseDrag{ .button = 2 });
    cameraSystem.initMouseZoomScroll(base.CameraScrollZoom{ .factor = 0.1 });
    cameraSystem.initTouchZoomAndDrag(base.TwoFingerZoomAndDrag{ .factor = 0.5 });
    if(builtin.mode == .Debug) cameraSystem.initCameraWASD(.{});

    //register your systems here
    _ = try ecs.registerSystem(@import("class_room_system.zig").ClassRoomSystem);
    _ = try ecs.registerSystem(@import("clock_system.zig").ClockSystem);
    _ = try ecs.registerSystem(@import("player_system.zig").PlayerSystem);
    _ = try ecs.registerSystem(@import("teacher_system.zig").TeacherSystem);
    _ = try ecs.registerSystem(@import("movement_system.zig").MovementSystem);
    _ = try ecs.registerSystem(@import("game_score_system.zig").GameScoreSystem);
    _ = try ecs.registerSystem(@import("debug_system.zig").DebugSystem);
    // _ = try ecs.registerSystem(example.TreeSystem);

}
