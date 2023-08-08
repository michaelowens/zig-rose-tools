const std = @import("std");
const fs = std.fs;

pub const HIM = @import("files/him.zig").HIM;
pub const IDX = @import("files/idx.zig").IDX;
pub const TIL = @import("files/til.zig").TIL;
pub const TSI = @import("files/tsi.zig").TSI;
pub const ZON = @import("files/zon.zig").ZON;

pub const RoseFile = struct {
    const Self = @This();

    pub const Config = struct {
        endian: std.builtin.Endian = .Little,
        wide_strings: bool = false,
    };

    allocator: std.mem.Allocator,
    config: Config,

    file: fs.File,
    reader: fs.File.Reader,
    writer: fs.File.Writer,

    pub fn init(allocator: std.mem.Allocator, file: fs.File, config: Config) !Self {
        return .{
            .allocator = allocator,
            .config = config,
            .file = file,
            .reader = file.reader(),
            .writer = file.writer(),
        };
    }

    pub fn readInt(self: Self, comptime T: type) !T {
        return try self.reader.readInt(T, self.config.endian);
    }

    pub fn writeInt(self: Self, comptime T: type, value: T) !void {
        try self.writer.writeInt(T, value, self.config.endian);
    }

    // there is probably a better way to do this
    fn floatToIntType(comptime T: type) !type {
        return switch (T) {
            f16 => i16,
            f32 => i32,
            f64 => i64,
            f128 => i128,
            else => return error.InvalidFloatType,
        };
    }

    pub fn readFloat(self: Self, comptime T: type) !T {
        const intType = try floatToIntType(T);
        const int = try self.readInt(intType);
        return @as(T, @bitCast(int));
    }

    pub fn writeFloat(self: Self, comptime T: type, value: T) !void {
        const intType = try floatToIntType(T);
        try self.writeInt(intType, @as(intType, @bitCast(value)));
    }

    pub fn readVarString(self: Self, n: u64) ![]u8 {
        if (n == 0) {
            return "";
        }

        var buf = try self.allocator.alloc(u8, n);
        _ = try self.reader.read(buf);

        // TODO: decode wide strings
        // if (self.config.wide_strings) {
        //     return utf8ToUtf16Le(buf);
        // }

        return buf;
    }

    pub fn readString(self: Self, comptime T: type) ![]u8 {
        const len = try self.reader.readInt(T, self.config.endian);
        return try self.readVarString(len);
    }

    pub fn writeVarString(self: Self, n: u64, value: []u8) !void {
        const char_count = @min(n, value.len);
        var i: usize = 0;
        while (i < n) {
            try self.writeInt(u8, if (i < char_count) value[i] else 0);
            i += 1;
        }
    }

    pub fn writeString(self: Self, comptime T: type, value: []const u8) !void {
        try self.writeInt(T, @as(T, @intCast(value.len)));
        try self.writer.writeAll(value);
    }

    pub fn readBool(self: Self) !bool {
        return try self.reader.readByte() == 1;
    }

    pub fn writeBool(self: Self, value: bool) !void {
        try self.writer.writeByte(if (value) 1 else 0);
    }

    pub fn readVec2(self: Self, comptime T: type) !Vec2(T) {
        return Vec2(T).init(try self.readInt(T), try self.readInt(T));
    }

    pub fn writeVec2(self: Self, comptime T: type, value: Vec2(T)) !void {
        try self.writeInt(T, value.x);
        try self.writeInt(T, value.y);
    }

    pub fn readFloatVec2(self: Self, comptime T: type) !Vec2(T) {
        return Vec2(T).init(try self.readFloat(T), try self.readFloat(T));
    }

    pub fn readVec3(self: Self, comptime T: type) !Vec3(T) {
        return Vec3(T).init(try self.readInt(T), try self.readInt(T), try self.readInt(T));
    }

    pub fn writeVec3(self: Self, comptime T: type, value: Vec3(T)) !void {
        try self.writeInt(T, value.x);
        try self.writeInt(T, value.y);
        try self.writeInt(T, value.z);
    }

    pub fn readFloatVec3(self: Self, comptime T: type) !Vec3(T) {
        return Vec3(T).init(try self.readFloat(T), try self.readFloat(T), try self.readFloat(T));
    }
};

pub fn Vec2(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return .{
                .x = x,
                .y = y,
            };
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return .{
                .x = x,
                .y = y,
                .z = z,
            };
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
