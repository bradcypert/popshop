const std = @import("std");
const cli = @import("cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Initialize and run CLI
    var popshop_cli = cli.CLI.init(allocator);
    try popshop_cli.run(args);
}

// Re-export main modules for testing
pub const config = @import("config.zig");
pub const matcher = @import("matcher.zig");
pub const proxy = @import("proxy.zig");
pub const app = @import("app.zig");
pub const interfaces = @import("http/interfaces.zig");

test {
    // Reference all modules to ensure they compile and run their tests
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(config);
    std.testing.refAllDecls(matcher);
    std.testing.refAllDecls(proxy);
    std.testing.refAllDecls(app);
    std.testing.refAllDecls(interfaces);
}