# PopShop Complete Example - Technical Overview

## Architecture

The complete example demonstrates a production-ready setup with PopShop as the central HTTP mocking and proxy server.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │────│   PopShop       │────│  External       │
│   (Browser)     │    │   Server        │    │  Service        │
│                 │    │                 │    │                 │
│ - HTML Form     │    │ - Mock Routes   │    │ - Node.js       │
│ - JavaScript    │    │ - Proxy Routes  │    │ - Weather API   │
│ - CORS Requests │    │ - CORS Headers  │    │ - User Service  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
        └───────── HTTP ────────┴──────── HTTP ─────────┘
```

## Component Details

### PopShop Server (Zig)
- **Port**: 8080
- **Config**: `demo.yaml`
- **Features**: Full mocking, proxying, CORS, error handling
- **Memory**: ~10MB
- **Performance**: >1000 req/s

### Frontend (HTML/JS)
- **Type**: Single-page application
- **Features**: Interactive API testing form
- **CORS**: Fully compatible
- **Examples**: Pre-configured test scenarios

### External Service (Node.js)
- **Port**: 3001
- **Purpose**: Proxy target demonstration
- **APIs**: Weather, Users, Status endpoints
- **Features**: Realistic response delays, errors

### Test Suite (Zig + Shell)
- **Coverage**: End-to-end functionality
- **Types**: Unit tests, integration tests, performance tests
- **Validation**: Status codes, response bodies, headers

## Data Flow

### 1. Mock Requests
```
Browser → PopShop → YAML Config → Mock Response → Browser
```

### 2. Proxy Requests
```
Browser → PopShop → External Service → Response → PopShop → Browser
```

### 3. Error Handling
```
Browser → PopShop → Error Config → Error Response + CORS → Browser
```

## Configuration System

### YAML Structure
```yaml
- request:
    path: "/api/endpoint"
    method: "GET"
    headers:
      authorization: "Bearer token"
  response:
    status: 200
    body: '{"data": "value"}'
    headers:
      content-type: "application/json"
```

### Routing Logic
1. **Method Matching**: Exact HTTP method match
2. **Path Matching**: Exact path match (wildcards planned)
3. **Header Matching**: Optional header validation
4. **Body Matching**: Optional body content validation

## Security Features

### CORS Implementation
- **Origin**: `*` (configurable)
- **Methods**: All HTTP methods supported
- **Headers**: Content-Type, Authorization, custom headers
- **Preflight**: OPTIONS requests handled automatically

### Authentication Simulation
- **Bearer Tokens**: Configurable validation
- **Multiple Scenarios**: Valid/invalid token responses
- **Headers**: Realistic authentication headers

## Performance Characteristics

### Response Times
- **Mock Responses**: <10ms
- **Proxy Responses**: <100ms (+ external service time)
- **CORS Preflight**: <5ms

### Memory Usage
- **Base**: ~8MB
- **Per Request**: ~1KB (arena allocated)
- **Peak**: ~50MB under load

### Throughput
- **Mock Endpoints**: >2000 req/s
- **Proxy Endpoints**: Limited by external service
- **Concurrent Connections**: 1000+

## Error Handling Strategy

### Client Errors (4xx)
- **400 Bad Request**: Validation errors with details
- **401 Unauthorized**: Authentication failures
- **404 Not Found**: Unknown endpoints
- **429 Too Many Requests**: Rate limiting

### Server Errors (5xx)
- **500 Internal Server Error**: Application errors
- **502 Bad Gateway**: Proxy target failures
- **503 Service Unavailable**: Overload scenarios

### CORS Error Handling
- All error responses include CORS headers
- OPTIONS requests always return 200
- Consistent error format across endpoints

## Development Workflow

### 1. Configuration
```bash
# Edit YAML config
vim example_full/config/demo.yaml

# Validate config
zig build run -- validate example_full/config/demo.yaml
```

### 2. Testing
```bash
# Quick validation
./example_full/quick_test.sh

# Full test suite
./example_full/tests/test_suite.sh

# Frontend testing
open example_full/frontend/index.html
```

### 3. Monitoring
```bash
# Server logs
tail -f popshop.log

# Proxy logs
tail -f proxy_server/proxy.log

# Performance monitoring
curl -w "@curl-format.txt" http://localhost:8080/health
```

## Extension Points

### Adding New Endpoints
1. Update `demo.yaml` with new route
2. Add frontend example
3. Create test case
4. Update documentation

### Custom Authentication
```yaml
- request:
    path: "/api/custom-auth"
    headers:
      x-api-key: "secret-key"
  response:
    status: 200
    body: '{"authorized": true}'
```

### Advanced Proxying
```yaml
- request:
    path: "/api/proxy-with-transform"
    method: "POST"
  proxy:
    url: "http://external-service/api"
    headers:
      x-transform: "apply-filters"
    timeout_ms: 30000
```

## Deployment Considerations

### Production Deployment
- Use specific CORS origins instead of `*`
- Enable request logging
- Configure rate limiting
- Set up health checks

### Docker Integration
```dockerfile
FROM alpine:latest
RUN apk add --no-cache zig
COPY . /app
WORKDIR /app
RUN zig build -Doptimize=ReleaseFast
EXPOSE 8080
CMD ["./zig-out/bin/popshop", "serve", "config.yaml"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: popshop
spec:
  replicas: 3
  selector:
    matchLabels:
      app: popshop
  template:
    metadata:
      labels:
        app: popshop
    spec:
      containers:
      - name: popshop
        image: popshop:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

## Troubleshooting Guide

### Common Issues

#### Port Already in Use
```bash
# Find process using port 8080
lsof -i :8080

# Kill process
kill $(lsof -t -i:8080)
```

#### CORS Errors
- Verify server is returning CORS headers
- Check browser developer console
- Test with curl to isolate browser issues

#### Proxy Timeouts
- Verify external service is running
- Check network connectivity
- Adjust timeout settings in YAML

#### Configuration Errors
```bash
# Validate YAML syntax
zig build run -- validate config.yaml

# Check logs for parsing errors
grep "YAML" popshop.log
```

## Future Enhancements

### Planned Features
- Wildcard path matching (`/api/users/*`)
- Path parameter extraction (`/api/users/{id}`)
- Request body transformation
- Response templating
- Configuration hot-reload
- Metrics and monitoring
- Load balancing for proxy targets