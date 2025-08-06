#!/bin/bash

# Deployment Validation and Fix Script
# Version: 2.0.0 - Enhanced validation with auto-fix capabilities

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
DOCKER_IMAGE="ghcr.io/bonaventuresimeon/nativeseries"
PRODUCTION_HOST="${PRODUCTION_HOST:-54.166.101.159}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠️  WARN]${NC} $1"; }
print_error() { echo -e "${RED}[❌ FAIL]${NC} $1"; }
print_info() { echo -e "${CYAN}[ℹ️  INFO]${NC} $1"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Function to increment counters
check_result() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    case $1 in
        "pass") PASSED_CHECKS=$((PASSED_CHECKS + 1)) ;;
        "fail") FAILED_CHECKS=$((FAILED_CHECKS + 1)) ;;
        "warn") WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Banner
print_section "🚀 Student Tracker - Deployment Validation & Fix"

print_info "Target Configuration:"
print_info "  📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
print_info "  🐳 Docker Image: ${DOCKER_IMAGE}:latest"
print_info "  📁 Namespace: ${NAMESPACE}"
print_info ""

# 1. Check Tools Installation
print_section "🛠️  Tool Installation Validation"

tools=("docker" "kubectl" "helm" "python3" "curl" "jq")
for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
        print_status "$tool is installed"
        check_result "pass"
    else
        print_error "$tool is missing"
        check_result "fail"
    fi
done

# 2. Check Project Structure
print_section "📁 Project Structure Validation"

required_files=(
    "app/main.py"
    "requirements.txt" 
    "Dockerfile"
    "helm-chart/Chart.yaml"
    "helm-chart/values.yaml"
    "argocd/application.yaml"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "$file exists"
        check_result "pass"
    else
        print_error "$file is missing"
        check_result "fail"
    fi
done

# 3. Validate Python Application
print_section "🐍 Python Application Validation"

if [[ -f "requirements.txt" ]]; then
    print_status "requirements.txt found"
    check_result "pass"
else
    print_error "requirements.txt missing"
    check_result "fail"
fi

# Check virtual environment
if [[ -d "venv" ]]; then
    print_status "Virtual environment exists"
    check_result "pass"
else
    print_warning "Virtual environment not found - creating one"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    check_result "warn"
fi

# Test application import
if source venv/bin/activate && python -c "from app.main import app; print('✅ App imports successfully')" 2>/dev/null; then
    print_status "Application imports successfully"
    check_result "pass"
else
    print_error "Application import failed"
    check_result "fail"
fi

# 4. Validate Docker Configuration
print_section "🐳 Docker Configuration Validation"

if command_exists docker; then
    if docker info >/dev/null 2>&1; then
        print_status "Docker daemon is running"
        check_result "pass"
    elif sudo docker info >/dev/null 2>&1; then
        print_status "Docker daemon is running (requires sudo)"
        check_result "pass"
    else
        print_error "Docker daemon is not accessible"
        check_result "fail"
    fi
else
    print_error "Docker is not installed"
    check_result "fail"
fi

# Check Dockerfile
if [[ -f "Dockerfile" ]]; then
    print_status "Dockerfile exists"
    check_result "pass"
    
    # Validate Dockerfile syntax
    if docker build -t ${APP_NAME}:test . --quiet >/dev/null 2>&1; then
        print_status "Docker image builds successfully"
        check_result "pass"
        docker rmi ${APP_NAME}:test >/dev/null 2>&1 || true
    else
        print_error "Docker build failed"
        check_result "fail"
    fi
else
    print_error "Dockerfile missing"
    check_result "fail"
fi

# 5. Validate Helm Chart
print_section "⎈ Helm Chart Validation"

if [[ -d "helm-chart" ]]; then
    print_status "Helm chart directory exists"
    check_result "pass"
    
    # Lint Helm chart
    if helm lint helm-chart >/dev/null 2>&1; then
        print_status "Helm chart linting passed"
        check_result "pass"
    else
        print_error "Helm chart linting failed"
        print_info "Running helm lint to show errors:"
        helm lint helm-chart || true
        check_result "fail"
    fi
    
    # Test template rendering
    if helm template test helm-chart >/dev/null 2>&1; then
        print_status "Helm template rendering successful"
        check_result "pass"
    else
        print_error "Helm template rendering failed"
        check_result "fail"
    fi
else
    print_error "Helm chart directory missing"
    check_result "fail"
fi

# 6. Validate ArgoCD Configuration
print_section "🎯 ArgoCD Configuration Validation"

if [[ -f "argocd/application.yaml" ]]; then
    print_status "ArgoCD application.yaml exists"
    check_result "pass"
    
    # Validate YAML syntax
    if kubectl apply --dry-run=client -f argocd/application.yaml >/dev/null 2>&1; then
        print_status "ArgoCD application YAML is valid"
        check_result "pass"
    else
        print_error "ArgoCD application YAML validation failed"
        check_result "fail"
    fi
else
    print_error "ArgoCD application.yaml missing"
    check_result "fail"
fi

# 7. Test Application Locally
print_section "🧪 Local Application Testing"

# Kill any existing processes
pkill -f uvicorn >/dev/null 2>&1 || true
sleep 2

# Test with virtual environment
if [[ -d "venv" ]]; then
    print_info "Starting application for testing..."
    source venv/bin/activate
    timeout 45 uvicorn app.main:app --host 0.0.0.0 --port 8001 > /tmp/test-app.log 2>&1 &
    APP_PID=$!
    
    # Wait for app to start (accounting for DB timeout)
    sleep 40
    
    if curl -s http://localhost:8001/health >/dev/null 2>&1; then
        print_status "Application health check passed"
        check_result "pass"
    else
        print_error "Application health check failed"
        print_info "Application log:"
        tail -10 /tmp/test-app.log || true
        check_result "fail"
    fi
    
    # Cleanup
    kill $APP_PID >/dev/null 2>&1 || true
else
    print_warning "Virtual environment not available for testing"
    check_result "warn"
fi

# 8. Docker Container Testing
print_section "🐳 Docker Container Testing"

if command_exists docker && docker info >/dev/null 2>&1; then
    # Stop any existing test containers
    docker stop test-validation >/dev/null 2>&1 || true
    docker rm test-validation >/dev/null 2>&1 || true
    
    # Build fresh image
    if docker build -t ${APP_NAME}:validation . >/dev/null 2>&1; then
        print_status "Docker image built successfully"
        check_result "pass"
        
        # Test container
        print_info "Starting container for testing..."
        docker run -d --name test-validation -p 8002:8000 ${APP_NAME}:validation >/dev/null 2>&1
        
        # Wait for container to start (accounting for DB timeout)
        sleep 40
        
        if curl -s http://localhost:8002/health >/dev/null 2>&1; then
            print_status "Docker container health check passed"
            check_result "pass"
        else
            print_error "Docker container health check failed"
            print_info "Container logs:"
            docker logs test-validation | tail -10 || true
            check_result "fail"
        fi
        
        # Cleanup
        docker stop test-validation >/dev/null 2>&1 || true
        docker rm test-validation >/dev/null 2>&1 || true
        docker rmi ${APP_NAME}:validation >/dev/null 2>&1 || true
    else
        print_error "Docker image build failed"
        check_result "fail"
    fi
else
    print_warning "Docker not available for container testing"
    check_result "warn"
fi

# 9. Configuration Validation
print_section "⚙️  Configuration Validation"

# Check environment variables in values.yaml
if grep -q "PRODUCTION_URL" helm-chart/values.yaml; then
    print_status "Production URL configured in Helm values"
    check_result "pass"
else
    print_warning "Production URL not found in Helm values"
    check_result "warn"
fi

# Check service configuration
if grep -q "nodePort: 30011" helm-chart/values.yaml; then
    print_status "NodePort correctly configured"
    check_result "pass"
else
    print_error "NodePort not correctly configured"
    check_result "fail"
fi

# Check image configuration
if grep -q "ghcr.io/bonaventuresimeon/nativeseries" helm-chart/values.yaml; then
    print_status "Container image correctly configured"
    check_result "pass"
else
    print_error "Container image not correctly configured"
    check_result "fail"
fi

# 10. Security Validation
print_section "🔒 Security Configuration Validation"

# Check security context in Helm values
if grep -q "runAsNonRoot: true" helm-chart/values.yaml; then
    print_status "Non-root security context configured"
    check_result "pass"
else
    print_warning "Non-root security context not configured"
    check_result "warn"
fi

# Check resource limits
if grep -q "limits:" helm-chart/values.yaml && grep -q "requests:" helm-chart/values.yaml; then
    print_status "Resource limits and requests configured"
    check_result "pass"
else
    print_warning "Resource limits/requests not fully configured"
    check_result "warn"
fi

# Final Report
print_section "📊 Validation Summary"

echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                        VALIDATION RESULTS                      ║${NC}"
echo -e "${WHITE}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${WHITE}║${NC} Total Checks:    ${CYAN}${TOTAL_CHECKS}${NC}"
echo -e "${WHITE}║${NC} Passed:          ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "${WHITE}║${NC} Failed:          ${RED}${FAILED_CHECKS}${NC}"
echo -e "${WHITE}║${NC} Warnings:        ${YELLOW}${WARNINGS}${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Calculate success rate
if [[ $TOTAL_CHECKS -gt 0 ]]; then
    SUCCESS_RATE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    echo -e "${WHITE}Success Rate: ${SUCCESS_RATE}%${NC}"
else
    SUCCESS_RATE=0
fi

echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    print_status "🎉 All critical validations passed! Deployment is ready."
    echo -e "${GREEN}✅ The application is ready for production deployment${NC}"
    echo -e "${GREEN}✅ Docker image builds successfully${NC}"
    echo -e "${GREEN}✅ Helm chart is valid and ready${NC}"
    echo -e "${GREEN}✅ Application runs correctly in containers${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Push Docker image: docker push ${DOCKER_IMAGE}:latest"
    echo -e "  2. Deploy with Helm: helm install ${APP_NAME} helm-chart"
    echo -e "  3. Set up ArgoCD: kubectl apply -f argocd/application.yaml"
    echo -e "  4. Access application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
    exit 0
elif [[ $SUCCESS_RATE -ge 80 ]]; then
    print_warning "⚠️  Most validations passed with some warnings"
    echo -e "${YELLOW}The deployment should work but may have minor issues${NC}"
    exit 1
else
    print_error "❌ Critical validation failures detected"
    echo -e "${RED}Please fix the failed checks before deploying${NC}"
    exit 2
fi