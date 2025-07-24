# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Popshop is a high-performance HTTP mocking and proxy server built with Zig. It features clean architecture with swappable HTTP server implementations, arena allocators for zero-copy request handling, and comprehensive security features. The CLI supports serving mock responses and proxying requests based on YAML configuration files.

## Development Environment

This project uses `mise` for environment management with Zig 0.13.0. The configuration is defined in `.mise.toml`.

### Initial Setup
```bash
# Trust the mise configuration (first time only)
mise trust

# Install tools (Zig)
mise install

# Build and test the project
mise run dev
```

### Using Zig Commands
```bash
# Use mise tasks (recommended)
mise run build     # zig build
mise run test      # zig build test
mise run fmt       # zig fmt src/
mise run clean     # clean build artifacts

# Direct execution through mise
mise exec -- zig build
mise exec -- zig build test
mise exec -- zig build run
```

## Available Mise Tasks

The project includes predefined mise tasks for common operations:

### Development Tasks
```bash
mise run dev           # Build and test (development workflow)
mise run build         # Build the project (zig build)
mise run test          # Run all tests (zig build test)
mise run clean         # Clean build artifacts
```

### Code Quality Tasks
```bash
mise run fmt           # Format Zig code (zig fmt src/)
```

### Running the CLI
```bash
mise run run          # Run the CLI (zig build run)

# Or with arguments using zig build:
zig build run -- serve config.yaml
zig build run -- serve config.yaml --port 8080 --watch
zig build run -- validate config.yaml
zig build run -- version
zig build run -- help
```

### Manual Commands (when needed)
```bash
# Build specific target
zig build -Dtarget=x86_64-linux-gnu

# Run with specific allocator
zig build run -Dallocator=gpa

# Debug build
zig build -Doptimize=Debug
```

## Architecture

### Core Structure
- `src/main.zig` - Entry point that initializes CLI and runs commands
- `src/cli.zig` - Command-line interface with argument parsing
- `src/app.zig` - Core application logic and request handling
- `src/config.zig` - YAML configuration parsing and validation
- `src/matcher.zig` - Request matching engine with pattern support
- `src/proxy.zig` - HTTP proxy client with security validations
- `src/http/` - HTTP server abstraction layer

### Clean Architecture Design
The project follows dependency inversion principles:
- **Interfaces**: `src/http/interfaces.zig` defines HTTP server contracts
- **Implementations**: `src/http/httpz_server.zig` provides httpz-based server
- **Core Logic**: Application code depends only on interfaces, not implementations
- **Swappable Servers**: Easy to replace httpz with std.http or custom implementations

### Key Features
- **Arena Allocators**: Each HTTP request gets its own arena, automatically cleaned up
- **Zero-Copy**: Minimal memory allocations and copying during request processing
- **Security**: SSRF protection, rate limiting, request size limits
- **Pattern Matching**: Support for wildcards and path parameters in routes
- **Hot Reload**: Configuration file watching with debounced reloading

### Dependencies
- **httpz**: High-performance HTTP server library
- **zig-yaml**: YAML parsing for configuration files
- **Zig stdlib**: All core functionality uses only standard library

### Testing
- Uses Zig's built-in test framework
- Tests are embedded in source files with `test` blocks
- Run tests with `zig build test` or `mise run test`

## Development Notes

- The project uses Zig 0.13.0 with standard formatting (`zig fmt`)
- Clean architecture allows easy swapping of HTTP server implementations
- Arena allocators ensure memory safety and automatic cleanup
- All HTTP operations are designed for high performance with minimal allocations
- CLI follows standard Unix conventions for arguments and exit codes
- Security features include SSRF protection and comprehensive input validation