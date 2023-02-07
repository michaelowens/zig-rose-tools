// Sprite Information

const std = @import("std");
const fs = std.fs;
const RoseFile = @import("../rosefile.zig").RoseFile;
const Vec2 = @import("../utils.zig").Vec2;

pub const TSI = struct {
    const Self = @This();

    sprite_sheets: []SpriteSheet,

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
        return .{
            .sprite_sheets = undefined,
        };
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        const sheet_count = try file.readInt(u16);
        self.sprite_sheets = try allocator.alloc(SpriteSheet, sheet_count);

        var i: usize = 0;
        while (i < sheet_count) {
            defer i += 1;
            self.sprite_sheets[i].path = try file.readString(u16);
            self.sprite_sheets[i].color_key = try file.readInt(u32);
        }

        _ = try file.readInt(u16); // total_sprite_count
        i = 0;
        while (i < sheet_count) {
            defer i += 1;

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

    pub fn write(self: Self, file: RoseFile) !void {
        try file.writer.context.seekTo(0);
        try file.writer.context.setEndPos(0);
        try file.writeInt(u16, @intCast(u16, self.sprite_sheets.len));

        var total_sprite_count: u16 = 0;
        for (self.sprite_sheets) |sprite_sheet| {
            try file.writeString(u16, sprite_sheet.path);
            try file.writeInt(u32, sprite_sheet.color_key);
            total_sprite_count += @intCast(u16, sprite_sheet.sprites.len);
        }

        try file.writeInt(u16, total_sprite_count);

        for (self.sprite_sheets) |sprite_sheet, i| {
            try file.writeInt(u16, @intCast(u16, sprite_sheet.sprites.len));
            for (sprite_sheet.sprites) |sprite| {
                try file.writeInt(u16, @intCast(u16, i));
                try file.writeVec2(u32, sprite.start_point);
                try file.writeVec2(u32, sprite.end_point);
                try file.writeInt(u32, sprite.color);
                try file.writeVarString(32, sprite.name);
            }
        }
    }
};