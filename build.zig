const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zync_mod = b.addModule("zync", .{
        .root_source_file = b.path("src/zync.zig"),
        .target = target,
    });

    const client_exe = b.addExecutable(.{
        .name = "zync",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_client.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zync", .module = zync_mod },
            },
        }),
    });

    b.installArtifact(client_exe);

    const run_client_step = b.step("run", "Run the client");

    const run_client_cmd = b.addRunArtifact(client_exe);
    run_client_step.dependOn(&run_client_cmd.step);

    run_client_cmd.step.dependOn(b.getInstallStep());

    run_client_cmd.addPassthruArgs();

    const server_exe = b.addExecutable(.{
        .name = "zync-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_server.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zync", .module = zync_mod },
            },
        }),
    });

    b.installArtifact(server_exe);

    const run_server_step = b.step("run-server", "Run the server");

    const run_server_cmd = b.addRunArtifact(server_exe);
    run_server_step.dependOn(&run_server_cmd.step);

    run_server_cmd.step.dependOn(b.getInstallStep());

    run_server_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{
        .root_module = zync_mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = client_exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
