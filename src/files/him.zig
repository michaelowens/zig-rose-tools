// Heightmaps

const std = @import("std");
const RoseFile = @import("../rosetools.zig").RoseFile;
const fs = std.fs;
const testing = std.testing;

pub const HIM = struct {
    const Self = @This();

    width: i32 = undefined,
    height: i32 = undefined,
    grid_count: i32 = undefined,
    scale: f32 = undefined,
    heights: [][]f32 = undefined,
    patches: [][]HeightmapPatch = undefined,
    quad_patches: []HeightmapPatch = undefined,

    pub const HeightmapPatch = struct {
        min: f32,
        max: f32,
    };

    pub fn init() Self {
        return .{};
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        self.width = try file.readInt(i32);
        self.height = try file.readInt(i32);
        self.grid_count = try file.readInt(i32);
        self.scale = try file.readFloat(f32);
        self.heights = try allocator.alloc([]f32, @intCast(self.height));

        var h: usize = 0;
        while (h < self.height) : (h += 1) {
            self.heights[h] = try allocator.alloc(f32, @intCast(self.width));
            var w: usize = 0;
            while (w < self.width) : (w += 1) {
                self.heights[h][w] = try file.readFloat(f32);
            }
        }

        _ = try file.readString(u8); // name = "quad"
        _ = try file.readInt(i32); // patch_count = 256

        self.patches = try allocator.alloc([]HeightmapPatch, 16);
        h = 0;
        while (h < 16) : (h += 1) {
            self.patches[h] = try allocator.alloc(HeightmapPatch, 16);
            var w: usize = 0;
            while (w < 16) : (w += 1) {
                self.patches[h][w].max = try file.readFloat(f32);
                self.patches[h][w].min = try file.readFloat(f32);
            }
        }

        const quad_patch_count = try file.readInt(i32);
        self.quad_patches = try allocator.alloc(HeightmapPatch, @as(usize, @intCast(quad_patch_count)));

        var i: usize = 0;
        while (i < quad_patch_count) : (i += 1) {
            self.quad_patches[i].max = try file.readFloat(f32);
            self.quad_patches[i].min = try file.readFloat(f32);
        }
    }

    pub fn write(self: *Self, file: RoseFile) !void {
        try file.writer.context.seekTo(0);
        try file.writer.context.setEndPos(0);
        try file.writeInt(i32, self.width);
        try file.writeInt(i32, self.height);
        try file.writeInt(i32, self.grid_count);
        try file.writeFloat(f32, self.scale);

        for (self.heights) |row| {
            for (row) |col| {
                try file.writeFloat(f32, col);
            }
        }

        try file.writeString(u8, "quad");
        try file.writeInt(i32, @as(i32, @intCast(self.patches.len * self.patches[0].len)));

        for (self.patches) |row| {
            for (row) |col| {
                try file.writeFloat(f32, col.max);
                try file.writeFloat(f32, col.min);
            }
        }

        try file.writeInt(i32, @as(i32, @intCast(self.quad_patches.len)));

        for (self.quad_patches) |quad_patch| {
            try file.writeFloat(f32, quad_patch.max);
            try file.writeFloat(f32, quad_patch.min);
        }
    }
};

test "reading HIM file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try fs.cwd().openFile("test_files/31_30.HIM", .{});
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});
    const filesize = try rosefile.file.getEndPos();

    var him = HIM.init();
    try him.read(allocator, rosefile);

    try testing.expect(filesize == try rosefile.file.getPos());
}

test "writing HIM file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const read_file = try fs.cwd().openFile("test_files/31_30.HIM", .{});
    defer read_file.close();
    const read_rosefile = try RoseFile.init(allocator, read_file, .{});
    var read_him = HIM.init();
    try read_him.read(allocator, read_rosefile);

    var write_file = try tmp.dir.createFile("31_30.HIM", .{ .read = true });
    defer write_file.close();
    const write_rosefile = try RoseFile.init(allocator, write_file, .{});
    try read_him.write(write_rosefile);
    try write_file.reader().context.seekTo(0);

    var written_him = HIM.init();
    try written_him.read(allocator, write_rosefile);

    try testing.expect(try write_file.reader().context.getEndPos() == try read_file.reader().context.getEndPos());
    try testing.expect(written_him.width == read_him.width);
    try testing.expect(written_him.height == read_him.height);
    try testing.expect(written_him.grid_count == read_him.grid_count);
    try testing.expect(written_him.scale == read_him.scale);

    for (read_him.heights, 0..) |_, row| {
        for (read_him.heights[row], 0..) |value, col| {
            try testing.expect(written_him.heights[row][col] == value);
        }
    }

    for (read_him.patches, 0..) |_, row| {
        for (read_him.patches[row], 0..) |value, col| {
            try testing.expect(written_him.patches[row][col].max == value.max);
            try testing.expect(written_him.patches[row][col].min == value.min);
        }
    }

    for (read_him.quad_patches, 0..) |value, row| {
        try testing.expect(written_him.quad_patches[row].max == value.max);
        try testing.expect(written_him.quad_patches[row].min == value.min);
    }
}
