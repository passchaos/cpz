const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cpz_mod = b.addModule("cpz", .{
        .root_source_file = b.path("src/cpz.zig"),
    });

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/cpz.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_unit_tests = addTestRun(b, unit_tests);

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/addressbook.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const example = b.addExecutable(.{
        .name = "cpz-addressbook",
        .root_module = example_mod,
    });
    b.installArtifact(example);

    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const bench = b.addExecutable(.{
        .name = "cpz-bench",
        .root_module = bench_mod,
    });
    b.installArtifact(bench);

    const cpzc_mod = b.createModule(.{
        .root_source_file = b.path("src/cpzc.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const cpzc = b.addExecutable(.{
        .name = "cpzc",
        .root_module = cpzc_mod,
    });
    b.installArtifact(cpzc);

    const cpzc_host_mod = b.createModule(.{
        .root_source_file = b.path("src/cpzc.zig"),
        .target = b.graph.host,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const cpzc_host = b.addExecutable(.{
        .name = "cpzc-host",
        .root_module = cpzc_host_mod,
    });

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run a microbenchmark over dynamic readers");
    bench_step.dependOn(&run_bench.step);

    const run_cpzc = b.addRunArtifact(cpzc);
    if (b.args) |args| run_cpzc.addArgs(args);
    const cpzc_step = b.step("cpzc", "Run the Cap'n Proto schema-to-Zig skeleton generator");
    cpzc_step.dependOn(&run_cpzc.step);

    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    const run_step = b.step("run", "Run the addressbook example");
    run_step.dependOn(&run_example.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const cpzc_test_mod = b.createModule(.{
        .root_source_file = b.path("src/cpzc.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const cpzc_tests = b.addTest(.{ .root_module = cpzc_test_mod });
    test_step.dependOn(&addTestRun(b, cpzc_tests).step);

    const run_schema_codegen = b.addRunArtifact(cpzc_host);
    run_schema_codegen.addFileArg(b.path("tests/schema_smoke.capnp"));
    const generated_schema = b.createModule(.{
        .root_source_file = run_schema_codegen.captureStdOut(.{ .basename = "schema_smoke.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const codegen_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "generated_schema", .module = generated_schema },
        },
    });
    const codegen_smoke_tests = b.addTest(.{ .root_module = codegen_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_smoke_tests).step);

    const run_method_defaults_codegen = b.addRunArtifact(cpzc_host);
    run_method_defaults_codegen.addFileArg(b.path("tests/schema_method_defaults.capnp"));
    const generated_method_defaults_schema = b.createModule(.{
        .root_source_file = run_method_defaults_codegen.captureStdOut(.{ .basename = "schema_method_defaults.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const codegen_method_defaults_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_method_defaults_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "generated_method_defaults_schema", .module = generated_method_defaults_schema },
        },
    });
    const codegen_method_defaults_smoke_tests = b.addTest(.{ .root_module = codegen_method_defaults_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_method_defaults_smoke_tests).step);

    const run_scalar_const_lists_codegen = b.addRunArtifact(cpzc_host);
    run_scalar_const_lists_codegen.addFileArg(b.path("tests/schema_scalar_const_lists.capnp"));
    const generated_scalar_const_lists_schema = b.createModule(.{
        .root_source_file = run_scalar_const_lists_codegen.captureStdOut(.{ .basename = "schema_scalar_const_lists.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const codegen_scalar_const_lists_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_scalar_const_lists_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "generated_scalar_const_lists_schema", .module = generated_scalar_const_lists_schema },
        },
    });
    const codegen_scalar_const_lists_smoke_tests = b.addTest(.{ .root_module = codegen_scalar_const_lists_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_scalar_const_lists_smoke_tests).step);

    const run_keyword_schema_codegen = b.addRunArtifact(cpzc_host);
    run_keyword_schema_codegen.addFileArg(b.path("tests/schema_keywords.capnp"));
    const generated_keyword_schema = b.createModule(.{
        .root_source_file = run_keyword_schema_codegen.captureStdOut(.{ .basename = "schema_keywords.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const codegen_keyword_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_keyword_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "generated_keyword_schema", .module = generated_keyword_schema },
        },
    });
    const codegen_keyword_smoke_tests = b.addTest(.{ .root_module = codegen_keyword_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_keyword_smoke_tests).step);

    const run_namespace_schema_codegen = b.addRunArtifact(cpzc_host);
    run_namespace_schema_codegen.addArgs(&.{ "--namespace", "api" });
    run_namespace_schema_codegen.addFileArg(b.path("tests/schema_namespace.capnp"));
    const generated_namespace_schema = b.createModule(.{
        .root_source_file = run_namespace_schema_codegen.captureStdOut(.{ .basename = "schema_namespace.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const codegen_namespace_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_namespace_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "generated_namespace_schema", .module = generated_namespace_schema },
        },
    });
    const codegen_namespace_smoke_tests = b.addTest(.{ .root_module = codegen_namespace_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_namespace_smoke_tests).step);

    const run_import_base_codegen = b.addRunArtifact(cpzc_host);
    run_import_base_codegen.addFileArg(b.path("tests/schema_import_base.capnp"));
    const generated_import_base = b.createModule(.{
        .root_source_file = run_import_base_codegen.captureStdOut(.{ .basename = "schema_import_base.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const run_import_use_codegen = b.addRunArtifact(cpzc_host);
    run_import_use_codegen.addFileArg(b.path("tests/schema_import_use.capnp"));
    const generated_import_use = b.createModule(.{
        .root_source_file = run_import_use_codegen.captureStdOut(.{ .basename = "schema_import_use.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "Base", .module = generated_import_base },
            .{ .name = "schema_import_base", .module = generated_import_base },
            .{ .name = "Child", .module = generated_import_base },
            .{ .name = "Local", .module = generated_import_base },
            .{ .name = "Extra", .module = generated_import_base },
        },
    });
    const codegen_import_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_import_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "Base", .module = generated_import_base },
            .{ .name = "generated_import_use", .module = generated_import_use },
        },
    });
    const codegen_import_smoke_tests = b.addTest(.{ .root_module = codegen_import_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_import_smoke_tests).step);

    const run_import_use_namespace_codegen = b.addRunArtifact(cpzc_host);
    run_import_use_namespace_codegen.addArgs(&.{ "--namespace", "api" });
    run_import_use_namespace_codegen.addFileArg(b.path("tests/schema_import_use.capnp"));
    const generated_import_use_namespace = b.createModule(.{
        .root_source_file = run_import_use_namespace_codegen.captureStdOut(.{ .basename = "schema_import_use_namespace.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "Base", .module = generated_import_base },
            .{ .name = "schema_import_base", .module = generated_import_base },
            .{ .name = "Child", .module = generated_import_base },
            .{ .name = "Local", .module = generated_import_base },
            .{ .name = "Extra", .module = generated_import_base },
        },
    });
    const codegen_import_namespace_smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/codegen_import_namespace_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "generated_import_use_namespace", .module = generated_import_use_namespace },
        },
    });
    const codegen_import_namespace_smoke_tests = b.addTest(.{ .root_module = codegen_import_namespace_smoke_mod });
    test_step.dependOn(&addTestRun(b, codegen_import_namespace_smoke_tests).step);

    const fmt_step = b.step("fmt", "Format Zig sources");
    const fmt = b.addFmt(.{
        .paths = &.{ "build.zig", "src", "examples", "tests" },
        .check = false,
    });
    fmt_step.dependOn(&fmt.step);

    const check_fmt = b.addFmt(.{
        .paths = &.{ "build.zig", "src", "examples", "tests" },
        .check = true,
    });
    const check_step = b.step("check", "Check formatting, compile examples, and run tests");
    check_step.dependOn(&check_fmt.step);
    check_step.dependOn(test_step);
    check_step.dependOn(&example.step);
    check_step.dependOn(&bench.step);
}

fn addTestRun(b: *std.Build, test_exe: *std.Build.Step.Compile) *std.Build.Step.Run {
    const run = b.addRunArtifact(test_exe);
    // Cross-target builds should still compile every test artifact, but a Linux
    // host cannot execute e.g. Windows test binaries without an external runner.
    // Let Zig mark those run steps skipped instead of failing the entire build.
    run.skip_foreign_checks = true;
    return run;
}
