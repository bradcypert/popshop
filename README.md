# PopShop

**High-performance HTTP mocking and proxy server built with Zig**

[![License: MIT][license_badge]][license_link]

A fast, memory-efficient HTTP server for mocking APIs and proxying requests, featuring arena allocators for zero-copy request handling and clean architectural patterns.

---

## Getting Started 🚀

### Installation

**From Source:**

```sh
# Clone the repository
git clone https://github.com/your-org/popshop.git
cd popshop

# Build with mise
mise trust
mise install
mise run build

# Or build directly with Zig
zig build
```

### Development Setup

This project uses `mise` for environment management with Zig:

```sh
# Trust the mise configuration (first time only)
mise trust

# Install tools (Zig)
mise install

# Build and test
mise run dev
```

## Usage

### Basic Server Commands

```sh
# Start HTTP server with YAML configuration
$ popshop serve config.yaml

# Start server on custom port with file watching
$ popshop serve config.yaml --port 3000 --watch

# Start server on all interfaces
$ popshop serve config.yaml --host 0.0.0.0 --port 8080

# Validate configuration file
$ popshop validate config.yaml

# Show version and help
$ popshop version
$ popshop help
```

### Configuration Format

Popshop uses YAML files to define request/response rules and proxy configurations:

```yaml
# Simple mock response
- request:
    path: "/api/health"
    method: get
  response:
    body: '{"status": "ok"}'
    status: 200
    headers:
      content-type: "application/json"

# Proxy to external service
- request:
    path: "/api/external"
    method: get
  proxy:
    url: https://httpbin.org/get
    headers:
      x-forwarded-by: "popshop"
```

### Features

- **Mock API Responses**: Define custom responses for specific HTTP requests
- **Proxy Forwarding**: Forward requests to external APIs with custom headers
- **File Watching**: Automatically reload configuration changes during development
- **Flexible Matching**: Match requests by path and HTTP method
- **Custom Headers**: Set response headers and proxy headers
- **Multiple Rules**: Single YAML file can contain multiple request/response rules

### Architecture

PopShop is built with clean architecture principles:

- **Clean Abstractions**: HTTP server implementation is swappable via interfaces
- **Arena Allocators**: Each request gets its own arena, automatically cleaned up
- **Zero Dependencies**: Core logic depends only on Zig standard library
- **Memory Safe**: Strong typing and ownership semantics prevent common bugs
- **High Performance**: Designed for low latency and high throughput

### Examples

See the `examples/` directory for sample configurations:

- `examples/simple.yaml` - Basic health check endpoint
- `examples/api.yaml` - Multiple API endpoints with different response types
- `examples/users.yaml` - User management API endpoints

## Development 🛠️

### Available Commands

```sh
# Build the project
mise run build

# Run tests
mise run test

# Format code
mise run fmt

# Clean build artifacts
mise run clean

# Development workflow (build + test)
mise run dev
```

### Testing 🧪

PopShop uses Zig's built-in testing framework:

```sh
# Run all tests
mise run test

# Or directly with Zig
zig build test

# Run tests with verbose output
zig build test -- --verbose
```

---

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT