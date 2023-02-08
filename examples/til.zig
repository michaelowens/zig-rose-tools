const std = @import("std");
const RoseTools = @import("rosetools");

const debug = std.debug;
const RoseFile = RoseTools.RoseFile;
const TIL = RoseTools.TIL;

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

    var til = TIL.init();
    try til.read(allocator, rosefile);

    debug.print("size: {}x{}\n", .{ til.width, til.height });

    //try til.write(rosefile);
}
