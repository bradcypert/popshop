# Popshop Improvements TODO

## Critical Issues (Fix Immediately)

- [ ] Clean up remaining sample command references
- [ ] Fix broken test infrastructure 
- [ ] Update README with actual HTTP server documentation
- [ ] Add security measures (request limits, SSRF protection, input validation)

## High Priority Improvements

### Architecture & Code Quality
- [ ] Extract large methods (`_handleRequest`, `_proxyRequest`) into smaller functions
- [ ] Add proper error handling hierarchy with custom exceptions
- [ ] Implement dependency injection for better testability
- [ ] Add configuration validation command
- [ ] Fix configuration reload race conditions (add debouncing)

### Security Enhancements
- [ ] Add request size limits and rate limiting
- [ ] Add proxy URL validation to prevent SSRF attacks
- [ ] Make CORS policies configurable (currently allows all origins)
- [ ] Add optional authentication middleware
- [ ] Sanitize all user inputs from YAML configs

### Developer Experience
- [ ] Implement hot-reload configuration without server restart
- [ ] Add structured logging with different levels
- [ ] Add metrics/health check endpoints
- [ ] Improve error messages and debugging tools
- [ ] Add verbose mode for detailed request logging

## Medium Priority Features

### Advanced Request Matching
- [ ] Add regex support for path matching (currently only exact match)
- [ ] Add query parameter matching
- [ ] Add JSON body matching for request rules

### Enhanced Proxy Features
- [ ] Add request/response transformation capabilities
- [ ] Add proxy response caching
- [ ] Add circuit breaker pattern for failing proxies

### Observability & Debugging
- [ ] Add request/response recording capabilities
- [ ] Add performance metrics collection
- [ ] Add integration tests for server functionality
- [ ] Add performance/load tests
- [ ] Improve test coverage

### Configuration Management
- [ ] Support environment variable substitution in configs
- [ ] Add dry-run mode for configuration validation
- [ ] Add bash completion for commands

## Low Priority (Nice to Have)

### Performance Optimizations
- [ ] Add connection pooling for proxy requests
- [ ] Add response compression middleware
- [ ] Optimize YAML parsing and caching

### Advanced Features
- [ ] Add WebSocket proxying support
- [ ] Add request delay simulation
- [ ] Add conditional responses based on headers/time
- [ ] Add request recording/playback mode

## Security Considerations

### Current Vulnerabilities
- No request size limits
- No authentication/authorization
- CORS is overly permissive (`*` for all origins)
- No input sanitization for proxy URLs
- No protection against SSRF attacks

### Recommended Security Measures
- [ ] Add configurable CORS policies
- [ ] Implement request size limits
- [ ] Add URL validation for proxy targets
- [ ] Add optional authentication middleware
- [ ] Add request rate limiting

## Architecture Notes

**Code Quality Issues Found:**
- Some methods are too long and need refactoring
- Missing error handling in several places
- No dependency injection container
- Inconsistent error message formatting

**Suggested Architectural Changes:**
1. Extract middleware into separate classes
2. Add proper dependency injection
3. Separate concerns better (configuration, routing, proxying)
4. Add proper error handling hierarchy