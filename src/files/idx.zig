// Virtual File System Index

const std = @import("std");
const fs = std.fs;
const RoseFile = @import("../rosefile.zig").RoseFile;

pub const IDX = struct {
    const Self = @This();

    base_version: i32,
    current_version: i32,
    file_systems: []VFSMetadata,

    pub const VFSFile = struct {
        path: []u8,
        files: u32,
    };

    pub const VFSMetadata = struct {
        filename: []u8,
        files: []VFSFileMetadata,
    };

    pub const VFSFileMetadata = struct {
        filepath: []u8,
        offset: u32,
        size: u32,
        block_size: u32,
        is_deleted: bool,
        is_compressed: bool,
        is_encrypted: bool,
        version: u32,
        checksum: u32,
    };

    pub fn init() Self {
        return .{
            .base_version = 0,
            .current_version = 0,
            .file_systems = undefined,
        };
    }

    pub fn read(self: *Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        // readStruct reads correctly, but the seek pos moves 16 bytes rather than 12
        // https://github.com/ziglang/zig/issues/12960
        // const idx_metadata = try reader.readStruct(IDXMetadata);
        self.base_version = try file.readInt(i32);
        self.current_version = try file.readInt(i32);

        const vfs_count = try file.readInt(u32);
        self.file_systems = try allocator.alloc(VFSMetadata, vfs_count);

        var i: usize = 0;
        while (i < vfs_count) {
            defer i += 1;

            self.file_systems[i].filename = try file.readString(u16);
            const data_offset: u64 = try file.readInt(u32);

            try file.reader.context.seekTo(data_offset);
            const file_count = try file.readInt(u32);
            _ = try file.readInt(u32); // delete_count
            _ = try file.readInt(u32); // start_offset

            self.file_systems[i].files = try allocator.alloc(VFSFileMetadata, file_count);

            var f: usize = 0;
            while (f < file_count) {
                defer f += 1;

                self.file_systems[i].files[f] = .{
                    .filepath = try file.readString(u16),
                    .offset = try file.readInt(u32),
                    .size = try file.readInt(u32),
                    .block_size = try file.readInt(u32),
                    .is_deleted = try file.readBool(),
                    .is_compressed = try file.readBool(),
                    .is_encrypted = try file.readBool(),
                    .version = try file.readInt(u32),
                    .checksum = try file.readInt(u32),
                };
            }
        }
    }

    pub fn write(self: Self, allocator: std.mem.Allocator, file: RoseFile) !void {
        try file.writer.context.seekTo(0);
        try file.writer.context.setEndPos(0);
        try file.writeInt(i32, self.base_version);
        try file.writeInt(i32, self.current_version);
        try file.writeInt(u32, @intCast(u32, self.file_systems.len));

        var file_system_offsets = try allocator.alloc(u64, self.file_systems.len);
        defer allocator.free(file_system_offsets);

        for (self.file_systems) |vfs, i| {
            try file.writeString(u16, vfs.filename);
            file_system_offsets[i] = try file.writer.context.getPos();
            try file.writeInt(u32, 0);
        }

        for (self.file_systems) |vfs, i| {
            const file_offset = try file.writer.context.getPos();

            try file.writer.context.seekTo(file_system_offsets[i]);
            try file.writeInt(u32, @intCast(u32, file_offset));
            try file.writer.context.seekTo(file_offset);

            var deleted_count: u32 = 0;
            for (vfs.files) |f| {
                if (f.is_deleted) {
                    deleted_count += 1;
                }
            }

            try file.writeInt(u32, @intCast(u32, vfs.files.len));
            try file.writeInt(u32, deleted_count);
            try file.writeInt(u32, vfs.files[0].offset);

            for (vfs.files) |f| {
                try file.writeString(u16, f.filepath);
                try file.writeInt(u32, f.offset);
                try file.writeInt(u32, f.size);
                try file.writeInt(u32, f.block_size);
                try file.writeBool(f.is_deleted);
                try file.writeBool(f.is_compressed);
                try file.writeBool(f.is_encrypted);
                try file.writeInt(u32, f.version);
                try file.writeInt(u32, f.checksum);
            }
        }
    }
};
