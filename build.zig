const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // This is the main library module that other packages will import
    const interface_module = b.addModule("interface", .{
        .root_source_file = b.path("src/CheckForInterfaceAtCmpTime.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test step
    const test_step = b.step("test", "Run all tests");

    // Tests for the main library file
    const lib_tests = b.addTest(.{
        .root_module = interface_module,
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    test_step.dependOn(&run_lib_tests.step);

    // Test files in test/ directory
    const test_files = [_][]const u8{
        "test/simple.zig",
        "test/complex.zig",
        "test/embedded.zig",
    };

    for (test_files) |test_file| {
        // Create a module for each test file
        const test_module = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });

        // Make the interface module available to the test
        test_module.addImport("interface", interface_module);

        const t = b.addTest(.{
            .root_module = test_module,
        });

        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }
}
