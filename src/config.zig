const std = @import("std");
const yaml = @import("yaml");

/// Configuration for a single request rule
pub const RequestRule = struct {
    path: []const u8,
    method: []const u8,
    headers: ?std.StringHashMap([]const u8) = null,
    body: ?[]const u8 = null,

    pub fn deinit(self: *RequestRule, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.method);
        if (self.headers) |*headers| {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }
        if (self.body) |body| {
            allocator.free(body);
        }
    }
};

/// Configuration for a mock response
pub const MockResponse = struct {
    status: u16 = 200,
    headers: ?std.StringHashMap([]const u8) = null,
    body: []const u8,

    pub fn deinit(self: *MockResponse, allocator: std.mem.Allocator) void {
        if (self.headers) |*headers| {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }
        allocator.free(self.body);
    }
};

/// Configuration for a proxy
pub const ProxyConfig = struct {
    url: []const u8,
    headers: ?std.StringHashMap([]const u8) = null,
    timeout_ms: u64 = 30000,

    pub fn deinit(self: *ProxyConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        if (self.headers) |*headers| {
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            headers.deinit();
        }
    }
};

/// A single rule that can either mock a response or proxy to another service
pub const Rule = struct {
    request: RequestRule,
    response: ?MockResponse = null,
    proxy: ?ProxyConfig = null,

    pub fn init(request: RequestRule) Rule {
        return Rule{ .request = request };
    }

    pub fn withMockResponse(self: Rule, response: MockResponse) Rule {
        var new_rule = self;
        new_rule.response = response;
        return new_rule;
    }

    pub fn withProxy(self: Rule, proxy: ProxyConfig) Rule {
        var new_rule = self;
        new_rule.proxy = proxy;
        return new_rule;
    }

    pub fn isMock(self: *const Rule) bool {
        return self.response != null;
    }

    pub fn isProxy(self: *const Rule) bool {
        return self.proxy != null;
    }

    pub fn deinit(self: *Rule, allocator: std.mem.Allocator) void {
        self.request.deinit(allocator);
        if (self.response) |*response| {
            response.deinit(allocator);
        }
        if (self.proxy) |*proxy| {
            proxy.deinit(allocator);
        }
    }
};

/// Complete configuration for the popshop server
pub const Config = struct {
    rules: std.ArrayList(Rule),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Config {
        return Config{
            .rules = std.ArrayList(Rule).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        for (self.rules.items) |*rule| {
            rule.deinit(self.allocator);
        }
        self.rules.deinit();
    }

    pub fn addRule(self: *Config, rule: Rule) !void {
        try self.rules.append(rule);
    }

    /// Load configuration from YAML file or directory
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        // Check if path is a file or directory
        const stat = std.fs.cwd().statFile(path) catch |err| switch (err) {
            error.FileNotFound => {
                // Try as directory
                return loadFromDirectory(allocator, path);
            },
            else => return err,
        };

        switch (stat.kind) {
            .file => return loadSingleFile(allocator, path),
            .directory => return loadFromDirectory(allocator, path),
            else => return error.InvalidPathType,
        }
    }

    /// Load configuration from a single YAML file
    fn loadSingleFile(allocator: std.mem.Allocator, file_path: []const u8) !Config {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try allocator.alloc(u8, file_size);
        defer allocator.free(content);

        _ = try file.readAll(content);

        return loadFromYaml(allocator, content);
    }

    /// Load configuration from all YAML files in a directory
    pub fn loadFromDirectory(allocator: std.mem.Allocator, dir_path: []const u8) !Config {
        var config = Config.init(allocator);
        errdefer config.deinit();

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
            std.log.err("Failed to open directory {s}: {}", .{ dir_path, err });
            return err;
        };
        defer dir.close();

        var iterator = dir.iterate();
        var files_loaded: usize = 0;

        while (try iterator.next()) |entry| {
            // Only process .yaml and .yml files
            if (entry.kind != .file) continue;
            
            const ext = std.fs.path.extension(entry.name);
            if (!std.mem.eql(u8, ext, ".yaml") and !std.mem.eql(u8, ext, ".yml")) {
                continue;
            }

            std.log.info("Loading config file: {s}/{s}", .{ dir_path, entry.name });

            // Load the file
            const file = try dir.openFile(entry.name, .{});
            defer file.close();

            const file_size = try file.getEndPos();
            const content = try allocator.alloc(u8, file_size);
            defer allocator.free(content);

            _ = try file.readAll(content);

            // Parse YAML and merge rules
            const file_config = loadFromYaml(allocator, content) catch |err| {
                std.log.err("Failed to parse {s}/{s}: {}", .{ dir_path, entry.name, err });
                continue; // Skip invalid files but continue processing
            };
            defer file_config.deinit();

            // Merge rules into main config
            for (file_config.rules.items) |rule| {
                // Deep copy the rule since we're moving it to a different config
                const copied_rule = try copyRule(allocator, rule);
                try config.addRule(copied_rule);
            }

            files_loaded += 1;
        }

        if (files_loaded == 0) {
            std.log.warn("No YAML files found in directory: {s}", .{dir_path});
        } else {
            std.log.info("Loaded {} YAML files from directory: {s}", .{ files_loaded, dir_path });
        }

        return config;
    }

    /// Deep copy a rule for transferring between configs
    fn copyRule(allocator: std.mem.Allocator, rule: Rule) !Rule {
        // Copy request
        var copied_request = RequestRule{
            .path = try allocator.dupe(u8, rule.request.path),
            .method = try allocator.dupe(u8, rule.request.method),
            .headers = null,
            .body = null,
        };

        if (rule.request.headers) |headers| {
            copied_request.headers = std.StringHashMap([]const u8).init(allocator);
            var iter = headers.iterator();
            while (iter.next()) |entry| {
                const key = try allocator.dupe(u8, entry.key_ptr.*);
                const value = try allocator.dupe(u8, entry.value_ptr.*);
                try copied_request.headers.?.put(key, value);
            }
        }

        if (rule.request.body) |body| {
            copied_request.body = try allocator.dupe(u8, body);
        }

        var copied_rule = Rule.init(copied_request);

        // Copy response if present
        if (rule.response) |response| {
            var copied_response = MockResponse{
                .status = response.status,
                .headers = null,
                .body = try allocator.dupe(u8, response.body),
            };

            if (response.headers) |headers| {
                copied_response.headers = std.StringHashMap([]const u8).init(allocator);
                var iter = headers.iterator();
                while (iter.next()) |entry| {
                    const key = try allocator.dupe(u8, entry.key_ptr.*);
                    const value = try allocator.dupe(u8, entry.value_ptr.*);
                    try copied_response.headers.?.put(key, value);
                }
            }

            copied_rule = copied_rule.withMockResponse(copied_response);
        }

        // Copy proxy if present
        if (rule.proxy) |proxy| {
            var copied_proxy = ProxyConfig{
                .url = try allocator.dupe(u8, proxy.url),
                .headers = null,
                .timeout_ms = proxy.timeout_ms,
            };

            if (proxy.headers) |headers| {
                copied_proxy.headers = std.StringHashMap([]const u8).init(allocator);
                var iter = headers.iterator();
                while (iter.next()) |entry| {
                    const key = try allocator.dupe(u8, entry.key_ptr.*);
                    const value = try allocator.dupe(u8, entry.value_ptr.*);
                    try copied_proxy.headers.?.put(key, value);
                }
            }

            copied_rule = copied_rule.withProxy(copied_proxy);
        }

        return copied_rule;
    }

    /// Load configuration from YAML string
    pub fn loadFromYaml(allocator: std.mem.Allocator, yaml_content: []const u8) !Config {
        var config = Config.init(allocator);
        errdefer config.deinit();

        // Parse YAML
        var parser = yaml.Parser.init(allocator);
        defer parser.deinit();

        const document = try parser.parse(yaml_content);
        defer document.deinit();

        // Expect an array of rules
        if (document.value != .sequence) {
            return error.InvalidYamlFormat;
        }

        for (document.value.sequence.items) |rule_node| {
            if (rule_node.value != .mapping) {
                continue;
            }

            const rule = try parseRule(allocator, rule_node.value.mapping);
            try config.addRule(rule);
        }

        return config;
    }

    fn parseRule(allocator: std.mem.Allocator, mapping: yaml.Mapping) !Rule {
        var request: ?RequestRule = null;
        var response: ?MockResponse = null;
        var proxy: ?ProxyConfig = null;

        var iter = mapping.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.value.string;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "request")) {
                request = try parseRequest(allocator, value.value.mapping);
            } else if (std.mem.eql(u8, key, "response")) {
                response = try parseResponse(allocator, value.value.mapping);
            } else if (std.mem.eql(u8, key, "proxy")) {
                proxy = try parseProxy(allocator, value.value.mapping);
            }
        }

        if (request == null) {
            return error.MissingRequestConfiguration;
        }

        var rule = Rule.init(request.?);
        if (response) |r| {
            rule = rule.withMockResponse(r);
        }
        if (proxy) |p| {
            rule = rule.withProxy(p);
        }

        return rule;
    }

    fn parseRequest(allocator: std.mem.Allocator, mapping: yaml.Mapping) !RequestRule {
        var path: ?[]const u8 = null;
        var method: ?[]const u8 = null;
        var headers: ?std.StringHashMap([]const u8) = null;
        var body: ?[]const u8 = null;

        var iter = mapping.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.value.string;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "path")) {
                path = try allocator.dupe(u8, value.value.string);
            } else if (std.mem.eql(u8, key, "method") or std.mem.eql(u8, key, "verb")) {
                method = try allocator.dupe(u8, value.value.string);
            } else if (std.mem.eql(u8, key, "headers")) {
                headers = try parseHeaders(allocator, value.value.mapping);
            } else if (std.mem.eql(u8, key, "body")) {
                body = try allocator.dupe(u8, value.value.string);
            }
        }

        if (path == null or method == null) {
            return error.MissingRequiredRequestFields;
        }

        return RequestRule{
            .path = path.?,
            .method = method.?,
            .headers = headers,
            .body = body,
        };
    }

    fn parseResponse(allocator: std.mem.Allocator, mapping: yaml.Mapping) !MockResponse {
        var status: u16 = 200;
        var headers: ?std.StringHashMap([]const u8) = null;
        var body: []const u8 = "";

        var iter = mapping.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.value.string;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "status")) {
                status = @intCast(value.value.integer);
            } else if (std.mem.eql(u8, key, "headers")) {
                headers = try parseHeaders(allocator, value.value.mapping);
            } else if (std.mem.eql(u8, key, "body")) {
                body = try allocator.dupe(u8, value.value.string);
            }
        }

        return MockResponse{
            .status = status,
            .headers = headers,
            .body = body,
        };
    }

    fn parseProxy(allocator: std.mem.Allocator, mapping: yaml.Mapping) !ProxyConfig {
        var url: ?[]const u8 = null;
        var headers: ?std.StringHashMap([]const u8) = null;
        var timeout_ms: u64 = 30000;

        var iter = mapping.iterator();
        while (iter.next()) |entry| {
            const key = entry.key_ptr.value.string;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "url")) {
                url = try allocator.dupe(u8, value.value.string);
            } else if (std.mem.eql(u8, key, "headers")) {
                headers = try parseHeaders(allocator, value.value.mapping);
            } else if (std.mem.eql(u8, key, "timeout_ms")) {
                timeout_ms = @intCast(value.value.integer);
            }
        }

        if (url == null) {
            return error.MissingProxyUrl;
        }

        return ProxyConfig{
            .url = url.?,
            .headers = headers,
            .timeout_ms = timeout_ms,
        };
    }

    fn parseHeaders(allocator: std.mem.Allocator, mapping: yaml.Mapping) !std.StringHashMap([]const u8) {
        var headers = std.StringHashMap([]const u8).init(allocator);

        var iter = mapping.iterator();
        while (iter.next()) |entry| {
            const key = try allocator.dupe(u8, entry.key_ptr.value.string);
            const value = try allocator.dupe(u8, entry.value_ptr.value.string);
            try headers.put(key, value);
        }

        return headers;
    }
};

test "Config.loadFromYaml" {
    const allocator = std.testing.allocator;
    
    const yaml_content =
        \\- request:
        \\    path: "/api/health"
        \\    method: "GET"
        \\  response:
        \\    status: 200
        \\    body: '{"status": "ok"}'
        \\- request:
        \\    path: "/api/proxy"
        \\    method: "GET"
        \\  proxy:
        \\    url: "https://httpbin.org/get"
    ;

    var config = try Config.loadFromYaml(allocator, yaml_content);
    defer config.deinit();

    try std.testing.expect(config.rules.items.len == 2);
    try std.testing.expect(config.rules.items[0].isMock());
    try std.testing.expect(config.rules.items[1].isProxy());
}