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
            var file_config_copy = file_config;
            defer file_config_copy.deinit();

            // Merge rules into main config
            for (file_config_copy.rules.items) |rule| {
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

        // Parse YAML using zig-yaml 0.1.1 API
        var parsed_yaml: yaml.Yaml = .{ .source = yaml_content };
        defer parsed_yaml.deinit(allocator);
        
        parsed_yaml.load(allocator) catch |err| switch (err) {
            error.ParseFailure => {
                std.log.err("YAML parse failure", .{});
                return error.InvalidYamlFormat;
            },
            else => return err,
        };

        // Check if we have any documents
        if (parsed_yaml.docs.items.len == 0) {
            std.log.warn("No YAML documents found", .{});
            return config;
        }

        // Get the first document - should be an array of rules  
        const doc = parsed_yaml.docs.items[0];
        
        // Process the YAML document to extract rules
        try parseYamlDocument(allocator, &config, doc);

        return config;
    }

    fn parseYamlDocument(allocator: std.mem.Allocator, config: *Config, doc: anytype) !void {
        switch (doc) {
            .list => |list| {
                // Expected format: array of rule objects
                for (list) |rule_value| {
                    const rule = try parseYamlRule(allocator, rule_value);
                    try config.addRule(rule);
                }
            },
            .map => {
                // Single rule object
                const rule = try parseYamlRule(allocator, doc);
                try config.addRule(rule);
            },
            else => {
                std.log.err("Expected YAML document to be a list or map, got: {}", .{doc});
                return error.InvalidYamlFormat;
            },
        }
    }

    fn parseYamlRule(allocator: std.mem.Allocator, rule_value: anytype) !Rule {
        const rule_map = switch (rule_value) {
            .map => |map| map,
            else => {
                std.log.err("Expected rule to be a map, got: {}", .{rule_value});
                return error.InvalidYamlFormat;
            },
        };

        var request: ?RequestRule = null;
        var response: ?MockResponse = null;
        var proxy: ?ProxyConfig = null;

        // Parse the rule map
        var map_iter = rule_map.iterator();
        while (map_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "request")) {
                request = try parseYamlRequest(allocator, value);
            } else if (std.mem.eql(u8, key, "response")) {
                response = try parseYamlResponse(allocator, value);
            } else if (std.mem.eql(u8, key, "proxy")) {
                proxy = try parseYamlProxy(allocator, value);
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

    fn parseYamlRequest(allocator: std.mem.Allocator, request_value: anytype) !RequestRule {
        const request_map = switch (request_value) {
            .map => |map| map,
            else => return error.InvalidYamlFormat,
        };

        var path: ?[]const u8 = null;
        var method: ?[]const u8 = null;
        var headers: ?std.StringHashMap([]const u8) = null;
        var body: ?[]const u8 = null;

        var map_iter = request_map.iterator();
        while (map_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "path")) {
                if (value == .string) {
                    path = try allocator.dupe(u8, value.string);
                }
            } else if (std.mem.eql(u8, key, "method") or std.mem.eql(u8, key, "verb")) {
                if (value == .string) {
                    method = try allocator.dupe(u8, value.string);
                }
            } else if (std.mem.eql(u8, key, "headers")) {
                if (value == .map) {
                    headers = try parseYamlHeaders(allocator, value.map);
                }
            } else if (std.mem.eql(u8, key, "body")) {
                if (value == .string) {
                    body = try allocator.dupe(u8, value.string);
                }
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

    fn parseYamlResponse(allocator: std.mem.Allocator, response_value: anytype) !MockResponse {
        const response_map = switch (response_value) {
            .map => |map| map,
            else => return error.InvalidYamlFormat,
        };

        var status: u16 = 200;
        var headers: ?std.StringHashMap([]const u8) = null;
        var body: []const u8 = "";

        var map_iter = response_map.iterator();
        while (map_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "status")) {
                switch (value) {
                    .int => |i| status = @intCast(i),
                    .string => |s| status = std.fmt.parseInt(u16, s, 10) catch 200,
                    else => {},
                }
            } else if (std.mem.eql(u8, key, "headers")) {
                if (value == .map) {
                    headers = try parseYamlHeaders(allocator, value.map);
                }
            } else if (std.mem.eql(u8, key, "body")) {
                if (value == .string) {
                    body = try allocator.dupe(u8, value.string);
                }
            }
        }

        return MockResponse{
            .status = status,
            .headers = headers,
            .body = body,
        };
    }

    fn parseYamlProxy(allocator: std.mem.Allocator, proxy_value: anytype) !ProxyConfig {
        const proxy_map = switch (proxy_value) {
            .map => |map| map,
            else => return error.InvalidYamlFormat,
        };

        var url: ?[]const u8 = null;
        var headers: ?std.StringHashMap([]const u8) = null;
        var timeout_ms: u64 = 30000;

        var map_iter = proxy_map.iterator();
        while (map_iter.next()) |entry| {
            const key: []const u8 = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "url")) {
                if (value == .string) {
                    url = try allocator.dupe(u8, value.string);
                }
            } else if (std.mem.eql(u8, key, "headers")) {
                if (value == .map) {
                    headers = try parseYamlHeaders(allocator, value.map);
                }
            } else if (std.mem.eql(u8, key, "timeout_ms")) {
                switch (value) {
                    .int => |i| timeout_ms = @intCast(i),
                    .string => |s| timeout_ms = std.fmt.parseInt(u64, s, 10) catch 30000,
                    else => {},
                }
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

    fn parseYamlHeaders(allocator: std.mem.Allocator, headers_map: anytype) !std.StringHashMap([]const u8) {
        var headers = std.StringHashMap([]const u8).init(allocator);

        var map_iter = headers_map.iterator();
        while (map_iter.next()) |entry| {
            const key: []const u8 = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            
            // Only process string values
            switch (value) {
                .string => |s| {
                    const owned_key = try allocator.dupe(u8, key);
                    const owned_value = try allocator.dupe(u8, s);
                    try headers.put(owned_key, owned_value);
                },
                else => continue,
            }
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

    // We should have parsed 2 rules from the YAML content
    try std.testing.expect(config.rules.items.len == 2);
    try std.testing.expect(config.rules.items[0].isMock());
    try std.testing.expect(!config.rules.items[0].isProxy());
    try std.testing.expect(!config.rules.items[1].isMock());
    try std.testing.expect(config.rules.items[1].isProxy());
}