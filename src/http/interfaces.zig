const std = @import("std");

/// HTTP method enumeration
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }

    pub fn fromString(str: []const u8) ?Method {
        if (std.ascii.eqlIgnoreCase(str, "GET")) return .GET;
        if (std.ascii.eqlIgnoreCase(str, "POST")) return .POST;
        if (std.ascii.eqlIgnoreCase(str, "PUT")) return .PUT;
        if (std.ascii.eqlIgnoreCase(str, "DELETE")) return .DELETE;
        if (std.ascii.eqlIgnoreCase(str, "PATCH")) return .PATCH;
        if (std.ascii.eqlIgnoreCase(str, "HEAD")) return .HEAD;
        if (std.ascii.eqlIgnoreCase(str, "OPTIONS")) return .OPTIONS;
        return null;
    }
};

/// HTTP status codes
pub const Status = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    request_timeout = 408,
    payload_too_large = 413,
    too_many_requests = 429,
    internal_server_error = 500,
    bad_gateway = 502,
    service_unavailable = 503,

    pub fn phrase(self: Status) []const u8 {
        return switch (self) {
            .ok => "OK",
            .created => "Created",
            .no_content => "No Content",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .request_timeout => "Request Timeout",
            .payload_too_large => "Payload Too Large",
            .too_many_requests => "Too Many Requests",
            .internal_server_error => "Internal Server Error",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
        };
    }
};

/// Header map type for cleaner APIs
pub const HeaderMap = std.StringHashMap([]const u8);

/// Abstract HTTP request interface
/// This ensures the core app doesn't depend on any specific HTTP library
pub const Request = struct {
    method: Method,
    path: []const u8,
    query: []const u8,
    headers: HeaderMap,
    body: []const u8,
    
    // Arena allocator for this request - automatically cleaned up after response
    arena: std.mem.Allocator,

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }

    pub fn getHeader(self: *const Request, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    pub fn hasHeader(self: *const Request, name: []const u8) bool {
        return self.headers.contains(name);
    }
};

/// Abstract HTTP response interface
pub const Response = struct {
    status: Status,
    headers: HeaderMap,
    body: []const u8,
    
    arena: std.mem.Allocator,

    pub fn init(arena: std.mem.Allocator, status: Status) Response {
        return Response{
            .status = status,
            .headers = HeaderMap.init(arena),
            .body = "",
            .arena = arena,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
    }

    pub fn setHeader(self: *Response, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn setBody(self: *Response, body: []const u8) void {
        self.body = body;
    }

    pub fn setJsonBody(self: *Response, json: []const u8) !void {
        try self.setHeader("Content-Type", "application/json");
        self.setBody(json);
    }
};

/// Request handler function type
pub const HandlerFn = *const fn (request: *Request) anyerror!Response;

/// Middleware function type  
pub const MiddlewareFn = *const fn (request: *Request, next: HandlerFn) anyerror!Response;

/// Abstract HTTP server interface
/// Any HTTP server implementation must conform to this interface
pub const Server = struct {
    const Self = @This();

    // Function pointers for the implementation
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        start: *const fn (ptr: *anyopaque, config: ServerConfig) anyerror!void,
        stop: *const fn (ptr: *anyopaque) anyerror!void,
        addRoute: *const fn (ptr: *anyopaque, method: Method, path: []const u8, handler: HandlerFn) anyerror!void,
        addMiddleware: *const fn (ptr: *anyopaque, middleware: MiddlewareFn) anyerror!void,
    };

    pub fn start(self: *Self, config: ServerConfig) !void {
        return self.vtable.start(self.ptr, config);
    }

    pub fn stop(self: *Self) !void {
        return self.vtable.stop(self.ptr);
    }

    pub fn addRoute(self: *Self, method: Method, path: []const u8, handler: HandlerFn) !void {
        return self.vtable.addRoute(self.ptr, method, path, handler);
    }

    pub fn addMiddleware(self: *Self, middleware: MiddlewareFn) !void {
        return self.vtable.addMiddleware(self.ptr, middleware);
    }
};

/// Server configuration
pub const ServerConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    
    // Security settings
    max_request_size: usize = 1024 * 1024, // 1MB
    request_timeout_ms: u64 = 30000, // 30 seconds
    max_header_size: usize = 8 * 1024, // 8KB
    rate_limit_requests: u32 = 100,
    rate_limit_window_ms: u64 = 60000, // 1 minute
    
    // CORS settings
    cors_origins: []const []const u8 = &.{"*"},
    cors_methods: []const []const u8 = &.{ "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS" },
    cors_headers: []const []const u8 = &.{ "Content-Type", "Authorization" },
};

/// Factory function type for creating server implementations
pub const ServerFactory = *const fn (allocator: std.mem.Allocator) anyerror!Server;