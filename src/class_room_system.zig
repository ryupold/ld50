const std = @import("std");
const zecsi = @import("zecsi/main.zig");
const log = zecsi.log;
const ECS = zecsi.ECS;
const Entity = zecsi.Entity;
const EntityID = zecsi.EntityID;
const Timer = zecsi.utils.Timer;
const CameraSystem = zecsi.baseSystems.CameraSystem;
const AssetSystem = zecsi.baseSystems.AssetSystem;
const GridPosition = zecsi.baseSystems.GridPosition;
const GridPlacementSystem = zecsi.baseSystems.GridPlacementSystem;
const AssetLink = zecsi.assets.AssetLink;
const JsonObject = zecsi.assets.JsonObject;
const r = zecsi.raylib;
const drawTexture = @import("utils.zig").drawTexture;

pub const StudentTable = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const RoomConfig = struct {
    blackboardRect: r.Rectangle,
    studentTables: struct {
        rows: i32,
        columns: i32,
        area: struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
        },
        margin: r.Vector2i,
        tableArea: r.Vector2i,
    },
};

const RoomGrid = std.AutoHashMap(GridPosition, EntityID);

pub const ClassRoomSystem = struct {
    ecs: *ECS,
    roomGrid: RoomGrid,
    camera: *CameraSystem,
    assets: *AssetSystem,
    grid: *GridPlacementSystem,
    groudTex: *AssetLink,
    wallTex: *AssetLink,
    blackboardTex: *AssetLink,
    studentTableTex: *AssetLink,

    hideGround: bool = false,
    roomConfigModTime: i128 = -1,
    roomConfig: JsonObject(RoomConfig),

    pub fn init(ecs: *ECS) !@This() {
        const ass = ecs.getSystem(AssetSystem).?;
        var system = @This(){
            .ecs = ecs,
            .roomGrid = RoomGrid.init(ecs.allocator),
            .assets = ass,
            .camera = ecs.getSystem(CameraSystem).?,
            .grid = ecs.getSystem(GridPlacementSystem).?,
            .groudTex = try ass.loadTexture("assets/images/class/ground.png"),
            .wallTex = try ass.loadTexture("assets/images/class/wall.png"),
            .blackboardTex = try ass.loadTexture("assets/images/class/blackboard.png"),
            .studentTableTex = try ass.loadTexture("assets/images/class/student_table_and_chair.png"),
            .roomConfig = try ass.loadJsonObject(RoomConfig, "assets/data/room_config.json"),
        };

        return system;
    }

    pub fn deinit(_: *@This()) void {}

    pub fn update(self: *@This(), _: f32) !void {
        const config = self.roomConfig.get();
        if (self.roomConfigModTime != self.roomConfig.modTime) {
            try self.reinitRoom(config);
            self.roomConfigModTime = self.roomConfig.modTime;
        }

        if (!self.hideGround) try self.drawBaseRoom();
        try self.drawBlackboard(config);
        try self.drawStudentChairs(config);

        if (r.IsKeyReleased(r.KEY_B)) {
            self.hideGround = !self.hideGround;
        }
    }

    /// assuming that the config was loaded
    fn reinitRoom(self: *@This(), config: RoomConfig) !void {
        //clear grid
        var kit = self.roomGrid.keyIterator();
        while (kit.next()) |pos| {
            const table = self.roomGrid.fetchRemove(pos.*).?.value;
            _ = try self.ecs.destroy(table);
            kit = self.roomGrid.keyIterator();
        }

        //TODO: populate grid
        _ = config;
    }

    pub fn drawStudentChairs(self: *@This(), config: RoomConfig) !void {
        const tex = self.studentTableTex.asset.Texture;
        const tables = config.studentTables;
        const areaPos = self.grid.toWorldPosition(.{ .x = tables.area.x, .y = tables.area.y })
            .sub(.{ .x = self.grid.cellSize() / 2.0, .y = self.grid.cellSize() / 2.0 });

        const tableSizeF: r.Vector2 = .{
            .x = self.grid.toWorldLen(tables.tableArea.x),
            .y = self.grid.toWorldLen(tables.tableArea.y),
        };

        var x: i32 = 0;
        var y: i32 = 0;
        var row: i32 = 0;
        var col: i32 = 0;
        while (row < tables.rows) : (row += 1) {
            col = 0;
            while (col < tables.columns) : (col += 1) {
                var table = r.Rectangle{
                    .x = self.grid.toWorldLen(x) + areaPos.x,
                    .y = self.grid.toWorldLen(y) + areaPos.y,
                    .width = tableSizeF.x,
                    .height = tableSizeF.y,
                };
                drawTexture(tex, table);
                x += tables.tableArea.x + tables.margin.x;
            }
            x = 0;
            y += tables.tableArea.y + tables.margin.y;
        }
    }

    pub fn drawBlackboard(self: *@This(), config: RoomConfig) !void {
        const tex = self.blackboardTex.asset.Texture;
        drawTexture(tex, config.blackboardRect);
    }

    pub fn drawBaseRoom(self: *@This()) !void {
        drawTexture(
            self.groudTex.asset.Texture,
            r.Rectangle{
                .x = 0,
                .y = 0,
                .width = self.ecs.window.size.x,
                .height = self.ecs.window.size.y,
            },
        );
        drawTexture(
            self.wallTex.asset.Texture,
            r.Rectangle{
                .x = 0,
                .y = 0,
                .width = self.ecs.window.size.x,
                .height = self.ecs.window.size.y,
            },
        );
    }
};
