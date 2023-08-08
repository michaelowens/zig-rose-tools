const std = @import("std");
const RoseTools = @import("rosetools");

const debug = std.debug;
const RoseFile = RoseTools.RoseFile;
const IDX = RoseTools.IDX;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const idx_path = args.next();
    const output_path = args.next();

    if (idx_path == null or output_path == null) {
        debug.print("no paths argument given, expected input idx path and output path", .{});
        return;
    }

    const abs_idx_file_path = try std.fs.realpathAlloc(allocator, idx_path.?);
    const file = try std.fs.openFileAbsolute(abs_idx_file_path, .{ .mode = .read_write });
    defer file.close();

    debug.print("abs_idx_file_path: {s}\n", .{abs_idx_file_path});

    const abs_idx_dir = std.fs.path.dirname(abs_idx_file_path);
    debug.print("abs_idx_dir: {s}\n", .{abs_idx_dir.?});

    const rosefile = try RoseFile.init(allocator, file, .{});

    var idx = IDX.init();
    try idx.read(allocator, rosefile);

    debug.print("base version: {}\n", .{idx.base_version});
    debug.print("current version: {}\n", .{idx.current_version});
    debug.print("file systems: {}\n\n", .{idx.file_systems.len});

    try std.fs.makeDirAbsolute(output_path.?);
    var dir = try std.fs.openDirAbsolute(output_path.?, .{ .no_follow = true });
    defer dir.close();

    for (idx.file_systems) |vfs| {
        debug.print("path: {s}\n", .{vfs.filename});
        debug.print("files: {}\n", .{vfs.files.len});
        debug.print("1st file: {s}\n", .{vfs.files[0].filepath});
        debug.print("last file: {s}\n\n", .{vfs.files[vfs.files.len - 1].filepath});

        const vfs_file_path = try std.fs.path.join(allocator, &[_][]const u8{ abs_idx_dir.?, vfs.filename });
        const vfs_file = try std.fs.openFileAbsolute(vfs_file_path, .{});
        defer vfs_file.close();
        const vfs_file_reader = vfs_file.reader();

        for (vfs.files) |vfs_file_metadata| {
            try vfs_file_reader.context.seekTo(vfs_file_metadata.offset);
            var file_contents = try allocator.alloc(u8, vfs_file_metadata.size);
            _ = try vfs_file_reader.read(file_contents);

            const abs_filepath = try std.fs.path.join(allocator, &[_][]const u8{ output_path.?, vfs_file_metadata.filepath });
            const abs_filepath_dir = std.fs.path.dirname(abs_filepath);

            try dir.makePath(abs_filepath_dir.?);
            const newFile = try std.fs.createFileAbsolute(abs_filepath, .{});
            defer newFile.close();
            _ = try newFile.write(file_contents);
        }
    }
}
