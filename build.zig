const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Boehm GC
    const gc = b.addStaticLibrary(.{
        .name = "gc",
        .target = target,
        .optimize = optimize,
    });
    {
        const cflags = [_][]const u8{};
        const libgc_srcs = [_][]const u8{
            "alloc.c",    "reclaim.c", "allchblk.c", "misc.c",     "mach_dep.c", "os_dep.c",
            "mark_rts.c", "headers.c", "mark.c",     "obj_map.c",  "blacklst.c", "finalize.c",
            "new_hblk.c", "dbg_mlc.c", "malloc.c",   "dyn_load.c", "typd_mlc.c", "ptr_chck.c",
            "mallocx.c",
        };

        gc.linkLibC();
        if (target.isDarwin()) {
            gc.linkFramework("CoreServices");
        }
        gc.addIncludePath("deps/github.com/ivmai/bdwgc/include");
        inline for (libgc_srcs) |src| {
            gc.addCSourceFile("deps/github.com/ivmai/bdwgc/" ++ src, &cflags);
        }

        const gc_step = b.step("libgc", "build libgc");
        gc_step.dependOn(&gc.step);
    }

    const exe = b.addExecutable(.{
        .name = "bio",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath("deps/github.com/ivmai/bdwgc/include");
    exe.linkLibC();
    exe.linkLibrary(gc);

    if (!target.isWindows()) {
        exe.addCSourceFile("deps/linenoise.c", &[_][]const u8{"-std=c99", "-Wno-everything"});
        exe.addIncludePath("deps");
    }

    var inst = b.addInstallArtifact(exe);
    b.getInstallStep().dependOn(&inst.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
