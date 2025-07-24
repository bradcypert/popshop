const std = @import("std");
const config = @import("config.zig");
const interfaces = @import("http/interfaces.zig");

const Rule = config.Rule;
const Request = interfaces.Request;
const HeaderMap = interfaces.HeaderMap;

/// Request matcher that determines which rule matches an incoming request
pub const RequestMatcher = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RequestMatcher {
        return RequestMatcher{ .allocator = allocator };
    }

    /// Find the first rule that matches the given request
    pub fn findMatchingRule(self: *RequestMatcher, request: *const Request, rules: []const Rule) ?*const Rule {
        _ = self; // RequestMatcher might need allocator for future regex support
        
        for (rules) |*rule| {
            if (self.doesRuleMatch(request, rule)) {
                return rule;
            }
        }
        return null;
    }

    /// Check if a single rule matches the request
    pub fn doesRuleMatch(self: *RequestMatcher, request: *const Request, rule: *const Rule) bool {
        // Check HTTP method
        if (!self.matchMethod(request, rule)) {
            return false;
        }

        // Check path
        if (!self.matchPath(request, rule)) {
            return false;
        }

        // Check headers if specified
        if (!self.matchHeaders(request, rule)) {
            return false;
        }

        // Check body if specified
        if (!self.matchBody(request, rule)) {
            return false;
        }

        return true;
    }

    fn matchMethod(self: *RequestMatcher, request: *const Request, rule: *const Rule) bool {
        _ = self;
        
        const request_method = request.method.toString();
        const rule_method = rule.request.method;
        
        return std.ascii.eqlIgnoreCase(request_method, rule_method);
    }

    fn matchPath(self: *RequestMatcher, request: *const Request, rule: *const Rule) bool {
        _ = self;
        
        const request_path = request.path;
        const rule_path = rule.request.path;
        
        // For now, exact match. Could be extended to support:
        // - Wildcards: /api/*
        // - Path parameters: /api/users/{id}
        // - Regex patterns: /api/users/\d+
        return std.mem.eql(u8, request_path, rule_path);
    }

    fn matchHeaders(self: *RequestMatcher, request: *const Request, rule: *const Rule) bool {
        _ = self;
        
        const rule_headers = rule.request.headers orelse return true;
        
        var iter = rule_headers.iterator();
        while (iter.next()) |entry| {
            const header_name = entry.key_ptr.*;
            const expected_value = entry.value_ptr.*;
            
            const actual_value = request.getHeader(header_name) orelse return false;
            
            if (!std.mem.eql(u8, actual_value, expected_value)) {
                return false;
            }
        }
        
        return true;
    }

    fn matchBody(self: *RequestMatcher, request: *const Request, rule: *const Rule) bool {
        _ = self;
        
        const expected_body = rule.request.body orelse return true;
        return std.mem.eql(u8, request.body, expected_body);
    }
};

/// Advanced path matcher supporting wildcards and parameters
pub const PathMatcher = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PathMatcher {
        return PathMatcher{ .allocator = allocator };
    }

    /// Match path with support for wildcards and parameters
    /// Examples:
    /// - "/api/*" matches "/api/users" and "/api/posts"
    /// - "/api/users/{id}" matches "/api/users/123" 
    /// - "/api/users/{id}/posts/{post_id}" matches "/api/users/123/posts/456"
    pub fn matchPath(self: *PathMatcher, request_path: []const u8, rule_path: []const u8) !?PathMatch {
        if (std.mem.indexOf(u8, rule_path, "*") == null and 
            std.mem.indexOf(u8, rule_path, "{") == null) {
            // Simple exact match
            if (std.mem.eql(u8, request_path, rule_path)) {
                return PathMatch.init(self.allocator);
            }
            return null;
        }

        return self.matchPatternPath(request_path, rule_path);
    }

    fn matchPatternPath(self: *PathMatcher, request_path: []const u8, rule_path: []const u8) !?PathMatch {
        var match = PathMatch.init(self.allocator);
        errdefer match.deinit();

        // Split paths into segments
        var request_segments = std.mem.split(u8, request_path, "/");
        var rule_segments = std.mem.split(u8, rule_path, "/");

        while (true) {
            const req_segment = request_segments.next();
            const rule_segment = rule_segments.next();

            // Both exhausted - match
            if (req_segment == null and rule_segment == null) {
                return match;
            }

            // Only one exhausted - no match unless rule ends with wildcard
            if (req_segment == null or rule_segment == null) {
                if (rule_segment != null and std.mem.eql(u8, rule_segment.?, "*")) {
                    return match;
                }
                return null;
            }

            const req_seg = req_segment.?;
            const rule_seg = rule_segment.?;

            // Wildcard matches everything remaining
            if (std.mem.eql(u8, rule_seg, "*")) {
                return match;
            }

            // Parameter extraction
            if (std.mem.startsWith(u8, rule_seg, "{") and std.mem.endsWith(u8, rule_seg, "}")) {
                const param_name = rule_seg[1..rule_seg.len-1];
                try match.addParameter(param_name, req_seg);
                continue;
            }

            // Exact segment match
            if (!std.mem.eql(u8, req_seg, rule_seg)) {
                return null;
            }
        }
    }
};

/// Result of a successful path match, containing extracted parameters
pub const PathMatch = struct {
    parameters: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PathMatch {
        return PathMatch{
            .parameters = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PathMatch) void {
        var iter = self.parameters.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.parameters.deinit();
    }

    pub fn addParameter(self: *PathMatch, name: []const u8, value: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try self.allocator.dupe(u8, value);
        try self.parameters.put(owned_name, owned_value);
    }

    pub fn getParameter(self: *const PathMatch, name: []const u8) ?[]const u8 {
        return self.parameters.get(name);
    }

    pub fn hasParameter(self: *const PathMatch, name: []const u8) bool {
        return self.parameters.contains(name);
    }
};

test "RequestMatcher.exact_match" {
    const allocator = std.testing.allocator;
    
    var matcher = RequestMatcher.init(allocator);
    
    // Create a mock request
    var headers = HeaderMap.init(allocator);
    defer headers.deinit();
    
    const request = Request{
        .method = .GET,
        .path = "/api/health",
        .query = "",
        .headers = headers,
        .body = "",
        .arena = allocator,
    };
    
    // Create a matching rule
    const rule = Rule{
        .request = config.RequestRule{
            .path = "/api/health",
            .method = "GET",
        },
    };
    
    try std.testing.expect(matcher.doesRuleMatch(&request, &rule));
}

test "RequestMatcher.method_mismatch" {
    const allocator = std.testing.allocator;
    
    var matcher = RequestMatcher.init(allocator);
    
    var headers = HeaderMap.init(allocator);
    defer headers.deinit();
    
    const request = Request{
        .method = .POST,
        .path = "/api/health",
        .query = "",
        .headers = headers,
        .body = "",
        .arena = allocator,
    };
    
    const rule = Rule{
        .request = config.RequestRule{
            .path = "/api/health",
            .method = "GET", // Different method
        },
    };
    
    try std.testing.expect(!matcher.doesRuleMatch(&request, &rule));
}

test "PathMatcher.wildcard" {
    const allocator = std.testing.allocator;
    
    var matcher = PathMatcher.init(allocator);
    
    const result = try matcher.matchPath("/api/users/123", "/api/*");
    try std.testing.expect(result != null);
    
    if (result) |*match| {
        defer match.deinit();
    }
}

test "PathMatcher.parameters" {
    const allocator = std.testing.allocator;
    
    var matcher = PathMatcher.init(allocator);
    
    const result = try matcher.matchPath("/api/users/123/posts/456", "/api/users/{id}/posts/{post_id}");
    try std.testing.expect(result != null);
    
    if (result) |*match| {
        defer match.deinit();
        
        try std.testing.expect(std.mem.eql(u8, match.getParameter("id").?, "123"));
        try std.testing.expect(std.mem.eql(u8, match.getParameter("post_id").?, "456"));
    }
}