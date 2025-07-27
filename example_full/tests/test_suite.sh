#!/bin/bash

# PopShop Test Suite - Shell Script Version
# Simple curl-based tests for quick validation

set -e

# Configuration
POPSHOP_URL="http://localhost:8080"
PROXY_URL="http://localhost:3001"
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if server is running
check_server() {
    local url=$1
    local name=$2
    
    if curl -f -s --max-time $TIMEOUT "$url" > /dev/null 2>&1; then
        log_success "$name server is running at $url"
        return 0
    else
        log_error "$name server is not responding at $url"
        return 1
    fi
}

# Run a test
run_test() {
    local name="$1"
    local method="$2"
    local url="$3"
    local expected_status="$4"
    local expected_body="$5"
    local headers="$6"
    
    ((TOTAL++))
    
    log_info "Running test: $name"
    
    # Build curl command
    local curl_cmd="curl -s -w '%{http_code}' --max-time $TIMEOUT"
    
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    curl_cmd="$curl_cmd -X $method '$url'"
    
    # Run request
    local response=$(eval $curl_cmd 2>/dev/null)
    local status_code="${response: -3}"
    local body="${response%???}"
    
    # Check status code
    if [ "$status_code" != "$expected_status" ]; then
        log_error "$name: Expected status $expected_status, got $status_code"
        return 1
    fi
    
    # Check body content if specified
    if [ -n "$expected_body" ] && ! echo "$body" | grep -q "$expected_body"; then
        log_error "$name: Expected body to contain '$expected_body'"
        echo "  Actual body: $body"
        return 1
    fi
    
    log_success "$name test passed"
    return 0
}

# Main test execution
main() {
    echo "🧪 PopShop Test Suite (Shell Version)"
    echo "====================================="
    echo ""
    
    log_info "Test Configuration:"
    echo "   PopShop URL: $POPSHOP_URL"
    echo "   Proxy Target: $PROXY_URL"
    echo "   Timeout: ${TIMEOUT}s"
    echo ""
    
    # Check if PopShop server is running
    if ! check_server "$POPSHOP_URL/health" "PopShop"; then
        log_warning "Start PopShop server with: zig build run -- serve example_full/config/demo.yaml"
        exit 1
    fi
    
    echo ""
    log_info "Running core functionality tests..."
    
    # Core tests
    run_test "Health Check" "GET" "$POPSHOP_URL/health" "200" "healthy"
    
    run_test "Get Users" "GET" "$POPSHOP_URL/api/users" "200" "Alice Johnson"
    
    run_test "Create User" "POST" "$POPSHOP_URL/api/users" "201" "created" \
        "-H 'Content-Type: application/json' -d '{\"name\":\"Test User\"}'"
    
    run_test "Protected Endpoint (Valid Token)" "GET" "$POPSHOP_URL/api/protected" "200" "Access granted" \
        "-H 'Authorization: Bearer valid-token'"
    
    run_test "Protected Endpoint (No Token)" "GET" "$POPSHOP_URL/api/protected" "401" "Unauthorized"
    
    run_test "Not Found" "GET" "$POPSHOP_URL/nonexistent" "404" ""
    
    run_test "Error Response" "GET" "$POPSHOP_URL/api/error" "500" "Internal Server Error"
    
    run_test "Rate Limited" "GET" "$POPSHOP_URL/api/ratelimited" "429" "Too Many Requests"
    
    run_test "XML Content Type" "GET" "$POPSHOP_URL/api/xml" "200" "<?xml"
    
    run_test "Plain Text" "GET" "$POPSHOP_URL/api/text" "200" "plain text"
    
    run_test "CSV Response" "GET" "$POPSHOP_URL/api/csv" "200" "id,name,email"
    
    # CORS test
    log_info "Testing CORS functionality..."
    local cors_response=$(curl -s -H "Origin: http://localhost:3000" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Content-Type" \
        -X OPTIONS "$POPSHOP_URL/api/health" -w '%{http_code}' --max-time $TIMEOUT)
    
    local cors_status="${cors_response: -3}"
    if [ "$cors_status" == "200" ]; then
        log_success "CORS preflight test passed"
        ((PASSED++))
    else
        log_error "CORS preflight test failed (status: $cors_status)"
        ((FAILED++))
    fi
    ((TOTAL++))
    
    # Proxy tests (if proxy server is running)
    echo ""
    if check_server "$PROXY_URL/status" "External service"; then
        log_info "Running proxy tests..."
        
        run_test "Proxy Weather" "GET" "$POPSHOP_URL/api/external/weather" "200" "temperature"
        
        run_test "Proxy Users" "GET" "$POPSHOP_URL/api/external/users" "200" "External User"
    else
        log_warning "External service not running, skipping proxy tests"
        log_info "Start proxy server with: node example_full/proxy_server/server.js"
    fi
    
    # Performance test
    echo ""
    log_info "Running performance test..."
    local start_time=$(date +%s%3N)
    curl -s --max-time $TIMEOUT "$POPSHOP_URL/health" > /dev/null
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    
    if [ $response_time -lt 1000 ]; then
        log_success "Performance test passed (${response_time}ms)"
        ((PASSED++))
    else
        log_error "Performance test failed (${response_time}ms > 1000ms)"
        ((FAILED++))
    fi
    ((TOTAL++))
    
    # Results
    echo ""
    echo "📊 Test Results:"
    echo "================"
    echo -e "${GREEN}✅ Passed: $PASSED${NC}"
    echo -e "${RED}❌ Failed: $FAILED${NC}"
    echo "📋 Total:  $TOTAL"
    
    if [ $FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 All tests passed! PopShop is working correctly.${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}⚠️  Some tests failed. Check the output above for details.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"