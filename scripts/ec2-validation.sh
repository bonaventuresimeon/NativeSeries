#!/bin/bash

# 🚀 EC2 Deployment Validation Script
# This script validates the EC2 setup and deployment for Student Tracker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate EC2 environment
validate_ec2_environment() {
    print_status "🔍 Validating EC2 environment..."
    
    # Check if we're on an EC2 instance
    if curl -s http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        print_success "✅ Running on EC2 instance: ${INSTANCE_ID}"
        
        # Get instance metadata
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        print_info "Instance Type: ${INSTANCE_TYPE}"
        print_info "Availability Zone: ${AVAILABILITY_ZONE}"
    else
        print_warning "⚠️  Not running on EC2 instance (or metadata service unavailable)"
    fi
    
    # Check system information
    print_status "🔍 Checking system information..."
    OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    print_info "Operating System: ${OS_INFO}"
    
    KERNEL_VERSION=$(uname -r)
    print_info "Kernel Version: ${KERNEL_VERSION}"
    
    # Check system resources
    print_status "🔍 Checking system resources..."
    CPU_CORES=$(nproc)
    print_info "CPU Cores: ${CPU_CORES}"
    
    MEMORY_TOTAL=$(free -h | awk 'NR==2{print $2}')
    print_info "Total Memory: ${MEMORY_TOTAL}"
    
    DISK_SPACE=$(df -h / | awk 'NR==2{print $4}')
    print_info "Available Disk Space: ${DISK_SPACE}"
    
    print_success "✅ EC2 environment validation completed"
}

# Function to validate Docker installation
validate_docker_installation() {
    print_status "🔍 Validating Docker installation..."
    
    if ! command_exists docker; then
        print_error "❌ Docker is not installed"
        return 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version)
    print_success "✅ Docker installed: ${DOCKER_VERSION}"
    
    # Check if Docker daemon is running
    if ! sudo docker info &> /dev/null; then
        print_error "❌ Docker daemon is not running"
        print_info "Run: sudo systemctl start docker"
        return 1
    fi
    
    # Check Docker daemon info
    DOCKER_DRIVER=$(sudo docker info | grep "Storage Driver" | awk '{print $3}')
    print_info "Storage Driver: ${DOCKER_DRIVER}"
    
    DOCKER_ROOT_DIR=$(sudo docker info | grep "Docker Root Dir" | awk '{print $4}')
    print_info "Docker Root Directory: ${DOCKER_ROOT_DIR}"
    
    # Check if user is in docker group
    if groups | grep -q docker; then
        print_success "✅ User is in docker group"
    else
        print_warning "⚠️  User is not in docker group"
        print_info "Run: sudo usermod -aG docker $USER"
    fi
    
    print_success "✅ Docker installation validation completed"
}

# Function to validate application deployment
validate_application_deployment() {
    print_status "🔍 Validating application deployment..."
    
    # Check if container is running
    if sudo docker ps | grep -q "${APP_NAME}"; then
        print_success "✅ Application container is running"
        
        # Get container details
        CONTAINER_ID=$(sudo docker ps | grep "${APP_NAME}" | awk '{print $1}')
        CONTAINER_STATUS=$(sudo docker inspect --format='{{.State.Status}}' "${APP_NAME}" 2>/dev/null)
        print_info "Container ID: ${CONTAINER_ID}"
        print_info "Container Status: ${CONTAINER_STATUS}"
        
        # Check container health
        if [ "$CONTAINER_STATUS" = "running" ]; then
            print_success "✅ Container is healthy"
        else
            print_warning "⚠️  Container status: ${CONTAINER_STATUS}"
        fi
        
        # Check port mapping
        if sudo docker port "${APP_NAME}" | grep -q "30011"; then
            print_success "✅ Port 30011 is exposed"
        else
            print_error "❌ Port 30011 is not exposed"
            print_info "Container port mapping:"
            sudo docker port "${APP_NAME}"
        fi
        
        # Check container logs for errors
        ERROR_COUNT=$(sudo docker logs "${APP_NAME}" 2>&1 | grep -i "error\|exception\|failed" | wc -l)
        if [ "$ERROR_COUNT" -eq 0 ]; then
            print_success "✅ No errors found in container logs"
        else
            print_warning "⚠️  Found ${ERROR_COUNT} potential errors in container logs"
            print_info "Recent logs:"
            sudo docker logs --tail 10 "${APP_NAME}"
        fi
        
    else
        print_error "❌ Application container is not running"
        print_info "Available containers:"
        sudo docker ps -a
        return 1
    fi
    
    print_success "✅ Application deployment validation completed"
}

# Function to validate network connectivity
validate_network_connectivity() {
    print_status "🔍 Validating network connectivity..."
    
    # Check if port 30011 is listening
    if sudo netstat -tlnp | grep ":30011 " >/dev/null 2>&1; then
        print_success "✅ Port 30011 is listening"
    else
        print_error "❌ Port 30011 is not listening"
        print_info "Listening ports:"
        sudo netstat -tlnp | grep LISTEN
    fi
    
    # Check local connectivity
    if curl -f "${PRODUCTION_URL}/health" >/dev/null 2>&1; then
        print_success "✅ Local health check passes"
    else
        print_error "❌ Local health check fails"
        print_info "Testing with verbose output:"
        curl -v "${PRODUCTION_URL}/health" 2>&1 | head -10
    fi
    
    # Check external connectivity (if possible)
    if command_exists curl; then
        EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")
        if [ "$EXTERNAL_IP" != "N/A" ]; then
            print_info "External IP: ${EXTERNAL_IP}"
            if curl -f "http://${EXTERNAL_IP}:${PRODUCTION_PORT}/health" >/dev/null 2>&1; then
                print_success "✅ External health check passes"
            else
                print_warning "⚠️  External health check fails (may be security group issue)"
            fi
        fi
    fi
    
    print_success "✅ Network connectivity validation completed"
}

# Function to validate application endpoints
validate_application_endpoints() {
    print_status "🔍 Validating application endpoints..."
    
    ENDPOINTS=(
        "health:Health Check"
        "docs:API Documentation"
        "students:Students Interface"
        "metrics:Prometheus Metrics"
    )
    
    for endpoint_info in "${ENDPOINTS[@]}"; do
        endpoint=$(echo "$endpoint_info" | cut -d: -f1)
        description=$(echo "$endpoint_info" | cut -d: -f2)
        
        if curl -f "${PRODUCTION_URL}/${endpoint}" >/dev/null 2>&1; then
            print_success "✅ ${description} endpoint is responding"
        else
            print_warning "⚠️  ${description} endpoint is not responding"
        fi
    done
    
    # Test health endpoint in detail
    print_status "🔍 Testing health endpoint details..."
    HEALTH_RESPONSE=$(curl -s "${PRODUCTION_URL}/health" 2>/dev/null)
    if command_exists jq; then
        STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status' 2>/dev/null)
        UPTIME=$(echo "$HEALTH_RESPONSE" | jq -r '.uptime_seconds' 2>/dev/null)
        REQUEST_COUNT=$(echo "$HEALTH_RESPONSE" | jq -r '.request_count' 2>/dev/null)
        
        if [ "$STATUS" = "healthy" ]; then
            print_success "✅ Application status: ${STATUS}"
            print_info "Uptime: ${UPTIME} seconds"
            print_info "Request count: ${REQUEST_COUNT}"
        else
            print_warning "⚠️  Application status: ${STATUS}"
        fi
    else
        print_info "Health response: ${HEALTH_RESPONSE}"
    fi
    
    print_success "✅ Application endpoints validation completed"
}

# Function to validate security configuration
validate_security_configuration() {
    print_status "🔍 Validating security configuration..."
    
    # Check security group configuration (if on EC2)
    if curl -s http://169.254.169.254/latest/meta-data/security-groups >/dev/null 2>&1; then
        SECURITY_GROUPS=$(curl -s http://169.254.169.254/latest/meta-data/security-groups)
        print_info "Security Groups: ${SECURITY_GROUPS}"
    fi
    
    # Check if required ports are open
    REQUIRED_PORTS=(22 80 30011 30080 30443)
    for port in "${REQUIRED_PORTS[@]}"; do
        if sudo netstat -tlnp | grep ":$port " >/dev/null 2>&1; then
            print_success "✅ Port ${port} is open"
        else
            print_warning "⚠️  Port ${port} is not open"
        fi
    done
    
    # Check firewall status
    if command_exists ufw; then
        UFW_STATUS=$(sudo ufw status | head -1)
        print_info "UFW Status: ${UFW_STATUS}"
    elif command_exists iptables; then
        print_info "iptables is configured"
    fi
    
    # Check for running processes as root
    ROOT_PROCESSES=$(ps aux | grep -v grep | grep "^root" | wc -l)
    print_info "Root processes running: ${ROOT_PROCESSES}"
    
    print_success "✅ Security configuration validation completed"
}

# Function to validate performance metrics
validate_performance_metrics() {
    print_status "🔍 Validating performance metrics..."
    
    # Check system performance
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    print_info "CPU Usage: ${CPU_USAGE}%"
    
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}' 2>/dev/null || echo "N/A")
    print_info "Memory Usage: ${MEMORY_USAGE}"
    
    DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
    print_info "Disk Usage: ${DISK_USAGE}"
    
    # Check Docker performance
    if sudo docker stats --no-stream "${APP_NAME}" >/dev/null 2>&1; then
        print_success "✅ Docker stats available"
        print_info "Container performance:"
        sudo docker stats --no-stream "${APP_NAME}"
    else
        print_warning "⚠️  Could not get Docker stats"
    fi
    
    # Check application response time
    if command_exists curl; then
        RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s "${PRODUCTION_URL}/health")
        print_info "Health endpoint response time: ${RESPONSE_TIME}s"
    fi
    
    print_success "✅ Performance metrics validation completed"
}

# Function to generate validation report
generate_validation_report() {
    print_status "📊 Generating validation report..."
    
    REPORT_FILE="ec2-validation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "EC2 Deployment Validation Report"
        echo "================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "System Information:"
        echo "-------------------"
        echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "Kernel: $(uname -r)"
        echo "CPU Cores: $(nproc)"
        echo "Memory: $(free -h | awk 'NR==2{print $2}')"
        echo "Disk Space: $(df -h / | awk 'NR==2{print $4}')"
        echo ""
        
        echo "Docker Information:"
        echo "-------------------"
        echo "Version: $(docker --version)"
        echo "Status: $(sudo systemctl is-active docker)"
        echo ""
        
        echo "Application Information:"
        echo "-----------------------"
        echo "Container Status: $(sudo docker inspect --format='{{.State.Status}}' "${APP_NAME}" 2>/dev/null || echo 'Not running')"
        echo "Port Mapping: $(sudo docker port "${APP_NAME}" 2>/dev/null || echo 'No mapping')"
        echo ""
        
        echo "Network Information:"
        echo "-------------------"
        echo "Listening Ports:"
        sudo netstat -tlnp | grep LISTEN
        echo ""
        
        echo "Health Check:"
        echo "-------------"
        curl -s "${PRODUCTION_URL}/health" 2>/dev/null || echo "Health check failed"
        
    } > "$REPORT_FILE"
    
    print_success "✅ Validation report generated: ${REPORT_FILE}"
}

# Main validation function
main() {
    echo "🚀 EC2 Deployment Validation Script"
    echo "==================================="
    echo ""
    
    # Run all validations
    validate_ec2_environment
    echo ""
    
    validate_docker_installation
    echo ""
    
    validate_application_deployment
    echo ""
    
    validate_network_connectivity
    echo ""
    
    validate_application_endpoints
    echo ""
    
    validate_security_configuration
    echo ""
    
    validate_performance_metrics
    echo ""
    
    generate_validation_report
    echo ""
    
    print_success "🎉 EC2 deployment validation completed!"
    print_info "Check the validation report for detailed information."
    print_info "If any issues were found, please review the warnings and errors above."
}

# Run main function
main "$@"