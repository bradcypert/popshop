#!/bin/bash

# PopShop Quick Test Script
# Runs a subset of tests for rapid validation

set -e

POPSHOP_URL="http://localhost:8080"
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 PopShop Quick Test${NC}"
echo "===================="
echo ""

# Check if server is running
echo -n "Checking server... "
if curl -f -s --max-time 5 "$POPSHOP_URL/health" > /dev/null; then
    echo -e "${GREEN}✅ Server is running${NC}"
else
    echo -e "${RED}❌ Server not responding${NC}"
    echo "Start server with: zig build run -- serve example_full/config/demo.yaml"
    exit 1
fi

# Quick tests
echo ""
echo "Running quick tests:"

# Health check
echo -n "  Health check... "
if curl -f -s --max-time 5 "$POPSHOP_URL/health" | grep -q "healthy"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

# Users API
echo -n "  Users API... "
if curl -f -s --max-time 5 "$POPSHOP_URL/api/users" | grep -q "Alice"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

# CORS
echo -n "  CORS headers... "
if curl -s -I --max-time 5 "$POPSHOP_URL/health" | grep -q "access-control-allow-origin"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

# Error handling
echo -n "  Error handling... "
if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$POPSHOP_URL/nonexistent" | grep -q "404"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Quick test complete!${NC}"
echo ""
echo "For comprehensive testing run:"
echo "  ./example_full/tests/test_suite.sh"