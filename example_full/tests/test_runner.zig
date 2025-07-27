const std = @import("std");
const print = std.debug.print;

/// Comprehensive test suite for PopShop functionality
/// This test runner performs end-to-end testing of the PopShop server
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("🧪 PopShop Test Suite\n");
    print("====================\n\n");

    var passed: u32 = 0;
    var failed: u32 = 0;
    var total: u32 = 0;

    // Test configuration
    const base_url = "http://localhost:8080";
    const proxy_url = "http://localhost:3001";

    print("📋 Test Configuration:\n");
    print("   PopShop URL: {s}\n", .{base_url});
    print("   Proxy Target: {s}\n", .{proxy_url});
    print("   Config: demo.yaml\n\n");

    // Wait for server to be ready
    print("⏳ Waiting for PopShop server to be ready...\n");
    if (waitForServer(allocator, base_url)) {
        print("✅ PopShop server is ready\n\n");
    } else |err| {
        print("❌ PopShop server is not responding: {}\n", .{err});
        print("💡 Make sure to start the server with: zig build run -- serve example_full/config/demo.yaml\n");
        return;
    }

    // Run all tests
    total += 1;
    if (testHealthCheck(allocator, base_url)) {
        print("✅ Health check test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Health check test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testGetUsers(allocator, base_url)) {
        print("✅ Get users test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Get users test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testCreateUser(allocator, base_url)) {
        print("✅ Create user test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Create user test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testProtectedEndpoint(allocator, base_url)) {
        print("✅ Protected endpoint test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Protected endpoint test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testUnauthorizedAccess(allocator, base_url)) {
        print("✅ Unauthorized access test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Unauthorized access test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testCorsHeaders(allocator, base_url)) {
        print("✅ CORS headers test passed\n");
        passed += 1;
    } else |err| {
        print("❌ CORS headers test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testNotFound(allocator, base_url)) {
        print("✅ 404 Not Found test passed\n");
        passed += 1;
    } else |err| {
        print("❌ 404 Not Found test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testErrorResponse(allocator, base_url)) {
        print("✅ Error response test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Error response test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testContentTypes(allocator, base_url)) {
        print("✅ Content types test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Content types test failed: {}\n", .{err});
        failed += 1;
    }

    total += 1;
    if (testRateLimit(allocator, base_url)) {
        print("✅ Rate limit test passed\n");
        passed += 1;
    } else |err| {
        print("❌ Rate limit test failed: {}\n", .{err});
        failed += 1;
    }

    // Proxy tests (only if proxy server is running)
    if (waitForServer(allocator, proxy_url)) {
        print("\n🔀 Proxy server detected, running proxy tests...\n");
        
        total += 1;
        if (testProxyWeather(allocator, base_url)) {
            print("✅ Proxy weather test passed\n");
            passed += 1;
        } else |err| {
            print("❌ Proxy weather test failed: {}\n", .{err});
            failed += 1;
        }

        total += 1;
        if (testProxyUsers(allocator, base_url)) {
            print("✅ Proxy users test passed\n");
            passed += 1;
        } else |err| {
            print("❌ Proxy users test failed: {}\n", .{err});
            failed += 1;
        }
    } else |_| {
        print("\n⚠️  Proxy server not running, skipping proxy tests\n");
        print("💡 Start proxy server with: node example_full/proxy_server/server.js\n");
    }

    // Print results
    print("\n📊 Test Results:\n");
    print("================\n");
    print("✅ Passed: {d}\n", .{passed});
    print("❌ Failed: {d}\n", .{failed});
    print("📋 Total:  {d}\n", .{total});
    
    if (failed == 0) {
        print("\n🎉 All tests passed! PopShop is working correctly.\n");
    } else {
        print("\n⚠️  Some tests failed. Check the output above for details.\n");
        std.process.exit(1);
    }
}

fn waitForServer(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(base_url);
    
    var attempts: u8 = 0;
    while (attempts < 10) : (attempts += 1) {
        var req = client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) }) catch {
            std.time.sleep(1000 * 1000 * 1000); // 1 second
            continue;
        };
        defer req.deinit();
        
        req.send() catch {
            std.time.sleep(1000 * 1000 * 1000); // 1 second
            continue;
        };
        
        req.finish() catch {
            std.time.sleep(1000 * 1000 * 1000); // 1 second
            continue;
        };
        
        req.wait() catch {
            std.time.sleep(1000 * 1000 * 1000); // 1 second
            continue;
        };
        
        return; // Success
    }
    
    return error.ServerNotReady;
}

fn testHealthCheck(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/health", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);
    
    if (std.mem.indexOf(u8, body, "healthy") == null) {
        return error.UnexpectedBody;
    }
}

fn testGetUsers(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/users", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);
    
    if (std.mem.indexOf(u8, body, "Alice Johnson") == null) {
        return error.UnexpectedBody;
    }
}

fn testCreateUser(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/users", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.POST, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    req.headers.content_type = std.http.Client.Request.Headers.ContentType{ .override = "application/json" };
    
    const body = "{\"name\":\"Test User\",\"email\":\"test@example.com\"}";
    req.headers.content_length = body.len;
    
    try req.send();
    try req.writeAll(body);
    try req.finish();
    try req.wait();
    
    if (req.response.status != .created) {
        return error.UnexpectedStatus;
    }
}

fn testProtectedEndpoint(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/protected", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.headers.append("authorization", "Bearer valid-token");
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);
    
    if (std.mem.indexOf(u8, body, "Access granted") == null) {
        return error.UnexpectedBody;
    }
}

fn testUnauthorizedAccess(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/protected", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .unauthorized) {
        return error.UnexpectedStatus;
    }
}

fn testCorsHeaders(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/health", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    const cors_header = req.response.headers.getFirstValue("access-control-allow-origin");
    if (cors_header == null or !std.mem.eql(u8, cors_header.?, "*")) {
        return error.MissingCorsHeaders;
    }
}

fn testNotFound(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/nonexistent", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .not_found) {
        return error.UnexpectedStatus;
    }
}

fn testErrorResponse(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/error", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .internal_server_error) {
        return error.UnexpectedStatus;
    }
}

fn testContentTypes(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Test XML response
    const xml_url = try std.fmt.allocPrint(allocator, "{s}/api/xml", .{base_url});
    defer allocator.free(xml_url);
    
    const xml_uri = try std.Uri.parse(xml_url);
    var xml_req = try client.open(.GET, xml_uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer xml_req.deinit();
    
    try xml_req.send();
    try xml_req.finish();
    try xml_req.wait();
    
    if (xml_req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const content_type = xml_req.response.headers.getFirstValue("content-type");
    if (content_type == null or std.mem.indexOf(u8, content_type.?, "xml") == null) {
        return error.WrongContentType;
    }
}

fn testRateLimit(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/ratelimited", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .too_many_requests) {
        return error.UnexpectedStatus;
    }
}

fn testProxyWeather(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/external/weather", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);
    
    if (std.mem.indexOf(u8, body, "temperature") == null) {
        return error.UnexpectedBody;
    }
}

fn testProxyUsers(allocator: std.mem.Allocator, base_url: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}/api/external/users", .{base_url});
    defer allocator.free(url);
    
    const uri = try std.Uri.parse(url);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = try allocator.alloc(u8, 4096) });
    defer req.deinit();
    
    try req.send();
    try req.finish();
    try req.wait();
    
    if (req.response.status != .ok) {
        return error.UnexpectedStatus;
    }
    
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);
    
    if (std.mem.indexOf(u8, body, "External User") == null) {
        return error.UnexpectedBody;
    }
}