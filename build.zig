const std = @import("std");
const zgui = @import("libs/zgui/build.zig");
const zglfw = @import("libs/zglfw/build.zig");
const zgpu = @import("libs/zgpu/build.zig");
const zpool = @import("libs/zpool/build.zig");
const zstbi = @import("libs/zstbi/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests.");
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/rosetools.zig" },
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&tests.step);

    const examples_step = b.step("examples", "Build examples");
    inline for (.{
        "him",
        "idx",
        "til",
        "tsi",
        "vfs",
        "zon",
    }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = "examples/" ++ example_name ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example.addAnonymousModule("rosetools", .{ .source_file = .{ .path = "src/rosetools.zig" } });
        b.installArtifact(example);
        examples_step.dependOn(&example.step);
    }

    const ui_step = b.step("ui", "UI build");
    const ui = b.addExecutable(.{
        .name = "rosetools-gui",
        .root_source_file = .{ .path = "ui/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_wgpu },
    });
    zgui_pkg.link(ui);

    // Needed for glfw/wgpu rendering backend
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .deps = .{ .zpool = zpool_pkg.zpool, .zglfw = zglfw_pkg.zglfw },
    });
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});

    zglfw_pkg.link(ui);
    zgpu_pkg.link(ui);
    zstbi_pkg.link(ui);

    ui.addIncludePath(std.Build.LazyPath.relative("libs/DDS"));

    ui.addAnonymousModule("rosetools", .{ .source_file = .{ .path = "src/rosetools.zig" } });
    b.installArtifact(ui);
    ui_step.dependOn(&ui.step);

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_step);
    all_step.dependOn(examples_step);
    all_step.dependOn(ui_step);

    b.default_step.dependOn(all_step);
}
