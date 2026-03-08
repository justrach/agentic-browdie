const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "agentic-browdie",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Run step
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);


    // merjs E2E test binary
    const merjs_e2e = b.addExecutable(.{
        .name = "merjs-e2e",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test/merjs_e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(merjs_e2e);
    const run_merjs_e2e = b.addRunArtifact(merjs_e2e);
    const merjs_e2e_step = b.step("merjs-e2e", "Run merjs E2E tests (requires merjs + browdie + Chrome live)");
    merjs_e2e_step.dependOn(&run_merjs_e2e.step);

    // Benchmarks
    const bench = b.addExecutable(.{
        .name = "browdie-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
