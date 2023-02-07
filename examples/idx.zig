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
    const path = args.next();

    if (path == null) {
        debug.print("no path argument given", .{});
        return;
    }

    const abs_file_path = try std.fs.realpathAlloc(allocator, path.?);
    const file = try std.fs.openFileAbsolute(abs_file_path, .{ .mode = .read_write });
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});

    var idx = IDX.init();
    try idx.read(allocator, rosefile);

    debug.print("base version: {}\n", .{idx.base_version});
    debug.print("current version: {}\n", .{idx.current_version});
    debug.print("file systems: {}\n\n", .{idx.file_systems.len});

    for (idx.file_systems) |vfs| {
        debug.print("path: {s}\n", .{vfs.filename});
        debug.print("files: {}\n", .{vfs.files.len});
        debug.print("1st file: {s}\n", .{vfs.files[0].filepath});
        debug.print("last file: {s}\n\n", .{vfs.files[vfs.files.len - 1].filepath});
    }

    try idx.write(allocator, rosefile);
}
