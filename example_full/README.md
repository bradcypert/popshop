# PopShop Complete Example

This directory contains a comprehensive example demonstrating all PopShop features including mocking, proxying, CORS, error handling, and more.

## 🚀 Quick Start

### 1. Start the PopShop Server

```bash
# From the project root
zig build run -- serve example_full/config/demo.yaml
```

### 2. Open the Frontend

```bash
# Open the HTML frontend in your browser
open example_full/frontend/index.html
```

### 3. (Optional) Start the Proxy Server

```bash
# Start the external service for proxy demonstration
node example_full/proxy_server/server.js
```

### 4. Run Tests

```bash
# Shell script tests (quick)
./example_full/tests/test_suite.sh

# Zig test runner (comprehensive)
zig run example_full/tests/test_runner.zig
```

## 📁 Directory Structure

```
example_full/
├── frontend/           # Simple HTML frontend for testing
│   └── index.html     # Interactive API tester
├── config/            # PopShop configuration
│   └── demo.yaml      # Comprehensive demo config
├── proxy_server/      # External service for proxy demos
│   └── server.js      # Node.js mock external service
├── tests/             # Test suites
│   ├── test_suite.sh  # Shell script tests
│   └── test_runner.zig # Zig comprehensive tests
├── docs/              # Additional documentation
└── README.md          # This file
```

## 🎯 Features Demonstrated

### Core Mocking
- **Health Check** - Basic JSON response
- **Users API** - CRUD operations with different status codes
- **Protected Endpoints** - Authentication-based responses
- **Error Simulation** - Various HTTP error codes
- **Content Types** - JSON, XML, CSV, plain text responses

### Advanced Features  
- **CORS Support** - Cross-origin requests enabled
- **Rate Limiting** - 429 Too Many Requests simulation
- **Proxy Requests** - Forward requests to external services
- **File Upload** - Mock file upload responses
- **Authentication** - Bearer token validation

## 🔧 Configuration Details

### Demo YAML Configuration

The `demo.yaml` file showcases various PopShop capabilities:

```yaml
# Basic mock response
- request:
    path: "/health"
    method: "GET"
  response:
    status: 200
    body: '{"status": "healthy"}'
    headers:
      content-type: "application/json"

# Proxy to external service
- request:
    path: "/api/external/weather"
    method: "GET"
  proxy:
    url: "http://localhost:3001/weather"
    timeout_ms: 5000
    headers:
      x-forwarded-by: "popshop"
```

### Supported Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check with JSON response |
| `/api/users` | GET/POST/PUT/DELETE | Users CRUD operations |
| `/api/protected` | GET | Authentication-required endpoint |
| `/api/products` | GET | Product catalog |
| `/api/orders` | POST | Order creation |
| `/api/upload` | POST | File upload simulation |
| `/api/error` | GET | 500 error simulation |
| `/api/ratelimited` | GET | 429 rate limit simulation |
| `/api/xml` | GET | XML response |
| `/api/text` | GET | Plain text response |
| `/api/csv` | GET | CSV download |
| `/api/external/*` | GET | Proxy to external service |

## 🌐 Frontend Usage

The HTML frontend (`frontend/index.html`) provides:

- **Interactive Form** - Set method, path, headers, body
- **Quick Examples** - Pre-configured common requests
- **Response Display** - Status, headers, formatted body
- **CORS Testing** - Cross-origin request demonstration

### Quick Examples Available:
- Health Check (`GET /health`)
- Get Users (`GET /api/users`) 
- Create User (`POST /api/users`)
- Protected Endpoint (`GET /api/protected`)
- Proxy Request (`GET /api/external/weather`)

## 🧪 Testing

### Shell Script Tests

Quick validation using curl:

```bash
./example_full/tests/test_suite.sh
```

Features:
- ✅ Status code validation
- ✅ Response body checks
- ✅ CORS header validation
- ✅ Performance timing
- ✅ Colored output

### Zig Test Runner

Comprehensive end-to-end tests:

```bash
zig run example_full/tests/test_runner.zig
```

Features:
- ✅ Full HTTP client testing
- ✅ JSON parsing validation
- ✅ Error condition testing
- ✅ Proxy functionality testing
- ✅ Detailed failure reporting

## 🔀 Proxy Server

The Node.js proxy server (`proxy_server/server.js`) simulates external services:

### Available Endpoints:
- `GET /weather` - Mock weather data
- `GET /users` - External user service
- `GET /status` - Service health status
- `GET /slow` - Delayed response (2s)
- `GET /error` - Error simulation

### Starting the Proxy Server:

```bash
cd example_full/proxy_server
node server.js
```

## 🔒 Security Features

### CORS Support
- ✅ `Access-Control-Allow-Origin: *`
- ✅ `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS`
- ✅ `Access-Control-Allow-Headers: Content-Type, Authorization`
- ✅ OPTIONS preflight request handling

### Authentication Demo
- ✅ Bearer token validation
- ✅ 401 Unauthorized responses
- ✅ Protected endpoint examples

## 🎮 Usage Scenarios

### 1. Frontend Development
Use PopShop to mock backend APIs during frontend development:

```javascript
// Frontend code can call PopShop endpoints
const response = await fetch('http://localhost:8080/api/users');
const users = await response.json();
```

### 2. API Testing
Test your API client code against known responses:

```bash
curl -H "Authorization: Bearer valid-token" \
     http://localhost:8080/api/protected
```

### 3. Integration Testing
Use the test suite to validate PopShop behavior:

```bash
# Run all tests
./example_full/tests/test_suite.sh

# Test specific scenarios
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"Test"}' \
     http://localhost:8080/api/users
```

### 4. Proxy Development
Test proxy configurations and external service integration:

```bash
# Start external service
node example_full/proxy_server/server.js

# Start PopShop with proxy config
zig build run -- serve example_full/config/demo.yaml

# Test proxy endpoint
curl http://localhost:8080/api/external/weather
```

## 📊 Performance

Expected performance characteristics:

- **Response Time**: < 50ms for mock responses
- **Throughput**: > 1000 requests/second
- **Memory Usage**: < 10MB resident
- **Startup Time**: < 1 second

## ⚠️ Known Issues

### YAML Configuration Limitations

1. **Multiline Strings Not Supported**
   - The current zig-yaml parser doesn't support YAML multiline string syntax (`|` and `>`)
   - **Workaround**: Use single-line JSON strings with escaped quotes
   ```yaml
   # ❌ This doesn't work:
   body: |
     {
       "name": "Alice",
       "email": "alice@example.com"
     }
   
   # ✅ Use this instead:
   body: '{"name": "Alice", "email": "alice@example.com"}'
   ```

2. **Complex YAML Features**
   - Anchors and references (`&`, `*`) are not supported
   - Some advanced YAML constructs may cause parsing errors
   - **Recommendation**: Keep YAML configuration simple and flat

## 🔧 Troubleshooting

### PopShop Server Won't Start
```bash
# Check if port 8080 is available
lsof -i :8080

# Verify config syntax
zig build run -- validate example_full/config/demo.yaml
```

### YAML Configuration Errors
```bash
# Common YAML issues:
# - Check for proper indentation (use spaces, not tabs)
# - Ensure all strings with special characters are quoted
# - Avoid multiline string syntax (use single-line JSON instead)

# Validate your config:
zig build run -- validate your-config.yaml
```

### Frontend CORS Issues
- Ensure PopShop server is running
- Check browser developer console
- Verify CORS headers in response

### Proxy Tests Failing
```bash
# Ensure proxy server is running
curl http://localhost:3001/status

# Check PopShop proxy configuration
grep -A5 "proxy:" example_full/config/demo.yaml
```

### Tests Failing
```bash
# Check server status
curl http://localhost:8080/health

# Run tests with verbose output
./example_full/tests/test_suite.sh
```

## 🚀 Next Steps

1. **Customize Configuration** - Modify `demo.yaml` for your use case
2. **Add Your Endpoints** - Extend the configuration with your API
3. **Integrate with CI/CD** - Use test suite in your pipeline
4. **Scale Up** - Use PopShop for load testing scenarios

## 📚 Additional Resources

- [PopShop Main Documentation](../README.md)
- [YAML Configuration Reference](../examples/)
- [HTTP Client Integration Guide](../docs/integration.md)

## 🤝 Contributing

To contribute to this example:

1. Add new endpoints to `demo.yaml`
2. Update frontend with new examples
3. Add corresponding tests
4. Update this documentation

## 📄 License

This example is part of the PopShop project and follows the same license terms.