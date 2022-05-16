const zecsi = @import("zecsi/zecsi.zig");
const log = zecsi.log;
const r = zecsi.raylib;

pub fn drawTexture(tex: r.Texture2D, dest: r.Rectangle) void {
    r.DrawTexturePro(tex, r.Rectangle{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, tex.width),
        .height = @intToFloat(f32, tex.height),
    }, dest, .{ .x = dest.width / 2, .y = dest.height / 2 }, 0, r.WHITE);
}

pub fn drawTextureOrigin(tex: r.Texture2D, dest: r.Rectangle, origin: r.Vector2) void {
    r.DrawTexturePro(tex, r.Rectangle{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, tex.width),
        .height = @intToFloat(f32, tex.height),
    }, dest, origin, 0, r.WHITE);
}

pub fn drawTextureRotated(tex: r.Texture2D, dest: r.Rectangle, rotation: f32) void {
    r.DrawTexturePro(tex, r.Rectangle{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, tex.width),
        .height = @intToFloat(f32, tex.height),
    }, dest, .{ .x = dest.width / 2, .y = dest.height / 2 }, rotation, r.WHITE);
}
