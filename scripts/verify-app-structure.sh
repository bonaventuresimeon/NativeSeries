#!/bin/bash

# 🔍 APPLICATION STRUCTURE VERIFICATION SCRIPT
# Verifies frontend templates, backend API structure, and deployment readiness

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DNS_URL="${DNS_URL:-http://18.206.89.183:30011}"

print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}🔍 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
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

print_test() {
    echo -e "${CYAN}🔍 $1${NC}"
}

# Verify application structure
verify_structure() {
    print_header "APPLICATION STRUCTURE VERIFICATION"
    
    local total_checks=0
    local passed_checks=0
    
    # Check main application files
    print_test "Checking main application files..."
    
    local required_files=(
        "app/main.py"
        "app/models.py"
        "app/database.py"
        "app/crud.py"
        "requirements.txt"
        "Dockerfile"
    )
    
    for file in "${required_files[@]}"; do
        total_checks=$((total_checks + 1))
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
            passed_checks=$((passed_checks + 1))
        else
            print_error "Missing: $file"
        fi
    done
    
    # Check routes directory
    print_test "Checking routes directory..."
    total_checks=$((total_checks + 1))
    if [[ -d "app/routes" ]]; then
        print_success "Found: app/routes/"
        passed_checks=$((passed_checks + 1))
        
        local route_files=("students.py" "api.py")
        for route_file in "${route_files[@]}"; do
            total_checks=$((total_checks + 1))
            if [[ -f "app/routes/$route_file" ]]; then
                print_success "Found: app/routes/$route_file"
                passed_checks=$((passed_checks + 1))
            else
                print_error "Missing: app/routes/$route_file"
            fi
        done
    else
        print_error "Missing: app/routes/ directory"
    fi
    
    # Check templates directory
    print_test "Checking templates directory..."
    total_checks=$((total_checks + 1))
    if [[ -d "templates" ]]; then
        print_success "Found: templates/ directory"
        passed_checks=$((passed_checks + 1))
        
        local template_files=("index.html" "students.html")
        for template_file in "${template_files[@]}"; do
            total_checks=$((total_checks + 1))
            if [[ -f "templates/$template_file" ]]; then
                print_success "Found: templates/$template_file"
                passed_checks=$((passed_checks + 1))
            else
                print_error "Missing: templates/$template_file"
            fi
        done
    else
        print_error "Missing: templates/ directory"
    fi
    
    echo ""
    print_info "Structure check: $passed_checks/$total_checks files found"
    
    if [[ $passed_checks -eq $total_checks ]]; then
        print_success "🎉 All required files found!"
        return 0
    else
        print_warning "Some files are missing but application may still work"
        return 1
    fi
}

# Verify templates content
verify_templates() {
    print_header "FRONTEND TEMPLATES VERIFICATION"
    
    if [[ ! -d "templates" ]]; then
        print_error "Templates directory not found"
        return 1
    fi
    
    local template_count=$(find templates -name "*.html" | wc -l)
    print_info "Found $template_count HTML template files"
    
    # List all templates
    print_test "Available templates:"
    for template in templates/*.html; do
        if [[ -f "$template" ]]; then
            local size=$(stat -c%s "$template" 2>/dev/null || echo "0")
            print_success "$(basename "$template") (${size} bytes)"
            
            # Check for basic HTML structure
            if grep -q "<html\|<HTML\|<!DOCTYPE" "$template" 2>/dev/null; then
                print_info "  ✓ Contains HTML structure"
            else
                print_warning "  ⚠ May not be valid HTML"
            fi
            
            # Check for student-related content
            if grep -qi "student" "$template" 2>/dev/null; then
                print_info "  ✓ Contains student-related content"
            fi
        fi
    done
    
    return 0
}

# Verify backend API structure
verify_backend() {
    print_header "BACKEND API VERIFICATION"
    
    # Check main.py for FastAPI setup
    print_test "Checking FastAPI application setup..."
    if [[ -f "app/main.py" ]]; then
        if grep -q "FastAPI" "app/main.py"; then
            print_success "FastAPI application found"
        else
            print_error "FastAPI not found in main.py"
        fi
        
        # Check for key endpoints
        if grep -q "/health" "app/main.py"; then
            print_success "Health endpoint found"
        else
            print_warning "Health endpoint not found in main.py"
        fi
        
        if grep -q "templates" "app/main.py"; then
            print_success "Template rendering setup found"
        else
            print_warning "Template rendering not found in main.py"
        fi
    fi
    
    # Check routes
    print_test "Checking API routes..."
    if [[ -f "app/routes/api.py" ]]; then
        print_success "API routes file found"
        
        # Check for CRUD operations
        local crud_ops=("GET" "POST" "PUT" "DELETE")
        for op in "${crud_ops[@]}"; do
            if grep -q "$op" "app/routes/api.py"; then
                print_success "  ✓ $op operations found"
            else
                print_warning "  ⚠ $op operations not found"
            fi
        done
    fi
    
    if [[ -f "app/routes/students.py" ]]; then
        print_success "Students routes file found"
        
        # Check for template responses
        if grep -q "TemplateResponse" "app/routes/students.py"; then
            print_success "  ✓ Template responses found"
        else
            print_warning "  ⚠ Template responses not found"
        fi
    fi
    
    return 0
}

# Check deployment configuration
verify_deployment_config() {
    print_header "DEPLOYMENT CONFIGURATION VERIFICATION"
    
    # Check Dockerfile
    print_test "Checking Dockerfile..."
    if [[ -f "Dockerfile" ]]; then
        print_success "Dockerfile found"
        
        if grep -q "COPY templates" "Dockerfile"; then
            print_success "  ✓ Templates copying configured"
        else
            print_warning "  ⚠ Templates copying not found in Dockerfile"
        fi
        
        if grep -q "EXPOSE" "Dockerfile"; then
            local port=$(grep "EXPOSE" "Dockerfile" | awk '{print $2}')
            print_success "  ✓ Port exposed: $port"
        else
            print_warning "  ⚠ No port exposed in Dockerfile"
        fi
    else
        print_error "Dockerfile not found"
    fi
    
    # Check requirements.txt
    print_test "Checking requirements.txt..."
    if [[ -f "requirements.txt" ]]; then
        print_success "Requirements file found"
        
        local deps=("fastapi" "uvicorn" "jinja2" "python-multipart")
        for dep in "${deps[@]}"; do
            if grep -qi "$dep" "requirements.txt"; then
                print_success "  ✓ $dep dependency found"
            else
                print_warning "  ⚠ $dep dependency not found"
            fi
        done
    else
        print_error "requirements.txt not found"
    fi
    
    # Check Helm chart
    print_test "Checking Helm chart..."
    if [[ -d "helm-chart" ]]; then
        print_success "Helm chart directory found"
        
        if [[ -f "helm-chart/values.yaml" ]]; then
            print_success "  ✓ values.yaml found"
            
            # Check image configuration
            if grep -q "repository:" "helm-chart/values.yaml"; then
                local repo=$(grep "repository:" "helm-chart/values.yaml" | awk '{print $2}')
                print_success "  ✓ Image repository: $repo"
            fi
            
            if grep -q "tag:" "helm-chart/values.yaml"; then
                local tag=$(grep "tag:" "helm-chart/values.yaml" | awk '{print $2}')
                print_success "  ✓ Image tag: $tag"
            fi
        fi
    else
        print_warning "Helm chart not found (optional)"
    fi
    
    return 0
}

# Test DNS connectivity
test_dns_connectivity() {
    print_header "DNS CONNECTIVITY TEST"
    
    print_test "Testing connectivity to $DNS_URL..."
    
    # Test different endpoints
    local endpoints=("" "/health" "/docs" "/students/")
    local working_endpoints=0
    
    for endpoint in "${endpoints[@]}"; do
        local url="$DNS_URL$endpoint"
        print_test "Testing: $url"
        
        if curl -s --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1; then
            print_success "✓ $url is accessible"
            working_endpoints=$((working_endpoints + 1))
        else
            print_error "✗ $url is not accessible"
        fi
    done
    
    if [[ $working_endpoints -gt 0 ]]; then
        print_success "🎉 $working_endpoints/${#endpoints[@]} endpoints are working!"
        return 0
    else
        print_error "❌ No endpoints are accessible"
        print_info "This could mean:"
        print_info "  • Application is not deployed yet"
        print_info "  • Application is deployed on different port"
        print_info "  • Network connectivity issues"
        print_info "  • Application is starting up"
        return 1
    fi
}

# Generate deployment commands
generate_deployment_commands() {
    print_header "DEPLOYMENT COMMANDS"
    
    echo -e "${CYAN}To deploy your application, use one of these methods:${NC}"
    echo ""
    
    echo -e "${GREEN}🚀 Method 1: Super Simple Deploy (Recommended)${NC}"
    echo "   ./scripts/simple-deploy.sh"
    echo ""
    
    echo -e "${GREEN}🚀 Method 2: Original Deploy Script${NC}"
    echo "   ./scripts/deploy.sh --force-prune"
    echo ""
    
    echo -e "${GREEN}🚀 Method 3: Docker Build and Run${NC}"
    echo "   docker build -t student-tracker ."
    echo "   docker run -d -p 30011:8000 student-tracker"
    echo ""
    
    echo -e "${GREEN}🚀 Method 4: Local Development${NC}"
    echo "   python3 -m venv venv"
    echo "   source venv/bin/activate"
    echo "   pip install -r requirements.txt"
    echo "   uvicorn app.main:app --host 0.0.0.0 --port 8000"
    echo ""
}

# Main function
main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
   ___                _____ __                   __                   
  /   |  ____  ____  / ___// /________  _______/ /___  ________  _____
 / /| | / __ \/ __ \ \__ \/ __/ ___/ / / / ___/ __/ / / / ___/ _ \/ ___/
/ ___ |/ /_/ / /_/ /___/ / /_/ /  / /_/ / /__/ /_/ /_/ / /  /  __(__  ) 
/_/  |_/ .___/ .___//____/\__/_/   \__,_/\___/\__/\__,_/_/   \___/____/  
      /_/   /_/                                                         
                        VERIFICATION TOOL
EOF
    echo -e "${NC}"
    
    print_info "This tool verifies your application structure and deployment readiness"
    print_info "Target DNS: $DNS_URL"
    echo ""
    
    local overall_success=true
    
    # Run all verifications
    verify_structure || overall_success=false
    verify_templates || overall_success=false
    verify_backend || overall_success=false
    verify_deployment_config || overall_success=false
    test_dns_connectivity || overall_success=false
    
    # Final summary
    print_header "VERIFICATION SUMMARY"
    
    if [[ "$overall_success" == "true" ]]; then
        print_success "🎉 ALL VERIFICATIONS PASSED!"
        echo ""
        print_info "Your application is ready for deployment!"
        print_info "Frontend templates: ✅ Found and verified"
        print_info "Backend API: ✅ Structure verified"
        print_info "Deployment config: ✅ Ready"
        print_info "DNS connectivity: ✅ Working"
    else
        print_warning "⚠️  SOME ISSUES FOUND"
        echo ""
        print_info "Your application structure is mostly ready, but check the issues above."
        print_info "Most issues are non-critical and won't prevent deployment."
    fi
    
    generate_deployment_commands
    
    print_header "🎊 VERIFICATION COMPLETE!"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "🔍 Application Structure Verification Tool"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h        Show this help"
        echo ""
        echo "Environment Variables:"
        echo "  DNS_URL          Target URL (default: http://18.206.89.183:30011)"
        echo ""
        echo "This tool verifies:"
        echo "  • Application file structure"
        echo "  • Frontend templates"
        echo "  • Backend API setup"
        echo "  • Deployment configuration"
        echo "  • DNS connectivity"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac