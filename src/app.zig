const std = @import("std");
const interfaces = @import("http/interfaces.zig");
const config = @import("config.zig");
const matcher = @import("matcher.zig");
const proxy = @import("proxy.zig");

const Server = interfaces.Server;
const Request = interfaces.Request;
const Response = interfaces.Response;
const Status = interfaces.Status;
const HandlerFn = interfaces.HandlerFn;
const Config = config.Config;
const Rule = config.Rule;
const RequestMatcher = matcher.RequestMatcher;
const ProxyClient = proxy.ProxyClient;

/// Core application that handles requests and manages the server
pub const PopshopApp = struct {
    allocator: std.mem.Allocator,
    server: Server,
    config: Config,
    matcher: RequestMatcher,
    proxy_client: ProxyClient,

    pub fn init(allocator: std.mem.Allocator, server: Server, app_config: Config) PopshopApp {
        return PopshopApp{
            .allocator = allocator,
            .server = server,
            .config = app_config,
            .matcher = RequestMatcher.init(allocator),
            .proxy_client = ProxyClient.init(allocator),
        };
    }

    pub fn deinit(self: *PopshopApp) void {
        self.proxy_client.deinit();
        self.config.deinit();
    }

    /// Start the HTTP server and begin handling requests
    pub fn start(self: *PopshopApp, server_config: interfaces.ServerConfig) !void {
        // Register our main handler
        try self.server.addRoute(.GET, "/*", handleRequest);
        try self.server.addRoute(.POST, "/*", handleRequest);
        try self.server.addRoute(.PUT, "/*", handleRequest);
        try self.server.addRoute(.DELETE, "/*", handleRequest);
        try self.server.addRoute(.PATCH, "/*", handleRequest);
        try self.server.addRoute(.HEAD, "/*", handleRequest);
        try self.server.addRoute(.OPTIONS, "/*", handleRequest);

        // Start the server
        try self.server.start(server_config);
        
        std.log.info("PopShop server started on {s}:{d}", .{ server_config.host, server_config.port });
        std.log.info("Loaded {} rule(s)", .{self.config.rules.items.len});
    }

    /// Stop the server
    pub fn stop(self: *PopshopApp) !void {
        try self.server.stop();
        std.log.info("PopShop server stopped");
    }

    /// Main request handler - this is where the magic happens
    fn handleRequest(request: *Request) !Response {
        // Note: In a real implementation, we'd need access to the app instance
        // This would typically be done through context or a global instance
        // For now, this is a placeholder showing the intended flow
        
        std.log.info("{s} {s}", .{ request.method.toString(), request.path });

        // Find matching rule
        // const matching_rule = self.matcher.findMatchingRule(request, self.config.rules.items);
        
        // if (matching_rule == null) {
        //     std.log.warn("No matching rule found for {s} {s}", .{ request.method.toString(), request.path });
        //     var response = Response.init(request.arena, .not_found);
        //     response.setBody("No matching rule found");
        //     return response;
        // }

        // Mock response for now
        var response = Response.init(request.arena, .ok);
        try response.setJsonBody("{\"message\": \"Hello from PopShop!\", \"path\": \"" ++ request.path ++ "\"}");
        return response;
    }

    /// Handle a request with the full app context
    pub fn handleRequestWithContext(self: *PopshopApp, request: *Request) !Response {
        std.log.info("{s} {s}", .{ request.method.toString(), request.path });

        // Find matching rule
        const matching_rule = self.matcher.findMatchingRule(request, self.config.rules.items);
        
        if (matching_rule == null) {
            std.log.warn("No matching rule found for {s} {s}", .{ request.method.toString(), request.path });
            var response = Response.init(request.arena, .not_found);
            response.setBody("No matching rule found");
            return response;
        }

        const rule = matching_rule.?;

        // Handle mock response
        if (rule.isMock()) {
            return self.serveMockResponse(request, rule);
        }

        // Handle proxy request
        if (rule.isProxy()) {
            return self.proxyRequest(request, rule);
        }

        // This should never happen if config is valid
        std.log.err("Rule has neither mock response nor proxy config");
        var response = Response.init(request.arena, .internal_server_error);
        response.setBody("Invalid rule configuration");
        return response;
    }

    fn serveMockResponse(self: *PopshopApp, request: *Request, rule: *const Rule) !Response {
        _ = self;
        
        const mock_response = rule.response.?;
        
        std.log.info("Serving mock response: {d}", .{mock_response.status});
        
        var response = Response.init(request.arena, @enumFromInt(mock_response.status));
        
        // Set custom headers
        if (mock_response.headers) |headers| {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                try response.setHeader(entry.key_ptr.*, entry.value_ptr.*);
            }
        }
        
        // Set default content-type if not specified
        if (!response.headers.contains("Content-Type")) {
            try response.setHeader("Content-Type", "application/json");
        }
        
        response.setBody(mock_response.body);
        return response;
    }

    fn proxyRequest(self: *PopshopApp, request: *Request, rule: *const Rule) !Response {
        const proxy_config = rule.proxy.?;
        
        std.log.info("Proxying request to {s}", .{proxy_config.url});
        
        return self.proxy_client.proxyRequest(request, proxy_config);
    }

    /// Reload configuration from file
    pub fn reloadConfig(self: *PopshopApp, config_path: []const u8) !void {
        std.log.info("Reloading configuration from {s}", .{config_path});
        
        // Load new config
        var new_config = Config.loadFromFile(self.allocator, config_path) catch |err| {
            std.log.err("Failed to reload configuration: {}", .{err});
            return err;
        };
        
        // Replace old config
        self.config.deinit();
        self.config = new_config;
        
        std.log.info("Configuration reloaded successfully - {} rule(s)", .{self.config.rules.items.len});
    }

    /// Get server statistics
    pub fn getStats(self: *PopshopApp) ServerStats {
        return ServerStats{
            .rules_count = self.config.rules.items.len,
            .mock_rules_count = self.countMockRules(),
            .proxy_rules_count = self.countProxyRules(),
        };
    }

    fn countMockRules(self: *PopshopApp) usize {
        var count: usize = 0;
        for (self.config.rules.items) |rule| {
            if (rule.isMock()) count += 1;
        }
        return count;
    }

    fn countProxyRules(self: *PopshopApp) usize {
        var count: usize = 0;
        for (self.config.rules.items) |rule| {
            if (rule.isProxy()) count += 1;
        }
        return count;
    }
};

/// Server statistics
pub const ServerStats = struct {
    rules_count: usize,
    mock_rules_count: usize,
    proxy_rules_count: usize,
};

/// Configuration file watcher for hot-reload functionality
pub const ConfigWatcher = struct {
    allocator: std.mem.Allocator,
    config_path: []const u8,
    app: *PopshopApp,
    watch_thread: ?std.Thread = null,
    should_stop: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8, app: *PopshopApp) ConfigWatcher {
        return ConfigWatcher{
            .allocator = allocator,
            .config_path = config_path,
            .app = app,
            .should_stop = std.atomic.Value(bool).init(false),
        };
    }

    pub fn start(self: *ConfigWatcher) !void {
        self.watch_thread = try std.Thread.spawn(.{}, watchConfigFile, .{self});
        std.log.info("Started watching configuration file: {s}", .{self.config_path});
    }

    pub fn stop(self: *ConfigWatcher) void {
        self.should_stop.store(true, .seq_cst);
        if (self.watch_thread) |thread| {
            thread.join();
            self.watch_thread = null;
        }
        std.log.info("Stopped watching configuration file");
    }

    fn watchConfigFile(self: *ConfigWatcher) !void {
        var last_modified: i128 = 0;
        
        while (!self.should_stop.load(.seq_cst)) {
            // Check file modification time
            const file = std.fs.cwd().openFile(self.config_path, .{}) catch {
                std.time.sleep(1000 * std.time.ns_per_ms); // Sleep 1 second
                continue;
            };
            defer file.close();
            
            const stat = file.stat() catch {
                std.time.sleep(1000 * std.time.ns_per_ms);
                continue;
            };
            
            if (stat.mtime > last_modified) {
                last_modified = stat.mtime;
                
                // Debounce - wait a bit to ensure file write is complete
                std.time.sleep(500 * std.time.ns_per_ms); // Wait 500ms
                
                // Reload configuration
                self.app.reloadConfig(self.config_path) catch |err| {
                    std.log.err("Failed to reload config: {}", .{err});
                };
            }
            
            // Check every second
            std.time.sleep(1000 * std.time.ns_per_ms);
        }
    }
};

test "PopshopApp.init" {
    const allocator = std.testing.allocator;
    
    // Create a mock server (would need to implement a test server)
    // This is a placeholder test structure
    var app_config = Config.init(allocator);
    defer app_config.deinit();
    
    // In a real test, we'd create a mock server implementation
    // const server = createMockServer(allocator);
    // var app = PopshopApp.init(allocator, server, app_config);
    // defer app.deinit();
}