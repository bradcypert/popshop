const std = @import("std");
const httpz = @import("httpz");
const interfaces = @import("interfaces.zig");

const Method = interfaces.Method;
const Status = interfaces.Status;
const Request = interfaces.Request;
const Response = interfaces.Response;
const HandlerFn = interfaces.HandlerFn;
const MiddlewareFn = interfaces.MiddlewareFn;
const Server = interfaces.Server;
const ServerConfig = interfaces.ServerConfig;
const HeaderMap = interfaces.HeaderMap;

/// HttpZ server implementation
pub const HttpZServer = struct {
    allocator: std.mem.Allocator,
    http_server: ?*httpz.Server(RequestContext) = null,
    config: ServerConfig = .{},
    routes: std.ArrayList(Route),
    middlewares: std.ArrayList(MiddlewareFn),

    const Route = struct {
        method: Method,
        path: []const u8,
        handler: HandlerFn,
    };

    const RequestContext = struct {
        arena: std.heap.ArenaAllocator,
    };

    pub fn init(allocator: std.mem.Allocator) !HttpZServer {
        return HttpZServer{
            .allocator = allocator,
            .routes = std.ArrayList(Route).init(allocator),
            .middlewares = std.ArrayList(MiddlewareFn).init(allocator),
        };
    }

    pub fn deinit(self: *HttpZServer) void {
        if (self.http_server) |s| {
            s.deinit();
        }
        self.routes.deinit();
        self.middlewares.deinit();
    }

    /// Create a Server interface from this implementation
    pub fn server(self: *HttpZServer) Server {
        return Server{
            .ptr = self,
            .vtable = &.{
                .start = start,
                .stop = stop,
                .addRoute = addRoute,
                .addMiddleware = addMiddleware,
            },
        };
    }

    fn start(ptr: *anyopaque, config: ServerConfig) !void {
        const self: *HttpZServer = @ptrCast(@alignCast(ptr));
        self.config = config;

        // Create httpz server
        var http_server = try httpz.Server(RequestContext).init(self.allocator, .{
            .address = config.host,
            .port = config.port,
            .request = .{
                .max_body_size = config.max_request_size,
            },
        }, RequestContext{
            .arena = std.heap.ArenaAllocator.init(self.allocator),
        });

        // Setup routes
        for (self.routes.items) |route| {
            try self.setupRoute(&http_server, route);
        }

        // Add CORS middleware (temporarily disabled)
        // http_server.notFound(corsNotFound);
        // http_server.errorHandler(errorHandler);

        // Start the server
        try http_server.listen();
        self.http_server = &http_server;
    }

    fn stop(ptr: *anyopaque) !void {
        const self: *HttpZServer = @ptrCast(@alignCast(ptr));
        if (self.http_server) |s| {
            s.stop();
            s.deinit();
            self.http_server = null;
        }
    }

    fn addRoute(ptr: *anyopaque, method: Method, path: []const u8, handler: HandlerFn) !void {
        const self: *HttpZServer = @ptrCast(@alignCast(ptr));
        
        // Store route for later setup
        try self.routes.append(.{
            .method = method,
            .path = try self.allocator.dupe(u8, path),
            .handler = handler,
        });
    }

    fn addMiddleware(ptr: *anyopaque, middleware: MiddlewareFn) !void {
        const self: *HttpZServer = @ptrCast(@alignCast(ptr));
        try self.middlewares.append(middleware);
    }

    fn setupRoute(self: *HttpZServer, http_server: *httpz.Server(RequestContext), route: Route) !void {
        _ = self;
        _ = http_server;
        _ = route;
        
        // TODO: Implement route setup when httpz API is clarified
        // The HTTP routing is temporarily disabled while we resolve API compatibility
        std.log.warn("HTTP routing temporarily disabled due to API changes", .{});
    }

    fn convertRequest(req: *httpz.Request, arena: std.mem.Allocator) !Request {
        var headers = HeaderMap.init(arena);
        
        // Convert headers
        var header_iter = req.headers.iterator();
        while (header_iter.next()) |header| {
            try headers.put(header.name, header.value);
        }

        // Parse method
        const method = Method.fromString(req.method) orelse Method.GET;

        return Request{
            .method = method,
            .path = req.url.path,
            .query = req.url.query orelse "",
            .headers = headers,
            .body = req.body() orelse "",
            .arena = arena,
        };
    }

    fn convertResponse(res: *httpz.Response, response: Response) !void {
        // Set status
        res.status = @intFromEnum(response.status);

        // Set headers
        var header_iter = response.headers.iterator();
        while (header_iter.next()) |header| {
            try res.header(header.key_ptr.*, header.value_ptr.*);
        }

        // Set body
        res.body = response.body;
    }

    fn corsNotFound(req: *httpz.Request, res: *httpz.Response, ctx: *RequestContext) !void {
        _ = ctx;
        
        // Add CORS headers for OPTIONS requests
        if (std.mem.eql(u8, req.method, "OPTIONS")) {
            try res.header("Access-Control-Allow-Origin", "*");
            try res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
            try res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
            res.status = 200;
            return;
        }

        res.status = 404;
        res.body = "Not Found";
    }

    fn errorHandler(req: *httpz.Request, res: *httpz.Response, err: anyerror, ctx: *RequestContext) void {
        _ = req;
        _ = ctx;
        
        std.log.err("Request error: {}", .{err});
        res.status = 500;
        res.body = "Internal Server Error";
    }
};

/// Factory function to create HttpZ server
pub fn createHttpZServer(allocator: std.mem.Allocator) !Server {
    const server_impl = try allocator.create(HttpZServer);
    server_impl.* = try HttpZServer.init(allocator);
    return server_impl.server();
}