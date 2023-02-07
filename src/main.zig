const std = @import("std");
const RoseFile = @import("rosefile.zig").RoseFile;
const IDX = @import("files/idx.zig").IDX;
const TSI = @import("files/tsi.zig").TSI;
const eql = std.mem.eql;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    const program_name = args.next() orelse "";

    var arg_file_type = args.next() orelse "";
    if (eql(u8, arg_file_type, "")) {
        std.log.err("Missing file type argument\nUsage: {s} <file type> <file path>", .{program_name});
        std.process.exit(0);
    }

    const arg_file_path = args.next() orelse "";
    if (eql(u8, arg_file_path, "")) {
        std.log.err("Missing file path argument\nUsage: {s} <file type> <file path>", .{program_name});
        std.process.exit(0);
    }

    var buf: [1024]u8 = undefined;
    const arg_file_type_lower = std.ascii.lowerString(&buf, arg_file_type);
    if (eql(u8, arg_file_type_lower, "idx")) {
        try test_idx(allocator, arg_file_path);
    } else if (eql(u8, arg_file_type_lower, "tsi")) {
        try test_tsi(allocator, arg_file_path);
    } else {
        std.log.err("Unknown file type", .{});
        std.process.exit(0);
    }
}

fn test_idx(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_write });
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});

    var idx = IDX.init();
    try idx.read(allocator, rosefile);

    std.log.debug("base version: {}", .{idx.base_version});
    std.log.debug("current version: {}", .{idx.current_version});
    std.log.debug("vfs files #: {}\n", .{idx.file_systems.len});

    for (idx.file_systems) |vfs| {
        std.log.debug("path: {s}", .{vfs.filename});
        std.log.debug("files: {}", .{vfs.files.len});
        std.log.debug("1st file: {s}", .{vfs.files[0].filepath});
        std.log.debug("last file: {s}\n", .{vfs.files[vfs.files.len - 1].filepath});
    }

    try idx.write(allocator, rosefile);
}

fn test_tsi(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_write });
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});

    var tsi = TSI.init();
    try tsi.read(allocator, rosefile);

    std.log.debug("spritesheets: {}", .{tsi.sprite_sheets.len});

    for (tsi.sprite_sheets) |sprite_sheet| {
        std.log.debug("{s}: {} sprites", .{ sprite_sheet.path, sprite_sheet.sprites.len });
    }

    try tsi.write(rosefile);
}
