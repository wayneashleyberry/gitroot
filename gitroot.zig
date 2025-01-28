const std = @import("std");
const fs = std.fs;
const path = std.fs.path;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} [find-gitroot|init [fish|bash|zsh]]\n", .{args[0]});
        return;
    }

    if (std.mem.eql(u8, args[1], "find-gitroot")) {
        try findGitRoot(allocator);
    } else if (std.mem.eql(u8, args[1], "init")) {
        if (args.len < 3) {
            std.debug.print("Usage: {s} init [fish|bash|zsh]\n", .{args[0]});
            return;
        }
        try printAlias(args[2]);
    } else {
        std.debug.print("Unknown command: {s}\n", .{args[1]});
    }
}

fn findGitRoot(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const original_cwd = try fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(original_cwd);

    var current_path = try allocator.dupe(u8, original_cwd);
    defer allocator.free(current_path);

    while (true) {
        var dir = fs.openDirAbsolute(current_path, .{}) catch {
            try stdout.print("{s}\n", .{original_cwd});
            return;
        };
        defer dir.close();

        var git_dir = dir.openDir(".git", .{}) catch |err| {
            switch (err) {
                error.FileNotFound, error.NotDir => {
                    const parent_path = path.dirname(current_path) orelse {
                        try stdout.print("{s}\n", .{original_cwd});
                        return;
                    };

                    if (std.mem.eql(u8, parent_path, current_path)) {
                        try stdout.print("{s}\n", .{original_cwd});
                        return;
                    }

                    current_path = try allocator.dupe(u8, parent_path);
                    continue;
                },
                else => {
                    try stdout.print("{s}\n", .{original_cwd});
                    return;
                },
            }
        };
        git_dir.close();

        try stdout.print("{s}\n", .{current_path});
        return;
    }
}

fn printAlias(shell: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    if (std.mem.eql(u8, shell, "bash") or std.mem.eql(u8, shell, "zsh")) {
        try stdout.writeAll("alias gr='cd \"$(gitroot find-gitroot)\"'\n");
    } else if (std.mem.eql(u8, shell, "fish")) {
        try stdout.writeAll("alias gr \"cd (gitroot find-gitroot)\"\n");
    } else {
        std.debug.print("Unsupported shell: {s}\n", .{shell});
        return error.UnsupportedShell;
    }
}
