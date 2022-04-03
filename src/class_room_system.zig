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
const drawTextureOrigin = @import("utils.zig").drawTextureOrigin;

pub const StudentTable = struct {
    area: r.RectangleI,
};

pub const RoomConfig = struct {
    blackboardRect: r.Rectangle,
    studentTables: struct {
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

pub const RoomGrid = std.AutoHashMap(GridPosition, EntityID);

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
    drawDebug: bool = false,
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

    pub fn deinit(self: *@This()) void {
        self.roomGrid.deinit();
    }

    pub fn update(self: *@This(), _: f32) !void {
        const config = self.roomConfig.get();
        if (self.roomConfigModTime != self.roomConfig.modTime) {
            try self.reinitRoom(config);
            self.roomConfigModTime = self.roomConfig.modTime;
        }

        if (!self.hideGround) try self.drawBaseRoom();
        try self.drawBlackboard(config);
        try self.drawStudentChairs(config);
        if (self.drawDebug) self.drawDebugRects();

        if (r.IsKeyReleased(r.KEY_B)) {
            self.hideGround = !self.hideGround;
        }
        if (r.IsKeyReleased(r.KEY_C)) {
            self.drawDebug = !self.drawDebug;
        }

        if (r.IsMouseButtonReleased(0)) {
            const wpos = self.camera.screenToWorld(r.GetMousePosition());
            log.debug("click on {?}", .{self.grid.toGridPosition(wpos)});
        }
    }

    /// assuming that the config was loaded
    fn reinitRoom(self: *@This(), config: RoomConfig) !void {
        log.debug("initialize room: {?}", .{config});

        try self.clearGrid();

        try self.addStudentTables(config);

        try self.addWalls(config);
    }

    ///populate grid with entities{StudentTable}
    fn addStudentTables(self: *@This(), config: RoomConfig) !void {
        const tables = config.studentTables;
        var y: i32 = tables.area.y;
        while (y < tables.area.height - tables.tableArea.y) : (y += tables.tableArea.y + tables.margin.y) {
            var x: i32 = tables.area.x;
            while (x < tables.area.width - tables.tableArea.x) : (x += tables.tableArea.x + tables.margin.x) {
                const table = StudentTable{
                    .area = .{
                        .x = x,
                        .y = y,
                        .width = tables.tableArea.x,
                        .height = tables.tableArea.y,
                    },
                };
                var e = try self.ecs.create(.{table});
                try self.putEntityOnGridArea(e.id, .{
                    .x = table.area.x,
                    .y = table.area.y,
                    .width = table.area.width,
                    .height = table.area.height - 1, //Make table collider 1 cell smaller so the player can walk up to another student
                });
            }
        }
    }

    fn addWalls(self: *@This(), config: RoomConfig) !void {
        const wallEntity = try self.ecs.createEmpty();
        const min = self.grid.toGridPosition(.{
            .x = -self.ecs.window.size.x / 2,
            .y = -self.ecs.window.size.y / 2,
        }).add(.{ .x = 0, .y = 2 }); //with wall size as offset
        const max = self.grid.toGridPosition(.{
            .x = self.ecs.window.size.x / 2,
            .y = self.ecs.window.size.y / 2,
        }).add(.{ .x = 1, .y = 1 });
        var y = min.y;
        while (y < max.y) : (y += 1) {
            var x = min.x;
            while (x < max.x) : (x += 1) {
                if (x > min.x and x < max.y - 1 and y > min.y and y < max.y - 1) continue;
                try self.putEntityOnGridArea(wallEntity.id, .{ .x = x, .y = y, .width = 1, .height = 1 });
            }
        }
        _ = self;
        _ = config;
    }

    ///clear grid
    fn clearGrid(self: *@This()) !void {
        var kit = self.roomGrid.keyIterator();
        while (kit.next()) |pos| {
            const table = self.roomGrid.fetchRemove(pos.*).?.value;
            _ = try self.ecs.destroy(table);
            kit = self.roomGrid.keyIterator();
        }
    }

    pub fn drawStudentChairs(self: *@This(), _: RoomConfig) !void {
        const tex = self.studentTableTex.asset.Texture;
        var it = self.ecs.query(.{StudentTable});
        while (it.next()) |e| {
            const table: *StudentTable = e.getData(self.ecs, StudentTable).?;
            std.debug.assert(table.area.y <= table.area.y + table.area.height);
            std.debug.assert(table.area.x <= table.area.x + table.area.width);

            const pos = self.grid.toWorldPositionEx(.{ .x = table.area.x, .y = table.area.y }, .{ .x = 0, .y = 0 });
            const w = self.grid.toWorldLen(table.area.width);
            const h = self.grid.toWorldLen(table.area.height);

            // draw table texture
            drawTextureOrigin(tex, .{
                .x = pos.x,
                .y = pos.y,
                .width = w,
                .height = h,
            }, r.Vector2.zero());
        }
    }

    fn drawDebugRects(self: *@This()) void {
        var kit = self.roomGrid.keyIterator();
        const padding: f32 = 3;
        const cs = self.grid.cellSize();
        while (kit.next()) |gpos| {
            const pos = self.grid.toWorldPositionEx(gpos.*, .{ .x = 0, .y = 0 });
            const rect = r.Rectangle{
                .x = pos.x + padding,
                .y = pos.y + padding,
                .width = cs - padding * 2,
                .height = cs - padding * 2,
            };
            const eid = self.roomGrid.get(gpos.*).?;
            r.DrawRectanglePro(rect, r.Vector2.zero(), 0, r.WHITE.set(.{
                .r = @truncate(u8, eid * 66),
                .g = @truncate(u8, eid * 132),
                .b = @truncate(u8, eid * 198),
                .a = 70,
            }));
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

    fn putEntityOnGridArea(self: *@This(), entity: EntityID, area: r.RectangleI) !void {
        std.debug.assert(area.x <= area.x + area.width);
        std.debug.assert(area.y <= area.y + area.height);

        var count: usize = 0;
        var y: i32 = area.y;
        while (y < area.y + area.height) : (y += 1) {
            var x: i32 = area.x;
            while (x < area.x + area.width) : (x += 1) {
                try self.roomGrid.put(.{ .x = x, .y = y }, entity);
                count += 1;
            }
        }

        log.debug("put #{d} on {?} occupying {d} cells", .{ entity, area, count });
    }
};
