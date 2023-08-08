// Sprite Information

const std = @import("std");
const RoseTools = @import("../rosetools.zig");
const fs = std.fs;
const RoseFile = RoseTools.RoseFile;
const Vec2 = RoseTools.Vec2;
const testing = std.testing;

pub const TSI = struct {
    const Self = @This();

    sprite_sheets: []SpriteSheet = undefined,

    pub const SpriteSheet = struct {
        path: []u8,
        color_key: u32,
        sprites: []Sprite,
    };

    pub const Sprite = struct {
        name: []u8,
        start_point: Vec2(u32),
        end_point: Vec2(u32),
        color: u32,
    };

    pub fn init() Self {
        return .{};
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        const sheet_count = try file.readInt(u16);
        self.sprite_sheets = try allocator.alloc(SpriteSheet, sheet_count);

        var i: usize = 0;
        while (i < sheet_count) : (i += 1) {
            self.sprite_sheets[i].path = try file.readString(u16);
            self.sprite_sheets[i].color_key = try file.readInt(u32);
        }

        _ = try file.readInt(u16); // total_sprite_count
        i = 0;
        while (i < sheet_count) : (i += 1) {
            const sprite_count = try file.readInt(u16);
            self.sprite_sheets[i].sprites = try allocator.alloc(Sprite, sprite_count);

            var j: usize = 0;
            while (j < sprite_count) {
                defer j += 1;
                _ = try file.readInt(u16); // sheet_id
                self.sprite_sheets[i].sprites[j] = Sprite{
                    .start_point = try file.readVec2(u32),
                    .end_point = try file.readVec2(u32),
                    .color = try file.readInt(u32),
                    .name = try file.readVarString(32),
                };
            }
        }
    }

    pub fn write(self: *Self, file: RoseFile) !void {
        try file.writer.context.seekTo(0);
        try file.writer.context.setEndPos(0);
        try file.writeInt(u16, @as(u16, @intCast(self.sprite_sheets.len)));

        var total_sprite_count: u16 = 0;
        for (self.sprite_sheets) |sprite_sheet| {
            try file.writeString(u16, sprite_sheet.path);
            try file.writeInt(u32, sprite_sheet.color_key);
            total_sprite_count += @as(u16, @intCast(sprite_sheet.sprites.len));
        }

        try file.writeInt(u16, total_sprite_count);

        for (self.sprite_sheets, 0..) |sprite_sheet, i| {
            try file.writeInt(u16, @as(u16, @intCast(sprite_sheet.sprites.len)));
            for (sprite_sheet.sprites) |sprite| {
                try file.writeInt(u16, @as(u16, @intCast(i)));
                try file.writeVec2(u32, sprite.start_point);
                try file.writeVec2(u32, sprite.end_point);
                try file.writeInt(u32, sprite.color);
                try file.writeVarString(32, sprite.name);
            }
        }
    }
};

test "reading TSI file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try fs.cwd().openFile("test_files/UI2.TSI", .{});
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});
    const filesize = try rosefile.file.getEndPos();

    var tsi = TSI.init();
    try tsi.read(allocator, rosefile);

    try testing.expect(filesize == try rosefile.file.getPos());
    try testing.expect(46 == tsi.sprite_sheets.len);
}

test "writing TSI file" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const read_file = try fs.cwd().openFile("test_files/UI2.TSI", .{});
    defer read_file.close();
    const read_rosefile = try RoseFile.init(allocator, read_file, .{});
    var read_idx = TSI.init();
    try read_idx.read(allocator, read_rosefile);

    var write_file = try tmp.dir.createFile("UI2.TSI", .{ .read = true });
    defer write_file.close();
    const write_rosefile = try RoseFile.init(allocator, write_file, .{});
    try read_idx.write(write_rosefile);
    try write_file.reader().context.seekTo(0);

    var written_idx = TSI.init();
    try written_idx.read(allocator, write_rosefile);

    try testing.expect(try write_file.reader().context.getEndPos() == try read_file.reader().context.getEndPos());
    try testing.expect(written_idx.sprite_sheets.len == read_idx.sprite_sheets.len);

    for (read_idx.sprite_sheets, 0..) |sprite_sheet, i| {
        try testing.expectEqualStrings(sprite_sheet.path, written_idx.sprite_sheets[i].path);
        try testing.expect(written_idx.sprite_sheets[i].color_key == sprite_sheet.color_key);

        for (sprite_sheet.sprites, 0..) |sprite, si| {
            try testing.expectEqualStrings(sprite.name, written_idx.sprite_sheets[i].sprites[si].name);
            try testing.expectEqualDeep(sprite.start_point, written_idx.sprite_sheets[i].sprites[si].start_point);
            try testing.expectEqualDeep(sprite.end_point, written_idx.sprite_sheets[i].sprites[si].end_point);
            try testing.expect(sprite.color == written_idx.sprite_sheets[i].sprites[si].color);
        }
    }
}
