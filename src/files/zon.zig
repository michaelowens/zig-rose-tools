// Zone Information
// TODO: needs fixing, reading ends up being 4 bytes short of file length

const std = @import("std");
const RoseTools = @import("../rosetools.zig");
const fs = std.fs;
const testing = std.testing;
const RoseFile = RoseTools.RoseFile;
const Vec2 = RoseTools.Vec2;
const Vec3 = RoseTools.Vec3;

pub const ZON = struct {
    const Self = @This();

    zone_type: ZoneType = undefined,
    width: i32 = undefined,
    height: i32 = undefined,
    grid_count: i32 = undefined,
    grid_size: f32 = undefined,
    start_position: Vec2(i32) = undefined,
    positions: [][]ZonePosition = undefined,
    event_points: []ZoneEventPoint = undefined,
    textures: [][]u8 = undefined,
    tiles: []ZoneTile = undefined,
    name: []u8 = undefined,
    is_underground: bool = undefined,
    background_music: []u8 = undefined,
    sky: []u8 = undefined,
    economy_tick_rate: i32 = undefined,
    population_base: i32 = undefined,
    population_growth_rate: i32 = undefined,
    metal_consumption: i32 = undefined,
    stone_consumption: i32 = undefined,
    wood_consumption: i32 = undefined,
    leather_consumption: i32 = undefined,
    cloth_consumption: i32 = undefined,
    alchemy_consumption: i32 = undefined,
    chemical_consumption: i32 = undefined,
    medicine_consumption: i32 = undefined,
    food_consumption: i32 = undefined,

    pub const ZoneType = enum(u32) {
        Grass = 0,
        Mountain = 1,
        MountainVillage = 2,
        BoatVillage = 3,
        Login = 4,
        MountainGorge = 5,
        Beach = 6,
        JunonDungeon = 7,
        LunaSnow = 8,
        Birth = 9,
        JunonField = 10,
        LunaDungeon = 11,
        EldeonField = 12,
        EldeonField2 = 13,
        JunonPyramids = 14,
    };

    pub const ZonePosition = struct {
        position: Vec2(f32),
        is_used: bool,
    };

    pub const ZoneEventPoint = struct {
        position: Vec3(f32),
        name: []u8,
    };

    pub const ZoneTile = struct {
        layer1: i32,
        layer2: i32,
        offset1: i32,
        offset2: i32,
        blend: bool,
        rotation: ZoneTileRotation,
        tile_type: i32,
    };

    pub const ZoneTileRotation = enum(u32) {
        Unknown = 0,
        None = 1,
        FlipHorizontal = 2,
        FlipVertical = 3,
        Flip = 4,
        Clockwise90 = 5,
        CounterClockwise90 = 6,
    };

    pub const ZoneBlockType = enum(u32) {
        BasicInfo = 0,
        EventPoints = 1,
        Textures = 2,
        Tiles = 3,
        Economy = 4,
    };

    pub fn init() Self {
        return .{};
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        const block_count = try file.readInt(u32);

        var blocks = try allocator.alloc(struct { u32, u32 }, block_count);

        var i: usize = 0;
        while (i < block_count) : (i += 1) {
            const block_type = try file.readInt(u32);
            const offset = try file.readInt(u32);
            blocks[i] = .{ block_type, offset };
        }

        for (blocks) |block| {
            const block_type = @as(ZoneBlockType, @enumFromInt(block[0]));
            const block_offset = block[1];

            try file.reader.context.seekTo(@as(u64, @intCast(block_offset)));

            switch (block_type) {
                .BasicInfo => {
                    self.zone_type = @as(ZoneType, @enumFromInt(try file.readInt(u32)));
                    self.width = try file.readInt(i32);
                    self.height = try file.readInt(i32);
                    self.grid_count = try file.readInt(i32);
                    self.grid_size = try file.readFloat(f32);
                    self.start_position = try file.readVec2(i32);

                    self.positions = try allocator.alloc([]ZonePosition, @as(usize, @intCast(self.width)));

                    var w: usize = 0;
                    var h: usize = 0;
                    while (w < self.width) : (w += 1) {
                        self.positions[w] = try allocator.alloc(ZonePosition, @as(usize, @intCast(self.height)));
                        while (h < self.height) : (h += 1) {
                            self.positions[w][h].is_used = try file.readBool();
                            self.positions[w][h].position = try file.readFloatVec2(f32);
                        }
                    }
                },
                .EventPoints => {
                    const count = try file.readInt(i32);
                    self.event_points = try allocator.alloc(ZoneEventPoint, @as(usize, @intCast(count)));

                    i = 0;
                    while (i < count) : (i += 1) {
                        self.event_points[i].position = try file.readFloatVec3(f32);
                        self.event_points[i].name = try file.readString(u8);
                    }
                },
                .Textures => {
                    const count = try file.readInt(i32);
                    self.textures = try allocator.alloc([]u8, @as(usize, @intCast(count)));

                    i = 0;
                    while (i < count) : (i += 1) {
                        self.textures[i] = try file.readString(u8);
                    }
                },
                .Tiles => {
                    const count = try file.readInt(i32);
                    self.tiles = try allocator.alloc(ZoneTile, @as(usize, @intCast(count)));

                    i = 0;
                    while (i < count) : (i += 1) {
                        self.tiles[i].layer1 = try file.readInt(i32);
                        self.tiles[i].layer2 = try file.readInt(i32);
                        self.tiles[i].offset1 = try file.readInt(i32);
                        self.tiles[i].offset2 = try file.readInt(i32);
                        self.tiles[i].blend = try file.readInt(i32) != 0;
                        self.tiles[i].rotation = @as(ZoneTileRotation, @enumFromInt(try file.readInt(i32)));
                        self.tiles[i].tile_type = try file.readInt(i32);
                    }
                },
                .Economy => {
                    self.name = try file.readString(u8);
                    self.is_underground = try file.readInt(i32) != 0;
                    self.background_music = try file.readString(u8);
                    self.sky = try file.readString(u8);
                    self.economy_tick_rate = try file.readInt(i32);
                    self.population_base = try file.readInt(i32);
                    self.population_growth_rate = try file.readInt(i32);
                    self.metal_consumption = try file.readInt(i32);
                    self.stone_consumption = try file.readInt(i32);
                    self.wood_consumption = try file.readInt(i32);
                    self.leather_consumption = try file.readInt(i32);
                    self.cloth_consumption = try file.readInt(i32);
                    self.alchemy_consumption = try file.readInt(i32);
                    self.chemical_consumption = try file.readInt(i32);
                    self.medicine_consumption = try file.readInt(i32);
                    self.food_consumption = try file.readInt(i32);
                },
            }
        }
    }
};

test "reading ZON file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try fs.cwd().openFile("test_files/JD01.ZON", .{});
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});
    const filesize = try rosefile.file.getEndPos();
    _ = filesize;

    var zon = ZON.init();
    try zon.read(allocator, rosefile);

    // try testing.expect(filesize == try rosefile.file.getPos());
}
