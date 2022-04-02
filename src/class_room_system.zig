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

pub const RoomConfig = struct {
    blackboardRect: r.Rectangle,
    studentTables: struct {
        rows: i32,
        columns: i32,
        margin: f32,
        area: struct {
            x: f32,
            y: f32,
            width: f32,
            height: f32,
        },
    },
};

pub const ClassRoomSystem = struct {
    ecs: *ECS,
    camera: *CameraSystem,
    assets: *AssetSystem,
    groudTex: *AssetLink,
    blackboardTex: *AssetLink,
    studentTableTex: *AssetLink,
    roomConfigLink: *AssetLink,
    roomConfig: RoomConfig = undefined,

    pub fn init(ecs: *ECS) !@This() {
        const ass = ecs.getSystem(AssetSystem).?;
        var system = @This(){
            .ecs = ecs,
            .assets = ass,
            .camera = ecs.getSystem(CameraSystem).?,
            .groudTex = try ass.loadTexture("assets/images/class/ground.png"),
            .blackboardTex = try ass.loadTexture("assets/images/class/blackboard.png"),
            .studentTableTex = try ass.loadTexture("assets/images/class/student_table_and_chair.png"),
            .roomConfigLink = try ass.loadJson("assets/data/room_config.json"),
        };

        return system;
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        self.roomConfig = self.roomConfigLink.asset.Json.as(RoomConfig) catch |err| {
            log.err("cannot load room config: {?}", .{err});
            return;
        };
        try self.drawGround();
        try self.drawBlackboard();
        try self.drawStudentChairs();
    }

    pub fn drawStudentChairs(self: *@This()) !void {
        const tex = self.studentTableTex.asset.Texture;
        const config = self.roomConfig.studentTables;
        const tableSize = r.Vector2{
            .x = (config.area.width - @intToFloat(f32, config.columns - 1) * config.margin) / @intToFloat(f32, config.columns),
            .y = (config.area.height - @intToFloat(f32, config.rows - 1) * config.margin) / @intToFloat(f32, config.rows),
        };

        var row: i32 = 0;
        var col: i32 = 0;
        while (row < config.rows) : (row += 1) {
            col = 0;
            while (col < config.columns) : (col += 1) {
                var table = r.Rectangle{
                    .x = config.area.x + @intToFloat(f32, col) * (tableSize.x + config.margin),
                    .y = config.area.y + @intToFloat(f32, row) * (tableSize.y + config.margin),
                    .width = tableSize.x,
                    .height = tableSize.y,
                };
                drawTexture(tex, table);
            }
        }
    }

    pub fn drawBlackboard(self: *@This()) !void {
        const tex = self.blackboardTex.asset.Texture;
        drawTexture(tex, self.roomConfig.blackboardRect);
    }

    pub fn drawGround(self: *@This()) !void {
        const tex = self.groudTex.asset.Texture;
        drawTexture(
            tex,
            r.Rectangle{
                .x = -self.ecs.window.size.x / 2,
                .y = -self.ecs.window.size.y / 2,
                .width = self.ecs.window.size.x,
                .height = self.ecs.window.size.y,
            },
        );
    }

    fn drawTexture(tex: r.Texture2D, dest: r.Rectangle) void {
        r.DrawTexturePro(tex, r.Rectangle{
            .x = 0,
            .y = 0,
            .width = @intToFloat(f32, tex.width),
            .height = @intToFloat(f32, tex.height),
        }, dest, r.Vector2.zero(), 0, r.WHITE);
    }
};
