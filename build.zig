const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("glfw_opengl_template", .{
        .root_source_file = b.path("src/root.zig"),

        .target = target,
    });

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zgui = b.dependency("zgui", .{
        .target = target,
        .optimize = optimize,
        .shared = false,
        .with_implot = true,
    });

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });

    const zpool = b.dependency("zpool", .{});
    const zgpu = b.dependency("zgpu", .{});

    const exe = b.addExecutable(.{
        .name = "glfw_opengl_template",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "glfw_opengl_template", .module = mod },
            },
        }),
    });

    exe.root_module.addImport("gl", gl_bindings);
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("zpool", zpool.module("root"));
    exe.root_module.addImport("zgpu", zgpu.module("root"));

    // Link the compiled GLFW library from glfw_zig so zglfw's extern declarations resolve
    if (target.result.os.tag != .emscripten) {
        exe.linkLibrary(zglfw.artifact("glfw"));
    }
    exe.linkLibrary(zgui.artifact("imgui"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
