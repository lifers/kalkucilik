const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .x86_64,
        .cpu_features_add = std.Target.x86.featureSet(&.{ .cx16, .sahf, .prfchw }),
        .os_tag = .windows,
        .os_version_min = .{ .windows = .win10_19h1 },
        .abi = .msvc,
    } });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kalkucilik",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .win32_manifest = b.path("src/app.manifest"),
    });
    // exe.entry = .{ .symbol_name = "mainCRTStartup" };
    exe.subsystem = .Windows;
    exe.root_module.addAnonymousImport(
        "win32",
        .{ .root_source_file = b.path("zigwin32/win32.zig") },
    );
    exe.addLibraryPath(.{ .cwd_relative = "C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.26100.0\\ucrt\\x64" });
    exe.linkSystemLibrary2("ucrt", .{ .preferred_link_mode = .dynamic });
    // exe.addCSourceFile(.{
    //     .file = b.path("src/BigFloat.cpp"),
    //     .flags = if (optimize == .Debug) &.{
    //         "-std=c++20",
    //         "-g3",
    //         "-Wall",
    //         "-Wextra",
    //         "-DBOOST_DISABLE_THREADS",
    //     } else &.{
    //         "-std=c++20", "-Oz", "-Wall", "-Wextra", "-v",
    //     },
    // });
    // exe.mingw_unicode_entry_point = true;
    // exe.addIncludePath(b.path("src/"));
    // exe.addIncludePath(b.path("boost.1.87.0/lib/native/include/"));
    // exe.linkLibCpp();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
