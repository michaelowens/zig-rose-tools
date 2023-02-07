const std = @import("std");
const RoseTools = @import("rosetools");

const debug = std.debug;
const RoseFile = RoseTools.RoseFile;
const TSI = RoseTools.TSI;

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

    var tsi = TSI.init();
    try tsi.read(allocator, rosefile);

    debug.print("spritesheets: {}\n", .{tsi.sprite_sheets.len});

    for (tsi.sprite_sheets) |sprite_sheet| {
        debug.print("{s}: {} sprites\n", .{ sprite_sheet.path, sprite_sheet.sprites.len });
    }

    try tsi.write(rosefile);
}
