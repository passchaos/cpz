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
        .root_source_file = b.path("bench/bench.zig"),
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
        .root_source_file = b.path("tools/cpzc.zig"),
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
        .root_source_file = b.path("tools/cpzc.zig"),
        .target = b.graph.host,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const cpzc_host = b.addExecutable(.{
        .name = "cpzc-host",
        .root_module = cpzc_host_mod,
    });

    const run_generated_example_codegen = b.addRunArtifact(cpzc_host);
    run_generated_example_codegen.addArgs(&.{"--no-metadata"});
    run_generated_example_codegen.addFileArg(b.path("examples/generated_addressbook.capnp"));
    const generated_example_schema = b.createModule(.{
        .root_source_file = run_generated_example_codegen.captureStdOut(.{ .basename = "generated_addressbook_schema.zig" }),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const generated_example_mod = b.createModule(.{
        .root_source_file = b.path("examples/generated_addressbook.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpz", .module = cpz_mod },
            .{ .name = "generated_addressbook", .module = generated_example_schema },
        },
    });
    const generated_example = b.addExecutable(.{
        .name = "cpz-generated-addressbook",
        .root_module = generated_example_mod,
    });
    b.installArtifact(generated_example);

    const run_generated_example = b.addRunArtifact(generated_example);
    const generated_example_step = b.step("run-generated", "Run the generated-code addressbook example");
    generated_example_step.dependOn(&run_generated_example.step);

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

    addCpzOnlyTest(b, test_step, "tools/cpzc.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "tests/malformed_input_smoke.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "tests/public_api_smoke.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "src/rpc.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "tests/upstream_testdata_smoke.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "tests/upstream_rpc_schema_smoke.zig", target, optimize, cpz_mod);
    addCpzOnlyTest(b, test_step, "tests/fuzz_smoke.zig", target, optimize, cpz_mod);

    const fuzz_mod = b.createModule(.{
        .root_source_file = b.path("tests/fuzz_smoke.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const fuzz_tests = b.addTest(.{ .root_module = fuzz_mod });
    const run_fuzz = addTestRun(b, fuzz_tests);
    const fuzz_step = b.step("fuzz", "Run fuzz corpus smoke (use `zig build test --fuzz` for continuous fuzzing)");
    fuzz_step.dependOn(&run_fuzz.step);

    const generated_import_base = addGeneratedModule(b, target, optimize, cpz_mod, cpzc_host, .{
        .schema = "tests/schema_import_base.capnp",
        .basename = "schema_import_base.zig",
    });
    const import_extra_imports = [_]ExtraImport{
        .{ .name = "Base", .module = generated_import_base },
        .{ .name = "schema_import_base", .module = generated_import_base },
        .{ .name = "Child", .module = generated_import_base },
        .{ .name = "Local", .module = generated_import_base },
        .{ .name = "Extra", .module = generated_import_base },
    };

    const generated_tests = [_]GeneratedTestSpec{
        .{
            .schema = "tests/schema_smoke.capnp",
            .basename = "schema_smoke.zig",
            .test_file = "tests/codegen_smoke.zig",
            .import_name = "generated_schema",
        },
        .{
            .schema = "tests/schema_method_defaults.capnp",
            .basename = "schema_method_defaults.zig",
            .test_file = "tests/codegen_method_defaults_smoke.zig",
            .import_name = "generated_method_defaults_schema",
        },
        .{
            .schema = "tests/schema_scalar_const_lists.capnp",
            .basename = "schema_scalar_const_lists.zig",
            .test_file = "tests/codegen_scalar_const_lists_smoke.zig",
            .import_name = "generated_scalar_const_lists_schema",
        },
        .{
            .schema = "tests/schema_capability_table.capnp",
            .basename = "schema_capability_table.zig",
            .test_file = "tests/codegen_capability_table_smoke.zig",
            .import_name = "generated_capability_table_schema",
        },
        .{
            .schema = "tests/schema_rpc_event.capnp",
            .basename = "schema_rpc_event.zig",
            .test_files = &.{
                "tests/codegen/rpc_event/wire.zig",
                "tests/codegen/rpc_event/dispatch_1.zig",
                "tests/codegen/rpc_event/dispatch_2.zig",
                "tests/codegen/rpc_event/handoff_1.zig",
                "tests/codegen/rpc_event/handoff_2.zig",
                "tests/codegen/rpc_event/handoff_3.zig",
                "tests/codegen/rpc_event/turn_plan_1.zig",
                "tests/codegen/rpc_event/turn_plan_2.zig",
                "tests/codegen/rpc_event/turn_output.zig",
                "tests/codegen/rpc_event/state.zig",
            },
            .import_name = "generated_rpc_event_schema",
            .test_support = "tests/support/rpc_event.zig",
        },
        .{
            .schema = "tests/schema_no_file_id.capnp",
            .basename = "schema_no_file_id.zig",
            .test_file = "tests/codegen_no_file_id_smoke.zig",
            .import_name = "generated_no_file_id_schema",
        },
        .{
            .schema = "tests/schema_lazy_codegen.capnp",
            .basename = "schema_lazy_codegen.zig",
            .test_file = "tests/codegen_lazy_smoke.zig",
            .import_name = "generated_lazy_schema",
        },
        .{
            .schema = "tests/schema_keywords.capnp",
            .basename = "schema_keywords.zig",
            .test_file = "tests/codegen_keyword_smoke.zig",
            .import_name = "generated_keyword_schema",
        },
        .{
            .schema = "tests/schema_namespace.capnp",
            .basename = "schema_namespace.zig",
            .test_file = "tests/codegen_namespace_smoke.zig",
            .import_name = "generated_namespace_schema",
            .args = &.{ "--namespace", "api" },
        },
        .{
            .schema = "tests/schema_import_use.capnp",
            .basename = "schema_import_use.zig",
            .test_file = "tests/codegen_import_smoke.zig",
            .import_name = "generated_import_use",
            .generated_extra_imports = &import_extra_imports,
            .test_extra_imports = &.{.{ .name = "Base", .module = generated_import_base }},
        },
        .{
            .schema = "tests/schema_import_use.capnp",
            .basename = "schema_import_use_namespace.zig",
            .test_file = "tests/codegen_import_namespace_smoke.zig",
            .import_name = "generated_import_use_namespace",
            .args = &.{ "--namespace", "api" },
            .generated_extra_imports = &import_extra_imports,
        },
        .{
            .schema = "tests/schema_lean.capnp",
            .basename = "schema_lean.zig",
            .test_file = "tests/codegen_lean_smoke.zig",
            .import_name = "generated_lean_schema",
            .args = &.{"--no-metadata"},
        },
        .{
            .schema = "tests/schema_lean.capnp",
            .basename = "schema_minimal.zig",
            .test_file = "tests/codegen_minimal_smoke.zig",
            .import_name = "generated_minimal_schema",
            .args = &.{ "--no-metadata", "--no-introspection" },
        },
    };
    for (generated_tests) |spec| {
        addGeneratedSchemaTest(b, test_step, target, optimize, cpz_mod, cpzc_host, spec);
    }

    const fmt_step = b.step("fmt", "Format Zig sources");
    const fmt = b.addFmt(.{
        .paths = &.{ "build.zig", "src", "tools", "bench", "examples", "tests" },
        .check = false,
    });
    fmt_step.dependOn(&fmt.step);

    const check_fmt = b.addFmt(.{
        .paths = &.{ "build.zig", "src", "tools", "bench", "examples", "tests" },
        .check = true,
    });
    const check_step = b.step("check", "Check formatting, compile examples, and run tests");
    check_step.dependOn(&check_fmt.step);
    check_step.dependOn(test_step);
    check_step.dependOn(&example.step);
    check_step.dependOn(&bench.step);
    check_step.dependOn(&generated_example.step);
}

const ExtraImport = struct {
    name: []const u8,
    module: *std.Build.Module,
};

const GeneratedModuleSpec = struct {
    schema: []const u8,
    basename: []const u8,
    args: []const []const u8 = &.{},
    extra_imports: []const ExtraImport = &.{},
};

const GeneratedTestSpec = struct {
    schema: []const u8,
    basename: []const u8,
    test_file: ?[]const u8 = null,
    test_files: []const []const u8 = &.{},
    import_name: []const u8,
    args: []const []const u8 = &.{},
    generated_extra_imports: []const ExtraImport = &.{},
    test_extra_imports: []const ExtraImport = &.{},
    test_support: ?[]const u8 = null,
};

fn addGeneratedModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cpz_mod: *std.Build.Module,
    cpzc_host: *std.Build.Step.Compile,
    spec: GeneratedModuleSpec,
) *std.Build.Module {
    const run = b.addRunArtifact(cpzc_host);
    if (spec.args.len != 0) run.addArgs(spec.args);
    run.addFileArg(b.path(spec.schema));

    var imports = std.ArrayList(std.Build.Module.Import).empty;
    defer imports.deinit(b.allocator);
    imports.append(b.allocator, .{ .name = "cpz", .module = cpz_mod }) catch @panic("OOM");
    for (spec.extra_imports) |extra| {
        imports.append(b.allocator, .{ .name = extra.name, .module = extra.module }) catch @panic("OOM");
    }
    return b.createModule(.{
        .root_source_file = run.captureStdOut(.{ .basename = spec.basename }),
        .target = target,
        .optimize = optimize,
        .imports = imports.items,
    });
}

fn addGeneratedSchemaTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cpz_mod: *std.Build.Module,
    cpzc_host: *std.Build.Step.Compile,
    spec: GeneratedTestSpec,
) void {
    const generated = addGeneratedModule(b, target, optimize, cpz_mod, cpzc_host, .{
        .schema = spec.schema,
        .basename = spec.basename,
        .args = spec.args,
        .extra_imports = spec.generated_extra_imports,
    });

    if (spec.test_file) |test_file| {
        addGeneratedTestFile(b, test_step, target, optimize, cpz_mod, generated, spec, test_file);
    }
    for (spec.test_files) |test_file| {
        addGeneratedTestFile(b, test_step, target, optimize, cpz_mod, generated, spec, test_file);
    }
}

fn addGeneratedTestFile(
    b: *std.Build,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cpz_mod: *std.Build.Module,
    generated: *std.Build.Module,
    spec: GeneratedTestSpec,
    test_file: []const u8,
) void {
    var imports = std.ArrayList(std.Build.Module.Import).empty;
    defer imports.deinit(b.allocator);
    imports.append(b.allocator, .{ .name = "cpz", .module = cpz_mod }) catch @panic("OOM");
    imports.append(b.allocator, .{ .name = spec.import_name, .module = generated }) catch @panic("OOM");
    if (spec.test_support) |support_path| {
        const support_mod = b.createModule(.{
            .root_source_file = b.path(support_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "cpz", .module = cpz_mod },
                .{ .name = spec.import_name, .module = generated },
            },
        });
        imports.append(b.allocator, .{ .name = "test_support", .module = support_mod }) catch @panic("OOM");
    }
    for (spec.test_extra_imports) |extra| {
        imports.append(b.allocator, .{ .name = extra.name, .module = extra.module }) catch @panic("OOM");
    }

    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_file),
        .target = target,
        .optimize = optimize,
        .imports = imports.items,
    });
    const tests = b.addTest(.{ .root_module = test_mod });
    test_step.dependOn(&addTestRun(b, tests).step);
}

fn addTestRun(b: *std.Build, test_exe: *std.Build.Step.Compile) *std.Build.Step.Run {
    const run = b.addRunArtifact(test_exe);
    // Cross-target builds should still compile every test artifact, but a Linux
    // host cannot execute e.g. Windows test binaries without an external runner.
    // Let Zig mark those run steps skipped instead of failing the entire build.
    run.skip_foreign_checks = true;
    return run;
}

fn addCpzOnlyTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cpz_mod: *std.Build.Module,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
    });
    const tests = b.addTest(.{ .root_module = test_mod });
    test_step.dependOn(&addTestRun(b, tests).step);
}
