const std = @import("std");
const interfaces = @import("http/interfaces.zig");
const config = @import("config.zig");

const Request = interfaces.Request;
const Response = interfaces.Response;
const Status = interfaces.Status;
const HeaderMap = interfaces.HeaderMap;
const ProxyConfig = config.ProxyConfig;

/// HTTP client for making proxy requests
pub const ProxyClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator) ProxyClient {
        return ProxyClient{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *ProxyClient) void {
        self.client.deinit();
    }

    /// Proxy a request to the target URL
    pub fn proxyRequest(
        self: *ProxyClient, 
        request: *const Request, 
        proxy_config: *const ProxyConfig,
    ) !Response {
        // Validate proxy URL for security
        if (!isValidProxyUrl(proxy_config.url)) {
            std.log.warn("Blocked potentially unsafe proxy URL: {s}", .{proxy_config.url});
            var response = Response.init(request.arena, .bad_request);
            response.setBody("Invalid proxy URL");
            return response;
        }

        // Parse target URL
        const uri = std.Uri.parse(proxy_config.url) catch |err| {
            std.log.err("Failed to parse proxy URL {s}: {}", .{ proxy_config.url, err });
            var response = Response.init(request.arena, .bad_request);
            response.setBody("Invalid proxy URL format");
            return response;
        };

        // Create HTTP request
        var req = try self.client.open(
            parseMethod(request.method),
            uri,
            .{
                .server_header_buffer = try request.arena.alloc(u8, 16 * 1024),
                .redirect_behavior = .unhandled,
            },
        );
        defer req.deinit();

        // Set timeout
        req.connection.?.data.socket.setTimeout(proxy_config.timeout_ms) catch |err| {
            std.log.warn("Failed to set socket timeout: {}", .{err});
        };

        // Copy headers from original request
        try self.copyRequestHeaders(&req, request, proxy_config);

        // Set content length if body exists
        if (request.body.len > 0) {
            req.transfer_encoding = .{ .content_length = request.body.len };
        }

        // Send request
        try req.send();

        // Send body if present
        if (request.body.len > 0) {
            try req.writeAll(request.body);
            try req.finish();
        }

        // Wait for response
        try req.wait();

        // Create response
        var response = Response.init(request.arena, @enumFromInt(req.response.status.class));
        
        // Copy response headers
        try self.copyResponseHeaders(&response, &req);

        // Read response body
        const body = try req.reader().readAllAlloc(request.arena, 10 * 1024 * 1024); // 10MB max
        response.setBody(body);

        return response;
    }

    fn copyRequestHeaders(
        self: *ProxyClient,
        req: *std.http.Client.Request,
        request: *const Request,
        proxy_config: *const ProxyConfig,
    ) !void {
        _ = self;

        // Copy original request headers (filtered)
        var iter = request.headers.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            
            // Skip headers that shouldn't be forwarded
            if (shouldSkipHeader(name)) {
                continue;
            }
            
            try req.headers.append(name, value);
        }

        // Add proxy-specific headers
        if (proxy_config.headers) |proxy_headers| {
            var proxy_iter = proxy_headers.iterator();
            while (proxy_iter.next()) |entry| {
                try req.headers.append(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        // Add X-Forwarded-For header
        try req.headers.append("X-Forwarded-For", "popshop-proxy");
    }

    fn copyResponseHeaders(self: *ProxyClient, response: *Response, req: *std.http.Client.Request) !void {
        _ = self;
        
        var iter = req.response.iterateHeaders();
        while (iter.next()) |header| {
            const name = header.name;
            const value = header.value;
            
            // Skip headers that can cause issues when proxying
            if (shouldSkipResponseHeader(name)) {
                continue;
            }
            
            try response.setHeader(name, value);
        }
    }

    fn parseMethod(method: interfaces.Method) std.http.Method {
        return switch (method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
            .HEAD => .HEAD,
            .OPTIONS => .OPTIONS,
        };
    }
};

/// Validate proxy URLs to prevent SSRF attacks
fn isValidProxyUrl(url: []const u8) bool {
    const uri = std.Uri.parse(url) catch return false;
    
    // Only allow HTTP and HTTPS
    if (!std.mem.eql(u8, uri.scheme, "http") and !std.mem.eql(u8, uri.scheme, "https")) {
        return false;
    }
    
    const host = uri.host orelse return false;
    
    // Block localhost and loopback addresses
    if (std.mem.eql(u8, host, "localhost") or 
        std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "::1") or
        std.mem.eql(u8, host, "0.0.0.0")) {
        return false;
    }
    
    // Block private IP ranges (basic check)
    if (std.mem.startsWith(u8, host, "10.") or
        std.mem.startsWith(u8, host, "192.168.") or
        std.mem.startsWith(u8, host, "169.254.")) {
        return false;
    }
    
    // Check for 172.16-31.x.x range
    if (std.mem.startsWith(u8, host, "172.")) {
        const parts = std.mem.split(u8, host, ".");
        var count: u8 = 0;
        var second_octet: u32 = 0;
        
        while (parts.next()) |part| {
            count += 1;
            if (count == 2) {
                second_octet = std.fmt.parseInt(u32, part, 10) catch break;
                if (second_octet >= 16 and second_octet <= 31) {
                    return false;
                }
                break;
            }
        }
    }
    
    return true;
}

/// Headers that should not be forwarded in proxy requests
fn shouldSkipHeader(name: []const u8) bool {
    const lower_name = std.ascii.lowerString(name);
    
    const skip_headers = [_][]const u8{
        "host",
        "connection",
        "upgrade", 
        "proxy-connection",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
    };
    
    for (skip_headers) |skip| {
        if (std.mem.eql(u8, lower_name, skip)) {
            return true;
        }
    }
    
    return false;
}

/// Response headers that should not be forwarded from proxy responses
fn shouldSkipResponseHeader(name: []const u8) bool {
    const lower_name = std.ascii.lowerString(name);
    
    const skip_headers = [_][]const u8{
        "connection",
        "upgrade",
        "proxy-authenticate", 
        "proxy-authorization",
        "transfer-encoding",
        "content-encoding", // Let the client handle encoding
    };
    
    for (skip_headers) |skip| {
        if (std.mem.eql(u8, lower_name, skip)) {
            return true;
        }
    }
    
    return false;
}

/// Security middleware for additional SSRF protection
pub const SecurityMiddleware = struct {
    allocator: std.mem.Allocator,
    max_request_size: usize,
    rate_limit_map: std.StringHashMap(RateLimitEntry),

    const RateLimitEntry = struct {
        count: u32,
        window_start: i64,
    };

    pub fn init(allocator: std.mem.Allocator, max_request_size: usize) SecurityMiddleware {
        return SecurityMiddleware{
            .allocator = allocator,
            .max_request_size = max_request_size,
            .rate_limit_map = std.StringHashMap(RateLimitEntry).init(allocator),
        };
    }

    pub fn deinit(self: *SecurityMiddleware) void {
        self.rate_limit_map.deinit();
    }

    /// Middleware function for request size and rate limiting
    pub fn securityMiddleware(
        self: *SecurityMiddleware,
        request: *Request,
        next: interfaces.HandlerFn,
    ) !Response {
        // Check request size
        if (request.body.len > self.max_request_size) {
            std.log.warn("Request rejected: body too large ({} bytes)", .{request.body.len});
            var response = Response.init(request.arena, .payload_too_large);
            response.setBody("Request entity too large");
            return response;
        }

        // Rate limiting (basic implementation)
        const client_ip = self.getClientIp(request);
        if (try self.isRateLimited(client_ip)) {
            std.log.warn("Request rejected: rate limit exceeded for {s}", .{client_ip});
            var response = Response.init(request.arena, .too_many_requests);
            try response.setHeader("Retry-After", "60");
            response.setBody("Too many requests");
            return response;
        }

        return next(request);
    }

    fn getClientIp(self: *SecurityMiddleware, request: *Request) []const u8 {
        _ = self;
        
        // Check X-Forwarded-For header first
        if (request.getHeader("X-Forwarded-For")) |xff| {
            var parts = std.mem.split(u8, xff, ",");
            if (parts.next()) |first_ip| {
                return std.mem.trim(u8, first_ip, " ");
            }
        }
        
        // Check X-Real-IP header
        if (request.getHeader("X-Real-IP")) |real_ip| {
            return std.mem.trim(u8, real_ip, " ");
        }
        
        return "unknown";
    }

    fn isRateLimited(self: *SecurityMiddleware, client_ip: []const u8) !bool {
        const now = std.time.timestamp();
        const window_size = 60; // 60 seconds
        const max_requests = 100;

        const result = try self.rate_limit_map.getOrPut(client_ip);
        
        if (!result.found_existing) {
            // First request from this IP
            result.value_ptr.* = RateLimitEntry{
                .count = 1,
                .window_start = now,
            };
            return false;
        }

        const entry = result.value_ptr;
        
        // Reset window if expired
        if (now - entry.window_start >= window_size) {
            entry.count = 1;
            entry.window_start = now;
            return false;
        }

        // Increment counter
        entry.count += 1;
        
        return entry.count > max_requests;
    }
};

test "isValidProxyUrl" {
    try std.testing.expect(isValidProxyUrl("https://httpbin.org/get"));
    try std.testing.expect(isValidProxyUrl("http://example.com/api"));
    
    try std.testing.expect(!isValidProxyUrl("ftp://example.com"));
    try std.testing.expect(!isValidProxyUrl("https://localhost:8080"));
    try std.testing.expect(!isValidProxyUrl("http://127.0.0.1"));
    try std.testing.expect(!isValidProxyUrl("https://192.168.1.1"));
    try std.testing.expect(!isValidProxyUrl("http://10.0.0.1"));
    try std.testing.expect(!isValidProxyUrl("https://172.16.0.1"));
}

test "shouldSkipHeader" {
    try std.testing.expect(shouldSkipHeader("Host"));
    try std.testing.expect(shouldSkipHeader("connection"));
    try std.testing.expect(shouldSkipHeader("UPGRADE"));
    
    try std.testing.expect(!shouldSkipHeader("Content-Type"));
    try std.testing.expect(!shouldSkipHeader("Authorization"));
}