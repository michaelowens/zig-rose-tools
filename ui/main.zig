const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const Tree = @import("tree.zig");

const c = @import("c.zig");

const RoseTools = @import("rosetools");
const RoseFile = RoseTools.RoseFile;
const IDX = RoseTools.IDX;

const window_title = "rose-tools gui";

const SelectedFile = union(enum) {
    None: void,
    Image: struct {
        texture_view: zgpu.TextureViewHandle,
        dimensions: struct { width: u32, height: u32 },
    },
    Text: []u8,
    Unsupported: void,
};

const FileExtension = enum {
    const Self = @This();

    DDS,
    LUA,
    XML,
    CSS,
    HTML,
    Unknown,

    fn fromPath(path: []const u8) Self {
        const extensionStr = std.fs.path.extension(path);
        return std.meta.stringToEnum(Self, extensionStr[1..]) orelse .Unknown;
    }
};

const DemoState = struct {
    gctx: *zgpu.GraphicsContext,
    draw_list: zgui.DrawList,
    vfs_tree: Tree.Node,
    selected_node: ?Tree.Node,
    selected_file: SelectedFile,
};

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !*DemoState {
    const gctx = try zgpu.GraphicsContext.create(allocator, window, .{});

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    _ = arena;

    zgui.init(allocator);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.initWithConfig(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        .{ .texture_filter_mode = .linear, .pipeline_multisample_count = 1 },
    );

    const font_file_contents = @embedFile("Roboto-Regular.ttf");
    _ = zgui.io.addFontFromMemory(font_file_contents, 16);

    const draw_list = zgui.createDrawList();

    const demo = try allocator.create(DemoState);
    demo.* = .{
        .gctx = gctx,
        .draw_list = draw_list,
        .vfs_tree = Tree.Node{
            .path = "",
            .nodeType = .Folder,
            .meta = null,
            .children = std.ArrayList(Tree.Node).init(allocator),
        },
        .selected_node = null,
        .selected_file = .None,
    };

    return demo;
}

fn destroy(allocator: std.mem.Allocator, demo: *DemoState) void {
    zgui.backend.deinit();
    zgui.destroyDrawList(demo.draw_list);
    zgui.deinit();
    demo.gctx.destroy(allocator);
    allocator.destroy(demo);
}

fn update(allocator: std.mem.Allocator, demo: *DemoState) !void {
    zgui.backend.newFrame(
        demo.gctx.swapchain_descriptor.width,
        demo.gctx.swapchain_descriptor.height,
    );

    zgui.setNextWindowPos(.{
        .x = 0.0,
        .y = 0.0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = 300,
        .h = @floatFromInt(demo.gctx.swapchain_descriptor.height),
    });

    // Sidebar area
    if (zgui.begin("Sidebar", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .no_scrollbar = true,
            .no_scroll_with_mouse = true,
        },
    })) {
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Average :");
        zgui.sameLine(.{});
        zgui.text(
            "{d:.3} ms/frame ({d:.1} fps)",
            .{ demo.gctx.stats.average_cpu_time, demo.gctx.stats.fps },
        );

        if (zgui.button("Open file", .{})) {
            std.log.info("open file", .{});
            try openFile(allocator, demo);
        }

        if (zgui.beginChild("FileTree", .{
            .w = zgui.getWindowWidth() - 20,
            .flags = .{
                // .always_vertical_scrollbar = true,
            },
        })) {
            try drawFiles(allocator, &demo.vfs_tree, demo);
        }
        defer zgui.endChild();
    }
    zgui.end();

    // Main area
    zgui.setNextWindowPos(.{
        .x = 300.0,
        .y = 0.0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = @floatFromInt(demo.gctx.swapchain_descriptor.width - 300),
        .h = @floatFromInt(demo.gctx.swapchain_descriptor.height),
    });

    if (zgui.begin("Main", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .no_scrollbar = true,
            .no_scroll_with_mouse = true,
        },
    })) {
        switch (demo.selected_file) {
            .None => {},
            .Unsupported => {
                zgui.text("There is no preview for this file.", .{});
            },
            .Image => |img| {
                const tex_id = demo.gctx.lookupResource(img.texture_view).?;

                zgui.image(tex_id, .{
                    .w = @floatFromInt(img.dimensions.width),
                    .h = @floatFromInt(img.dimensions.height),
                });
            },
            .Text => |txt| {
                _ = zgui.inputTextMultiline("Filename", .{
                    .buf = txt,
                    .w = zgui.getWindowWidth() - 12.0,
                    .h = zgui.getWindowHeight() - 12.0,
                    .flags = .{
                        .read_only = true,
                    },
                });
            },
        }
    }
    zgui.end();
}

fn drawFiles(allocator: std.mem.Allocator, tree: *Tree.Node, demo: *DemoState) !void {
    const recursor = struct {
        fn search(allocatorr: std.mem.Allocator, node: *const Tree.Node, demoo: *DemoState) !void {
            for (node.children.items) |item| {
                if (item.nodeType == .Folder) {
                    if (zgui.treeNodeFlags(item.path, .{
                        // .open_on_double_click = true,
                        .span_avail_width = true,
                        .span_full_width = true,
                        .no_tree_push_on_open = false,
                    })) {
                        try search(allocatorr, &item, demoo);
                        zgui.treePop();
                    }
                }
            }

            for (node.children.items) |item| {
                if (item.nodeType == .File) {
                    var selected = false;
                    if (demoo.selected_node) |sn| {
                        selected = std.meta.eql(sn, item);
                    }
                    if (zgui.selectable(item.path, .{
                        .selected = selected,
                    })) {
                        const vfs_file = try std.fs.openFileAbsolute("D:\\Games\\ROSE Online\\rose.vfs", .{});
                        defer vfs_file.close();
                        const vfs_file_reader = vfs_file.reader();

                        try vfs_file_reader.context.seekTo(item.meta.?.offset);
                        var file_contents = try allocatorr.alloc(u8, item.meta.?.size);
                        _ = try vfs_file_reader.read(file_contents);

                        const extension = FileExtension.fromPath(item.path);

                        switch (extension) {
                            .DDS => {
                                demoo.selected_node = item;
                                const teststr = try allocatorr.dupeZ(u8, file_contents);

                                var img = c.dds_load_from_memory(teststr, @as(c_long, @intCast(item.meta.?.size)));
                                const image_dimensions = .{
                                    .width = img.*.header.width,
                                    .height = img.*.header.height,
                                };

                                const texture = demoo.gctx.createTexture(.{
                                    .size = image_dimensions,
                                    .format = .rgba8_unorm,
                                    .usage = .{
                                        .texture_binding = true,
                                        .copy_dst = true,
                                        .storage_binding = true,
                                    },
                                });

                                const texture_view = demoo.gctx.createTextureView(texture, .{});
                                demoo.selected_file = .{
                                    .Image = .{
                                        .texture_view = texture_view,
                                        .dimensions = image_dimensions,
                                    },
                                };

                                var pixelsSlice: []u8 = img.*.pixels[0 .. (img.*.header.width * img.*.header.height) * 4];
                                var data = std.ArrayList(u8).init(allocatorr);
                                var window_size = img.*.header.width * 4;
                                var it = std.mem.window(u8, pixelsSlice, window_size, window_size);
                                while (it.next()) |w| {
                                    try data.insertSlice(0, w);
                                }

                                demoo.gctx.queue.writeTexture(
                                    .{ .texture = demoo.gctx.lookupResource(texture).? },
                                    .{
                                        .bytes_per_row = img.*.header.width * 4,
                                        .rows_per_image = img.*.header.height,
                                    },
                                    image_dimensions,
                                    u8,
                                    data.items,
                                );
                            },
                            .LUA, .XML, .CSS, .HTML => {
                                demoo.selected_node = item;
                                demoo.selected_file = .{ .Text = file_contents };
                            },
                            .Unknown => {
                                demoo.selected_node = item;
                                demoo.selected_file = .Unsupported;
                            },
                        }
                    }
                }
            }
        }
    }.search;

    try recursor(allocator, tree, demo);
}

fn draw(demo: *DemoState) void {
    const gctx = demo.gctx;

    const swapchain_texv = gctx.swapchain.getCurrentTextureView();
    defer swapchain_texv.release();

    const commands = commands: {
        const encoder = gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Gui pass.
        {
            const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
            defer zgpu.endReleasePass(pass);
            zgui.backend.draw(pass);
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();
}

pub fn main() !void {
    zglfw.init() catch {
        std.log.err("Failed to initialize GLFW library.", .{});
        return;
    };
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.os.chdir(path) catch {};
    }

    const window = zglfw.Window.create(800, 400, window_title, null) catch {
        std.log.err("Failed to create demo window.", .{});
        return;
    };
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    zstbi.init(allocator);
    defer zstbi.deinit();

    const demo = create(allocator, window) catch {
        std.log.err("Failed to initialize the demo.", .{});
        return;
    };
    defer destroy(allocator, demo);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try update(allocator, demo);
        draw(demo);
    }
}

fn openFile(allocator: std.mem.Allocator, demo: *DemoState) !void {
    const path = "D:\\Games\\ROSE Online\\data.idx";
    const abs_file_path = try std.fs.realpathAlloc(allocator, path);
    const file = try std.fs.openFileAbsolute(abs_file_path, .{ .mode = .read_write });
    defer file.close();

    const rosefile = try RoseFile.init(allocator, file, .{});

    var idx = IDX.init();
    try idx.read(allocator, rosefile);

    for (idx.file_systems) |vfs| {
        var vfsNode = Tree.Node{
            .path = try allocator.dupeZ(u8, vfs.filename),
            .nodeType = .Folder,
            .meta = null,
            .children = std.ArrayList(Tree.Node).init(allocator),
        };

        for (vfs.files) |vfs_file_metadata| {
            _ = try Tree.addPath(allocator, &vfsNode, vfs_file_metadata.filepath, .File, .{
                .offset = vfs_file_metadata.offset,
                .size = vfs_file_metadata.size,
            });
        }
        try demo.vfs_tree.children.append(vfsNode);
    }
}
