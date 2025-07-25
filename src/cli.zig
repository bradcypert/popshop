const std = @import("std");
const interfaces = @import("http/interfaces.zig");
const config = @import("config.zig");
const app = @import("app.zig");
const httpz_server = @import("http/httpz_server.zig");

const ServerConfig = interfaces.ServerConfig;
const Config = config.Config;
const PopshopApp = app.PopshopApp;
const ConfigWatcher = app.ConfigWatcher;

/// Command line interface for PopShop
pub const CLI = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CLI {
        return CLI{ .allocator = allocator };
    }

    /// Run the CLI with command line arguments
    pub fn run(self: *CLI, args: []const []const u8) !void {
        if (args.len < 2) {
            self.printUsage();
            return;
        }

        const command = args[1];

        if (std.mem.eql(u8, command, "serve")) {
            try self.runServeCommand(args[2..]);
        } else if (std.mem.eql(u8, command, "validate")) {
            try self.runValidateCommand(args[2..]);
        } else if (std.mem.eql(u8, command, "version")) {
            self.printVersion();
        } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
            self.printHelp();
        } else {
            std.log.err("Unknown command: {s}", .{command});
            self.printUsage();
            std.process.exit(1);
        }
    }

    fn runServeCommand(self: *CLI, args: []const []const u8) !void {
        var serve_config = ServeConfig{};
        var config_path: ?[]const u8 = null;

        // Parse serve command arguments
        var i: usize = 0;
        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--port") or std.mem.eql(u8, arg, "-p")) {
                if (i + 1 >= args.len) {
                    std.log.err("--port requires a value", .{});
                    std.process.exit(1);
                }
                serve_config.port = std.fmt.parseInt(u16, args[i + 1], 10) catch |err| {
                    std.log.err("Invalid port number: {s} ({})", .{ args[i + 1], err });
                    std.process.exit(1);
                };
                i += 2;
            } else if (std.mem.eql(u8, arg, "--host") or std.mem.eql(u8, arg, "-h")) {
                if (i + 1 >= args.len) {
                    std.log.err("--host requires a value", .{});
                    std.process.exit(1);
                }
                serve_config.host = args[i + 1];
                i += 2;
            } else if (std.mem.eql(u8, arg, "--watch") or std.mem.eql(u8, arg, "-w")) {
                serve_config.watch = true;
                i += 1;
            } else if (std.mem.eql(u8, arg, "--max-request-size")) {
                if (i + 1 >= args.len) {
                    std.log.err("--max-request-size requires a value", .{});
                    std.process.exit(1);
                }
                serve_config.max_request_size = std.fmt.parseInt(usize, args[i + 1], 10) catch |err| {
                    std.log.err("Invalid max request size: {s} ({})", .{ args[i + 1], err });
                    std.process.exit(1);
                };
                i += 2;
            } else if (std.mem.startsWith(u8, arg, "--")) {
                std.log.err("Unknown option: {s}", .{arg});
                std.process.exit(1);
            } else {
                // Assume it's the config path
                config_path = arg;
                i += 1;
            }
        }

        if (config_path == null) {
            config_path = "config.yaml"; // Default config file
        }

        try self.startServer(config_path.?, serve_config);
    }

    fn runValidateCommand(self: *CLI, args: []const []const u8) !void {
        if (args.len == 0) {
            std.log.err("validate command requires a config file path", .{});
            std.process.exit(1);
        }

        const config_path = args[0];
        
        std.log.info("Validating configuration file: {s}", .{config_path});

        var app_config = Config.loadFromFile(self.allocator, config_path) catch |err| {
            std.log.err("Configuration validation failed: {}", .{err});
            std.process.exit(1);
        };
        defer app_config.deinit();

        const stats = self.analyzeConfig(&app_config);
        
        std.log.info("✓ Configuration is valid", .{});
        std.log.info("  Total rules: {}", .{stats.total_rules});
        std.log.info("  Mock responses: {}", .{stats.mock_rules});
        std.log.info("  Proxy rules: {}", .{stats.proxy_rules});
        
        if (stats.warnings.items.len > 0) {
            std.log.warn("Warnings:", .{});
            for (stats.warnings.items) |warning| {
                std.log.warn("  - {s}", .{warning});
            }
        }
    }

    fn startServer(self: *CLI, config_path: []const u8, serve_config: ServeConfig) !void {
        std.log.info("Starting PopShop server...", .{});
        std.log.info("Config file: {s}", .{config_path});
        std.log.info("Host: {s}", .{serve_config.host});
        std.log.info("Port: {}", .{serve_config.port});

        // Load configuration
        var app_config = Config.loadFromFile(self.allocator, config_path) catch |err| {
            std.log.err("Failed to load configuration: {}", .{err});
            std.process.exit(1);
        };
        defer app_config.deinit();

        // Create HTTP server
        const server = httpz_server.createHttpZServer(self.allocator) catch |err| {
            std.log.err("Failed to create HTTP server: {}", .{err});
            std.process.exit(1);
        };

        // Create application
        var popshop_app = PopshopApp.init(self.allocator, server, app_config);
        defer popshop_app.deinit();

        // Create server configuration
        const server_config = ServerConfig{
            .host = serve_config.host,
            .port = serve_config.port,
            .max_request_size = serve_config.max_request_size,
        };

        // Start config watcher if requested
        var watcher: ?ConfigWatcher = null;
        if (serve_config.watch) {
            watcher = ConfigWatcher.init(self.allocator, config_path, &popshop_app);
            try watcher.?.start();
        }
        defer if (watcher) |*w| w.stop();

        // Start the server
        try popshop_app.start(server_config);

        std.log.info("Server started successfully!", .{});
        std.log.info("Press Ctrl+C to stop the server (signal handling temporarily disabled)", .{});

        // Keep the server running (simplified without signal handling for now)
        // In a production environment, you'd want to implement proper signal handling
        while (true) {
            std.time.sleep(1000 * std.time.ns_per_ms); // Sleep 1 second
        }
    }

    fn analyzeConfig(self: *CLI, app_config: *const Config) ConfigStats {
        
        var stats = ConfigStats{
            .total_rules = app_config.rules.items.len,
            .mock_rules = 0,
            .proxy_rules = 0,
            .warnings = std.ArrayList([]const u8).init(self.allocator),
        };

        for (app_config.rules.items) |rule| {
            if (rule.isMock()) {
                stats.mock_rules += 1;
            }
            if (rule.isProxy()) {
                stats.proxy_rules += 1;
            }
            
            // Check for potential issues
            if (!rule.isMock() and !rule.isProxy()) {
                // This would be caught during config loading, but just in case
                stats.warnings.append("Rule has neither mock response nor proxy config") catch {};
            }
        }

        return stats;
    }

    fn printUsage(self: *CLI) void {
        _ = self;
        std.log.info("Usage: popshop <command> [options]", .{});
        std.log.info("", .{});
        std.log.info("Commands:", .{});
        std.log.info("  serve [config.yaml]    Start the HTTP server", .{});
        std.log.info("  validate <config.yaml> Validate configuration file", .{});
        std.log.info("  version               Show version information", .{});
        std.log.info("  help                  Show this help message", .{});
    }

    fn printHelp(self: *CLI) void {
        std.log.info("PopShop - HTTP mocking and proxy server", .{});
        std.log.info("", .{});
        self.printUsage();
        std.log.info("", .{});
        std.log.info("Serve Options:", .{});
        std.log.info("  -p, --port <port>           Port to run server on (default: 8080)", .{});
        std.log.info("  -h, --host <host>           Host to bind to (default: 127.0.0.1)", .{});
        std.log.info("  -w, --watch                 Watch config file for changes", .{});
        std.log.info("  --max-request-size <bytes>  Maximum request size (default: 1048576)", .{});
        std.log.info("", .{});
        std.log.info("Examples:", .{});
        std.log.info("  popshop serve config.yaml", .{});
        std.log.info("  popshop serve config.yaml --port 3000 --watch", .{});
        std.log.info("  popshop validate config.yaml", .{});
    }

    fn printVersion(self: *CLI) void {
        _ = self;
        std.log.info("PopShop v0.1.0", .{});
        std.log.info("Built with Zig {s}", .{@import("builtin").zig_version_string});
    }
};

const ServeConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    watch: bool = false,
    max_request_size: usize = 1024 * 1024, // 1MB
};

const ConfigStats = struct {
    total_rules: usize,
    mock_rules: usize,
    proxy_rules: usize,
    warnings: std.ArrayList([]const u8),
};