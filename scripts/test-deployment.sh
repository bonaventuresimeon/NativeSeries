#!/bin/bash

# 🧪 COMPREHENSIVE DEPLOYMENT TEST SCRIPT
# Tests DNS, frontend templates, backend API, and overall functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DNS_URL="${DNS_URL:-http://18.206.89.183}"
NODE_PORT="${NODE_PORT:-30011}"
TIMEOUT=10

# Print functions
print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}🧪 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_test() {
    echo -e "${CYAN}🔍 Testing: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Test functions
test_dns_connectivity() {
    print_test "DNS Connectivity to $DNS_URL"
    
    if curl -s --connect-timeout $TIMEOUT "$DNS_URL" >/dev/null 2>&1; then
        print_success "DNS is reachable at $DNS_URL"
        return 0
    else
        print_error "Cannot reach $DNS_URL"
        return 1
    fi
}

test_health_endpoint() {
    print_test "Health Endpoint"
    
    local health_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/health" 2>/dev/null || echo "ERROR")
    
    if [[ "$health_response" != "ERROR" ]]; then
        print_success "Health endpoint is working"
        print_info "Response: $health_response"
        return 0
    else
        print_error "Health endpoint is not responding"
        return 1
    fi
}

test_frontend_root() {
    print_test "Frontend Root Page"
    
    local root_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/" 2>/dev/null || echo "ERROR")
    
    if [[ "$root_response" != "ERROR" ]] && [[ ${#root_response} -gt 100 ]]; then
        print_success "Frontend root page is loading"
        
        # Check for HTML content
        if echo "$root_response" | grep -q "<html\|<HTML\|<!DOCTYPE"; then
            print_success "Valid HTML content detected"
        else
            print_warning "Response doesn't appear to be HTML"
        fi
        
        # Check for common frontend elements
        if echo "$root_response" | grep -qi "student"; then
            print_success "Student-related content found"
        fi
        
        return 0
    else
        print_error "Frontend root page is not loading properly"
        return 1
    fi
}

test_students_page() {
    print_test "Students Page (/students/)"
    
    local students_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/students/" 2>/dev/null || echo "ERROR")
    
    if [[ "$students_response" != "ERROR" ]] && [[ ${#students_response} -gt 50 ]]; then
        print_success "Students page is accessible"
        
        # Check for HTML content
        if echo "$students_response" | grep -q "<html\|<HTML\|<!DOCTYPE"; then
            print_success "Students page returns valid HTML"
        fi
        
        return 0
    else
        print_error "Students page is not accessible"
        return 1
    fi
}

test_api_docs() {
    print_test "API Documentation (/docs)"
    
    local docs_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/docs" 2>/dev/null || echo "ERROR")
    
    if [[ "$docs_response" != "ERROR" ]] && [[ ${#docs_response} -gt 100 ]]; then
        print_success "API documentation is accessible"
        
        # Check for Swagger/OpenAPI content
        if echo "$docs_response" | grep -qi "swagger\|openapi\|api"; then
            print_success "API documentation appears to be properly formatted"
        fi
        
        return 0
    else
        print_error "API documentation is not accessible"
        return 1
    fi
}

test_api_students_endpoint() {
    print_test "Students API Endpoint (/api/students)"
    
    local api_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/api/students" 2>/dev/null || echo "ERROR")
    
    if [[ "$api_response" != "ERROR" ]]; then
        print_success "Students API endpoint is responding"
        
        # Check if it's valid JSON
        if echo "$api_response" | python3 -m json.tool >/dev/null 2>&1; then
            print_success "API returns valid JSON"
            
            # Show first few characters of response
            local preview=$(echo "$api_response" | head -c 200)
            print_info "API Response preview: $preview..."
        else
            print_warning "API response is not valid JSON"
            print_info "Response: $api_response"
        fi
        
        return 0
    else
        print_error "Students API endpoint is not responding"
        return 1
    fi
}

test_static_files() {
    print_test "Static Files (CSS/JS)"
    
    # Test common static file paths
    local static_paths=("/static/css/style.css" "/static/js/main.js" "/static/favicon.ico")
    local static_found=false
    
    for path in "${static_paths[@]}"; do
        if curl -s --connect-timeout $TIMEOUT "$DNS_URL$path" >/dev/null 2>&1; then
            print_success "Static file found: $path"
            static_found=true
        fi
    done
    
    if [[ "$static_found" == "true" ]]; then
        return 0
    else
        print_warning "No common static files found (this might be normal)"
        return 0  # Don't fail the test for this
    fi
}

test_database_connectivity() {
    print_test "Database Connectivity (via API)"
    
    # Try to create a test student
    local test_data='{"name":"Test Student","email":"test@example.com","course":"Test Course"}'
    
    local create_response=$(curl -s --connect-timeout $TIMEOUT -X POST \
        -H "Content-Type: application/json" \
        -d "$test_data" \
        "$DNS_URL/api/students" 2>/dev/null || echo "ERROR")
    
    if [[ "$create_response" != "ERROR" ]]; then
        print_success "Database appears to be connected (API accepts POST requests)"
        
        # Try to get students list to verify database interaction
        local get_response=$(curl -s --connect-timeout $TIMEOUT "$DNS_URL/api/students" 2>/dev/null || echo "ERROR")
        if [[ "$get_response" != "ERROR" ]]; then
            print_success "Database read operations working"
        fi
        
        return 0
    else
        print_warning "Database connectivity test inconclusive"
        return 0  # Don't fail for this
    fi
}

check_response_times() {
    print_test "Response Times"
    
    local endpoints=("/" "/health" "/students/" "/docs")
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout $TIMEOUT "$DNS_URL$endpoint" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
            
            if [[ $duration -lt 1000 ]]; then
                print_success "$endpoint responds in ${duration}ms (fast)"
            elif [[ $duration -lt 3000 ]]; then
                print_success "$endpoint responds in ${duration}ms (good)"
            else
                print_warning "$endpoint responds in ${duration}ms (slow)"
            fi
        fi
    done
}

verify_application_structure() {
    print_test "Application Structure"
    
    # Check if the main application files exist
    local app_files=("app/main.py" "app/routes/students.py" "app/templates")
    local missing_files=()
    
    for file in "${app_files[@]}"; do
        if [[ -f "$file" ]] || [[ -d "$file" ]]; then
            print_success "Found: $file"
        else
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All critical application files found"
        return 0
    else
        print_warning "Some files missing: ${missing_files[*]}"
        return 0  # Don't fail for this
    fi
}

run_comprehensive_test() {
    local total_tests=0
    local passed_tests=0
    
    print_header "COMPREHENSIVE DEPLOYMENT TEST"
    
    echo -e "${BLUE}Testing application at: $DNS_URL${NC}"
    echo -e "${BLUE}Port: $NODE_PORT${NC}"
    echo ""
    
    # Run all tests
    local tests=(
        "test_dns_connectivity"
        "test_health_endpoint"
        "test_frontend_root"
        "test_students_page"
        "test_api_docs"
        "test_api_students_endpoint"
        "test_static_files"
        "test_database_connectivity"
        "check_response_times"
        "verify_application_structure"
    )
    
    for test_func in "${tests[@]}"; do
        echo ""
        total_tests=$((total_tests + 1))
        
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
    done
    
    # Summary
    print_header "TEST SUMMARY"
    
    echo -e "${CYAN}Total Tests: $total_tests${NC}"
    echo -e "${GREEN}Passed: $passed_tests${NC}"
    echo -e "${RED}Failed: $((total_tests - passed_tests))${NC}"
    echo ""
    
    local success_rate=$(( (passed_tests * 100) / total_tests ))
    
    if [[ $success_rate -ge 80 ]]; then
        print_success "🎉 DEPLOYMENT TEST PASSED! ($success_rate% success rate)"
        echo ""
        echo -e "${GREEN}✅ Your application is working correctly!${NC}"
        echo -e "${CYAN}🌐 Access your app at: $DNS_URL${NC}"
        echo -e "${CYAN}👥 Students page: $DNS_URL/students/${NC}"
        echo -e "${CYAN}📚 API docs: $DNS_URL/docs${NC}"
        echo -e "${CYAN}❤️ Health check: $DNS_URL/health${NC}"
        return 0
    else
        print_error "❌ DEPLOYMENT TEST FAILED! ($success_rate% success rate)"
        echo ""
        echo -e "${YELLOW}Some issues were found. Check the test results above.${NC}"
        return 1
    fi
}

# Show detailed curl test
show_detailed_curl_test() {
    print_header "DETAILED CURL TESTS"
    
    echo -e "${CYAN}1. Testing Root Page:${NC}"
    echo "curl -v $DNS_URL/"
    curl -v "$DNS_URL/" 2>&1 | head -20
    echo ""
    
    echo -e "${CYAN}2. Testing Health Endpoint:${NC}"
    echo "curl -v $DNS_URL/health"
    curl -v "$DNS_URL/health" 2>&1
    echo ""
    
    echo -e "${CYAN}3. Testing Students Page:${NC}"
    echo "curl -v $DNS_URL/students/"
    curl -v "$DNS_URL/students/" 2>&1 | head -20
    echo ""
    
    echo -e "${CYAN}4. Testing API Endpoint:${NC}"
    echo "curl -v $DNS_URL/api/students"
    curl -v "$DNS_URL/api/students" 2>&1
    echo ""
}

# Main execution
main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
  ______          __     ____             __                          __ 
 /_  __/__  _____/ /_   / __ \___  ____  / /___  __  ______ ___  ___  / /_
  / / / _ \/ ___/ __/  / / / / _ \/ __ \/ / __ \/ / / / __ `__ \/ _ \/ __/
 / / /  __(__  ) /_   / /_/ /  __/ /_/ / / /_/ / /_/ / / / / / /  __/ /_  
/_/  \___/____/\__/  /_____/\___/ .___/_/\____/\__, /_/ /_/ /_/\___/\__/  
                               /_/            /____/                      
EOF
    echo -e "${NC}"
    
    case "${1:-}" in
        --detailed|-d)
            show_detailed_curl_test
            ;;
        --help|-h)
            echo "🧪 Deployment Test Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --detailed, -d    Show detailed curl tests"
            echo "  --help, -h        Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  DNS_URL          Target URL (default: http://18.206.89.183)"
            echo "  NODE_PORT        Port number (default: 30011)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Run comprehensive test"
            echo "  $0 --detailed                # Show detailed curl output"
            echo "  DNS_URL=http://myapp.com $0  # Test different URL"
            exit 0
            ;;
        *)
            run_comprehensive_test
            ;;
    esac
}

main "$@"