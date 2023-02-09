const std = @import("std");
const RoseTools = @import("rosetools");

const debug = std.debug;
const RoseFile = RoseTools.RoseFile;
const HIM = RoseTools.HIM;

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

    var him = HIM.init();
    try him.read(allocator, rosefile);

    debug.print("size: {}x{}\n", .{ him.width, him.height });
    debug.print("grid count: {}\n", .{him.grid_count});
    debug.print("scale: {}\n", .{him.scale});
    debug.print("heights: {}\n", .{him.heights.len * him.heights[0].len});
    debug.print("patches: {}\n", .{him.patches.len * him.patches[0].len});
    debug.print("quad patches: {}\n", .{him.quad_patches.len});

    //try him.write(allocator, rosefile);
}
