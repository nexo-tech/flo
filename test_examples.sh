#!/bin/bash
# Automated Example Testing Script
#
# This script builds and runs all examples to verify they work correctly.
# Used in CI/CD to ensure examples remain functional.

set -e  # Exit on first error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Flō Example Testing Suite                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test an example
test_example() {
    local name=$1
    echo -n "Testing $name... "

    if timeout 5 dune exec examples/$name.exe > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
        echo "  Error or timeout running examples/$name.exe"
    fi
}

# Build all examples first
echo "Building all examples..."
if dune build 2>&1 | grep -i "warning" > /dev/null; then
    echo -e "${RED}✗ Build has warnings${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Build successful (no warnings)${NC}"
fi
echo ""

# Test each example
echo "Running examples..."
test_example "simple_app"
test_example "structured_events"
test_example "file_logging"
test_example "perf_app"
test_example "web_service"
test_example "ppx_usage"
test_example "custom_formatter"
test_example "logfmt_output"
test_example "json_logging"
test_example "pretty_console"
test_example "multi_sink"
test_example "context_propagation"
test_example "testing_with_flo"
test_example "error_handling"
test_example "distributed_tracing"
test_example "semantic_conventions"
test_example "core_composition"
test_example "custom_sink"
test_example "eio_integration"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Results: $PASSED passed, $FAILED failed"
echo "════════════════════════════════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All examples passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some examples failed${NC}"
    exit 1
fi
