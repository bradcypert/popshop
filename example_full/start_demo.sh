#!/bin/bash

# PopShop Demo Startup Script
# This script starts all components for the full demo

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POPSHOP_PORT=8080
PROXY_PORT=3001

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for $name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --max-time 2 "$url" > /dev/null 2>&1; then
            log_success "$name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    log_error "$name failed to start within ${max_attempts} seconds"
    return 1
}

# Cleanup function for graceful shutdown
cleanup() {
    log_info "Shutting down demo services..."
    
    # Kill PopShop server
    if [ ! -z "$POPSHOP_PID" ]; then
        kill $POPSHOP_PID 2>/dev/null || true
        wait $POPSHOP_PID 2>/dev/null || true
        log_success "PopShop server stopped"
    fi
    
    # Kill proxy server
    if [ ! -z "$PROXY_PID" ]; then
        kill $PROXY_PID 2>/dev/null || true
        wait $PROXY_PID 2>/dev/null || true
        log_success "Proxy server stopped"
    fi
    
    log_info "Demo cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    echo "🛍️  PopShop Complete Demo Startup"
    echo "================================="
    echo ""
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    # Check if mise is available
    if ! command -v mise &> /dev/null; then
        log_error "mise not found. Please install mise or ensure it's in your PATH"
        exit 1
    fi
    
    # Check if zig is available through mise
    if ! mise exec -- zig version &> /dev/null; then
        log_error "Zig not found through mise. Please run 'mise install' first"
        exit 1
    fi
    
    # Check if node is available for proxy server
    if ! command -v node &> /dev/null; then
        log_warning "Node.js not found. Proxy server will not be available"
        SKIP_PROXY=true
    fi
    
    # Check ports
    if ! check_port $POPSHOP_PORT; then
        log_error "Port $POPSHOP_PORT is already in use"
        log_info "Kill the process using: lsof -ti:$POPSHOP_PORT | xargs kill"
        exit 1
    fi
    
    if [ "$SKIP_PROXY" != "true" ] && ! check_port $PROXY_PORT; then
        log_warning "Port $PROXY_PORT is already in use, skipping proxy server"
        SKIP_PROXY=true
    fi
    
    log_success "Prerequisites check complete"
    echo ""
    
    # Build PopShop
    log_info "Building PopShop..."
    cd "$PROJECT_ROOT"
    mise exec -- zig build > /dev/null 2>&1
    log_success "PopShop built successfully"
    
    # Start proxy server (if available)
    if [ "$SKIP_PROXY" != "true" ]; then
        log_info "Starting proxy server on port $PROXY_PORT..."
        cd "$SCRIPT_DIR/proxy_server"
        node server.js > proxy.log 2>&1 &
        PROXY_PID=$!
        
        if wait_for_service "http://localhost:$PROXY_PORT/status" "Proxy server"; then
            log_success "Proxy server started (PID: $PROXY_PID)"
        else
            log_error "Failed to start proxy server"
            kill $PROXY_PID 2>/dev/null || true
            SKIP_PROXY=true
        fi
    fi
    
    # Start PopShop server
    log_info "Starting PopShop server on port $POPSHOP_PORT..."
    cd "$PROJECT_ROOT"
    mise exec -- zig build run -- serve example_full/config/demo.yaml > popshop.log 2>&1 &
    POPSHOP_PID=$!
    
    if wait_for_service "http://localhost:$POPSHOP_PORT/health" "PopShop server"; then
        log_success "PopShop server started (PID: $POPSHOP_PID)"
    else
        log_error "Failed to start PopShop server"
        cleanup
        exit 1
    fi
    
    echo ""
    echo "🎉 Demo is ready!"
    echo "================="
    echo ""
    echo "📡 Services:"
    echo "   PopShop Server: http://localhost:$POPSHOP_PORT"
    
    if [ "$SKIP_PROXY" != "true" ]; then
        echo "   Proxy Target:   http://localhost:$PROXY_PORT"
    else
        echo "   Proxy Target:   Not available (Node.js not found or port in use)"
    fi
    
    echo ""
    echo "🌐 Frontend:"
    echo "   Open in browser: file://$SCRIPT_DIR/frontend/index.html"
    echo ""
    echo "🧪 Quick Tests:"
    echo "   Health check:   curl http://localhost:$POPSHOP_PORT/health"
    echo "   Get users:      curl http://localhost:$POPSHOP_PORT/api/users"
    echo "   Run test suite: $SCRIPT_DIR/tests/test_suite.sh"
    echo ""
    echo "📊 Logs:"
    echo "   PopShop:        tail -f $PROJECT_ROOT/popshop.log"
    
    if [ "$SKIP_PROXY" != "true" ]; then
        echo "   Proxy:          tail -f $SCRIPT_DIR/proxy_server/proxy.log"
    fi
    
    echo ""
    echo "⏹️  To stop: Press Ctrl+C"
    echo ""
    
    # Open frontend in browser (if possible)
    if command -v open &> /dev/null; then
        log_info "Opening frontend in browser..."
        open "$SCRIPT_DIR/frontend/index.html"
    elif command -v xdg-open &> /dev/null; then
        log_info "Opening frontend in browser..."
        xdg-open "$SCRIPT_DIR/frontend/index.html"
    else
        log_warning "Cannot auto-open browser. Please manually open: file://$SCRIPT_DIR/frontend/index.html"
    fi
    
    # Wait for user interrupt
    log_info "Demo is running. Press Ctrl+C to stop..."
    while true; do
        sleep 1
    done
}

# Run main function
main "$@"