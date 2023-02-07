const std = @import("std");

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
        "idx",
        "tsi",
    }) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = "examples/" ++ example_name ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example.addAnonymousModule("rosetools", .{ .source_file = .{ .path = "src/rosetools.zig" } });
        example.install();
        examples_step.dependOn(&example.step);
    }

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(test_step);
    all_step.dependOn(examples_step);

    b.default_step.dependOn(all_step);
}
