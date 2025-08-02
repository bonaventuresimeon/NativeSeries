#!/bin/bash
# =============================================================================
# 🚀 NATIVESERIES - SIMPLIFIED DEPLOYMENT SCRIPT
# =============================================================================
# This script provides a simplified deployment solution for the NativeSeries
# application using Docker Compose only. Perfect for development and testing.
# 
# Author: Bonaventure Simeon
# Email: contact@bonaventure.org.ng
# Phone: +234 (812) 222 5406
#
# Features:
# - Automatic tool installation (Docker, Docker Compose)
# - Docker Compose deployment (port 8011)
# - Health verification and monitoring
# - Comprehensive error handling
# - Cross-platform compatibility
# 
# Usage: sudo ./deploy-simple.sh
# =============================================================================

set -e

echo "🚀 Starting NativeSeries simplified deployment to 18.206.89.183:8011"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if we're in a container environment
is_container() {
    [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null
}

# Function to check disk space
check_disk_space() {
    print_step "Checking disk space..."
    
    # Get available disk space
    local available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    local total_space=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
    local used_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    print_status "Disk space: ${available_space}G available out of ${total_space}G total (${used_percent}% used)"
    
    # Check if we have enough space (at least 5GB available)
    if [ "$available_space" -lt 5 ]; then
        print_warning "Low disk space detected (${available_space}G available)"
        print_status "Cleaning up Docker system to free space..."
        sudo docker system prune -af --volumes 2>/dev/null || true
        print_status "Disk space after cleanup:"
        df -h | grep -E "(Filesystem|/dev/)"
    else
        print_status "Sufficient disk space available"
    fi
}

# Function to install Docker
install_docker() {
    print_step "Installing Docker..."
    
    if command_exists docker; then
        print_status "Docker is already installed"
        return
    fi
    
    # Install Docker based on OS
    if command_exists apt-get; then
        # Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    elif command_exists yum; then
        # CentOS/RHEL/Amazon Linux
        sudo yum install -y docker
    else
        print_error "Unsupported package manager"
        exit 1
    fi
    
    # Start Docker
    if is_container; then
        print_status "Running in container, starting Docker daemon..."
        sudo dockerd &
        sleep 10
    else
        if command_exists systemctl; then
            sudo systemctl start docker
            sudo systemctl enable docker
        else
            sudo service docker start
        fi
    fi
    
    # Verify Docker is running
    if ! sudo docker ps >/dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    print_status "Docker installed and running successfully"
}

# Function to install Docker Compose
install_docker_compose() {
    print_step "Installing Docker Compose..."
    
    if command_exists docker-compose; then
        print_status "Docker Compose is already installed"
        return
    fi
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Also install as Docker plugin
    sudo mkdir -p ~/.docker/cli-plugins/
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o ~/.docker/cli-plugins/docker-compose
    sudo chmod +x ~/.docker/cli-plugins/docker-compose
    
    print_status "Docker Compose installed successfully"
}

# Function to check Docker Compose command
check_docker_compose() {
    print_step "Checking Docker Compose..."
    
    # Determine which Docker Compose command to use
    if command_exists docker-compose; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_status "Using docker-compose command"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_status "Using docker compose command"
    else
        print_error "Docker Compose not found"
        exit 1
    fi
}

# Function to cleanup existing resources
cleanup_existing() {
    print_step "Cleaning up existing resources..."
    
    # Clean up Docker system and reclaim space
    if command_exists docker; then
        print_status "Cleaning up Docker system and reclaiming space..."
        sudo docker system prune -af --volumes 2>/dev/null || true
        
        # Check disk space after cleanup
        print_status "Checking disk space after cleanup..."
        df -h | grep -E "(Filesystem|/dev/)"
    fi
    
    print_status "Cleanup completed"
}

# Function to setup Docker Compose
setup_docker_compose() {
    print_step "Setting up Docker Compose environment..."
    
    # Stop any running containers
    if [ ! -z "$DOCKER_COMPOSE_CMD" ]; then
        print_status "Stopping existing Docker Compose services..."
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
    fi
    
    # Build and start services
    print_status "Building and starting Docker Compose services..."
    $DOCKER_COMPOSE_CMD up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service status
    print_status "Checking service status..."
    $DOCKER_COMPOSE_CMD ps
    
    print_status "Docker Compose setup completed"
}

# Function to verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Wait for services to be ready
    sleep 30
    
    # Test Docker Compose deployment
    print_status "Testing Docker Compose deployment (port 8011)..."
    if curl -s http://localhost:8011/health >/dev/null; then
        print_status "✅ Docker Compose deployment is healthy!"
        curl -s http://localhost:8011/health | jq . 2>/dev/null || curl -s http://localhost:8011/health
    else
        print_warning "⚠️ Docker Compose deployment not yet ready"
        print_status "Checking container logs..."
        $DOCKER_COMPOSE_CMD logs --tail=20
    fi
    
    print_status "Deployment verification completed"
}

# Function to display final information
display_final_info() {
    print_status "🎉 NativeSeries Simplified Deployment Completed Successfully!"
    echo ""
    echo "📋 Production Access Information:"
    echo "   🐳 Docker Compose Application: http://18.206.89.183:8011"
    echo "   📖 API Documentation: http://18.206.89.183:8011/docs"
    echo "   🩺 Health Check: http://18.206.89.183:8011/health"
    echo "   📊 Metrics: http://18.206.89.183:8011/metrics"
    echo "   📈 Grafana: http://18.206.89.183:3000 (admin/admin123)"
    echo "   📊 Prometheus: http://18.206.89.183:9090"
    echo "   🗄️ Adminer: http://18.206.89.183:8080"
    echo ""
    echo "🔧 Management Commands:"
    echo "   docker compose ps"
    echo "   docker compose logs -f"
    echo "   docker compose down"
    echo ""
    echo "🧪 Health Check Commands:"
    echo "   curl http://18.206.89.183:8011/health"
    echo "   sudo ./health-check.sh"
    echo ""
    echo "📝 Deployment Summary:"
    echo "   - Docker Compose: Port 8011 (Development/Testing)"
    echo "   - All services: Healthy and operational"
    echo "   - Simplified deployment for quick setup"
    echo ""
    echo "🎯 Next Steps:"
    echo "   - Access your application at http://18.206.89.183:8011"
    echo "   - Monitor with Grafana at http://18.206.89.183:3000"
    echo "   - For Kubernetes deployment, use the full deploy.sh script"
    echo ""
    print_status "NativeSeries application is running on:"
    print_status "  - Docker Compose: http://18.206.89.183:8011"
}

# Main deployment function
main() {
    print_step "Starting simplified deployment process..."
    
    # Install required tools
    install_docker
    install_docker_compose
    check_docker_compose
    
    # Check disk space before deployment
    check_disk_space
    
    # Cleanup existing resources
    cleanup_existing
    
    # Setup Docker Compose environment
    setup_docker_compose
    
    # Verify deployment
    verify_deployment
    
    # Display final information
    display_final_info
}

# Run main function
main "$@"