const std = @import("std");
const fs = std.fs;
const path = std.fs.path;

// Entry point of the program
pub fn main() !void {
    // Initialize an arena allocator for memory management
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Allocate memory for command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Check if there are enough arguments
    if (args.len < 2) {
        std.debug.print("Usage: {s} [find-gitroot|init [fish|bash|zsh]]\n", .{args[0]});
        return;
    }

    // Handle the "find-gitroot" command
    if (std.mem.eql(u8, args[1], "find-gitroot")) {
        try findGitRoot(allocator);
    }
    // Handle the "init" command
    else if (std.mem.eql(u8, args[1], "init")) {
        if (args.len < 3) {
            std.debug.print("Usage: {s} init [fish|bash|zsh]\n", .{args[0]});
            return;
        }
        try printAlias(args[2]);
    }
    // Handle unknown commands
    else {
        std.debug.print("Unknown command: {s}\n", .{args[1]});
    }
}

// Function to find the Git root directory
fn findGitRoot(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    // Get the current working directory and allocate memory for it
    const original_cwd = try fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(original_cwd);

    // Duplicate the current path for manipulation
    var current_path = try allocator.dupe(u8, original_cwd);
    defer allocator.free(current_path);

    // Loop to traverse directories upwards until the Git root is found
    while (true) {
        // Open the current directory
        var dir = fs.openDirAbsolute(current_path, .{}) catch {
            try stdout.print("{s}\n", .{original_cwd});
            return;
        };
        defer dir.close();

        // Try to open the ".git" directory within the current directory
        var git_dir = dir.openDir(".git", .{}) catch |err| {
            switch (err) {
                // Handle file not found or not a directory errors
                error.FileNotFound, error.NotDir => {
                    // Get the parent directory path
                    const parent_path = path.dirname(current_path) orelse {
                        try stdout.print("{s}\n", .{original_cwd});
                        return;
                    };

                    // Check if we have reached the root directory
                    if (std.mem.eql(u8, parent_path, current_path)) {
                        try stdout.print("{s}\n", .{original_cwd});
                        return;
                    }

                    // Move to the parent directory
                    current_path = try allocator.dupe(u8, parent_path);
                    continue;
                },
                // Handle other errors
                else => {
                    try stdout.print("{s}\n", .{original_cwd});
                    return;
                },
            }
        };
        git_dir.close();

        // Print the current path if ".git" directory is found
        try stdout.print("{s}\n", .{current_path});
        return;
    }
}

// Function to print alias for different shells
fn printAlias(shell: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // Handle bash and zsh shells
    if (std.mem.eql(u8, shell, "bash") or std.mem.eql(u8, shell, "zsh")) {
        try stdout.writeAll("alias gr='cd \"$(gitroot find-gitroot)\"'\n");
    }
    // Handle fish shell
    else if (std.mem.eql(u8, shell, "fish")) {
        try stdout.writeAll("alias gr \"cd (gitroot find-gitroot)\"\n");
    }
    // Handle unsupported shells
    else {
        std.debug.print("Unsupported shell: {s}\n", .{shell});
        return error.UnsupportedShell;
    }
}
