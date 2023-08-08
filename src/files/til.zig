// Terrain Tilemap

const std = @import("std");
const RoseFile = @import("../rosetools.zig").RoseFile;
const fs = std.fs;
const testing = std.testing;

pub const TIL = struct {
    const Self = @This();

    width: i32 = undefined,
    height: i32 = undefined,
    tiles: [][]Tile = undefined,

    const Tile = struct {
        brush_id: u8,
        tile_idx: u8,
        tile_set: u8,
        tile_id: i32,
    };

    pub fn init() Self {
        return .{};
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        self.width = try file.readInt(i32);
        self.height = try file.readInt(i32);
        self.tiles = try allocator.alloc([]Tile, @intCast(usize, self.width));

        var w: usize = 0;
        while (w < self.width) : (w += 1) {
            self.tiles[w] = try allocator.alloc(Tile, @intCast(usize, self.height));
            var h: usize = 0;
            while (h < self.height) : (h += 1) {
                self.tiles[w][h].brush_id = try file.readInt(u8);
                self.tiles[w][h].tile_idx = try file.readInt(u8);
                self.tiles[w][h].tile_set = try file.readInt(u8);
                self.tiles[w][h].tile_id = try file.readInt(i32);
            }
        }
    }

    pub fn write(self: *Self, file: RoseFile) !void {
        try file.writer.context.seekTo(0);
        try file.writer.context.setEndPos(0);
        try file.writeInt(i32, self.width);
        try file.writeInt(i32, self.height);
        for (self.tiles, 0..) |_, row| {
            for (self.tiles[row], 0..) |_, col| {
                try file.writeInt(u8, self.tiles[row][col].brush_id);
                try file.writeInt(u8, self.tiles[row][col].tile_idx);
                try file.writeInt(u8, self.tiles[row][col].tile_set);
                try file.writeInt(i32, self.tiles[row][col].tile_id);
            }
        }
    }
};

test "reading TIL file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try fs.cwd().openFile("test_files/31_30.TIL", .{});
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});
    const filesize = try rosefile.file.getEndPos();

    var til = TIL.init();
    try til.read(allocator, rosefile);

    try testing.expect(filesize == try rosefile.file.getPos());
}

test "writing TIL file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const read_file = try fs.cwd().openFile("test_files/31_30.TIL", .{});
    defer read_file.close();
    const read_rosefile = try RoseFile.init(allocator, read_file, .{});
    var read_idx = TIL.init();
    try read_idx.read(allocator, read_rosefile);

    var write_file = try tmp.dir.createFile("31_30.TIL", .{ .read = true });
    defer write_file.close();
    const write_rosefile = try RoseFile.init(allocator, write_file, .{});
    try read_idx.write(write_rosefile);
    try write_file.reader().context.seekTo(0);

    var written_idx = TIL.init();
    try written_idx.read(allocator, write_rosefile);

    try testing.expect(try write_file.reader().context.getEndPos() == try read_file.reader().context.getEndPos());
    try testing.expect(written_idx.width == read_idx.width);
    try testing.expect(written_idx.height == read_idx.height);
    for (read_idx.tiles, 0..) |_, row| {
        for (read_idx.tiles[row], 0..) |tile, col| {
            try testing.expect(written_idx.tiles[row][col].brush_id == tile.brush_id);
            try testing.expect(written_idx.tiles[row][col].tile_idx == tile.tile_idx);
            try testing.expect(written_idx.tiles[row][col].tile_set == tile.tile_set);
            try testing.expect(written_idx.tiles[row][col].tile_id == tile.tile_id);
        }
    }
}
