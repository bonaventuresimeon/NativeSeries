#!/bin/bash

# Smoke Tests for Student Tracker Application
# This script runs basic health checks after deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BASE_URL="${1:-http://localhost:8000}"
TIMEOUT="${2:-30}"
MAX_RETRIES="${3:-5}"

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to wait for service to be ready
wait_for_service() {
    local url="$1"
    local retries=0
    
    print_status "Waiting for service at $url to be ready..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -f -s --max-time $TIMEOUT "$url/health" > /dev/null 2>&1; then
            print_status "✅ Service is ready!"
            return 0
        fi
        
        retries=$((retries + 1))
        print_warning "Service not ready, attempt $retries/$MAX_RETRIES..."
        sleep 5
    done
    
    print_error "❌ Service failed to become ready after $MAX_RETRIES attempts"
    return 1
}

# Function to test endpoint
test_endpoint() {
    local endpoint="$1"
    local expected_status="${2:-200}"
    local url="$BASE_URL$endpoint"
    
    print_status "Testing endpoint: $endpoint"
    
    local response=$(curl -s -w "%{http_code}" --max-time $TIMEOUT "$url" -o /dev/null)
    
    if [ "$response" = "$expected_status" ]; then
        print_status "✅ $endpoint - Status: $response (Expected: $expected_status)"
        return 0
    else
        print_error "❌ $endpoint - Status: $response (Expected: $expected_status)"
        return 1
    fi
}

# Function to test endpoint with content check
test_endpoint_content() {
    local endpoint="$1"
    local expected_content="$2"
    local url="$BASE_URL$endpoint"
    
    print_status "Testing endpoint content: $endpoint"
    
    local response=$(curl -s --max-time $TIMEOUT "$url")
    
    if echo "$response" | grep -q "$expected_content"; then
        print_status "✅ $endpoint - Content check passed"
        return 0
    else
        print_error "❌ $endpoint - Content check failed"
        print_error "Expected: $expected_content"
        print_error "Received: $response"
        return 1
    fi
}

# Main smoke test function
run_smoke_tests() {
    local failed_tests=0
    
    print_status "🚀 Starting smoke tests for $BASE_URL"
    echo "Timeout: ${TIMEOUT}s, Max retries: $MAX_RETRIES"
    echo ""
    
    # Wait for service to be ready
    if ! wait_for_service "$BASE_URL"; then
        print_error "Service readiness check failed"
        return 1
    fi
    
    echo ""
    print_status "Running endpoint tests..."
    
    # Test health endpoint
    test_endpoint "/health" 200 || failed_tests=$((failed_tests + 1))
    
    # Test API documentation
    test_endpoint "/docs" 200 || failed_tests=$((failed_tests + 1))
    
    # Test OpenAPI schema
    test_endpoint "/openapi.json" 200 || failed_tests=$((failed_tests + 1))
    
    # Test root endpoint
    test_endpoint "/" 200 || failed_tests=$((failed_tests + 1))
    
    # Test metrics endpoint (if available)
    test_endpoint "/metrics" 200 || {
        print_warning "Metrics endpoint not available (this is optional)"
    }
    
    # Test health endpoint content
    test_endpoint_content "/health" "status" || failed_tests=$((failed_tests + 1))
    
    echo ""
    
    if [ $failed_tests -eq 0 ]; then
        print_status "🎉 All smoke tests passed!"
        return 0
    else
        print_error "❌ $failed_tests smoke test(s) failed!"
        return 1
    fi
}

# Performance test (basic)
run_performance_test() {
    print_status "Running basic performance test..."
    
    local start_time=$(date +%s%N)
    local response=$(curl -s -w "%{time_total}" --max-time $TIMEOUT "$BASE_URL/health" -o /dev/null)
    local end_time=$(date +%s%N)
    
    local response_time_ms=$(echo "scale=2; $response * 1000" | bc)
    
    print_status "Response time: ${response_time_ms}ms"
    
    if (( $(echo "$response < 2.0" | bc -l) )); then
        print_status "✅ Performance test passed (< 2s)"
        return 0
    else
        print_warning "⚠️ Performance test warning (>= 2s)"
        return 0  # Warning, not failure
    fi
}

# Main execution
main() {
    echo "Student Tracker - Smoke Tests"
    echo "============================="
    echo ""
    
    # Run smoke tests
    if run_smoke_tests; then
        echo ""
        
        # Run performance test if basic tests pass
        if command -v bc >/dev/null 2>&1; then
            run_performance_test
        else
            print_warning "bc not available, skipping performance test"
        fi
        
        echo ""
        print_status "🎉 All tests completed successfully!"
        exit 0
    else
        echo ""
        print_error "❌ Smoke tests failed!"
        exit 1
    fi
}

# Show usage if no arguments and not in CI
if [ $# -eq 0 ] && [ -z "${CI:-}" ]; then
    echo "Usage: $0 [BASE_URL] [TIMEOUT] [MAX_RETRIES]"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Test localhost:8000"
    echo "  $0 http://staging.yourdomain.com     # Test staging"
    echo "  $0 http://yourdomain.com 60 10       # Test production with custom timeout"
    echo ""
fi

# Run main function
main "$@"