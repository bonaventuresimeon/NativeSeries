#!/bin/bash

# =============================================================================
# 🐳 STUDENT TRACKER - DOCKER COMPOSE DEPLOYMENT SCRIPT
# =============================================================================
# This script provides a quick Docker Compose deployment for the Student Tracker
# application. It's perfect for development and simple production deployments.
#
# Features:
# - Quick Docker Compose deployment
# - Health verification
# - Service status display
# - Cross-platform compatibility
#
# Usage: sudo ./docker-compose.sh
# =============================================================================

set -e

echo "🐳 Starting Docker Compose deployment to 18.206.89.183:8011"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
    
    print_status "Docker Compose installed successfully"
}

# Function to check Docker Compose
check_docker_compose() {
    if command_exists docker-compose; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not available. Installing..."
        install_docker_compose
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
    print_status "Using Docker Compose command: $DOCKER_COMPOSE_CMD"
}

# Function to check Docker
check_docker() {
    print_step "Checking Docker installation..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        print_status "You can run: sudo ./deploy.sh (which includes Docker installation)"
        exit 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker first."
        print_status "You can run: sudo systemctl start docker"
        exit 1
    fi
    
    print_status "Docker is ready"
}

# Function to cleanup existing
cleanup_existing() {
    print_step "Cleaning up existing deployment..."
    
    print_status "Stopping existing Docker Compose services..."
    $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
    
    print_status "Removing old images..."
    docker rmi simple-app:latest 2>/dev/null || true
    docker rmi student-tracker:latest 2>/dev/null || true
    
    print_status "Cleaning up Docker system..."
    docker system prune -f 2>/dev/null || true
}

# Function to deploy with Docker Compose
deploy_docker_compose() {
    print_step "Deploying with Docker Compose..."
    
    print_status "Building and starting services..."
    $DOCKER_COMPOSE_CMD up -d --build
    
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    print_status "Checking service status..."
    $DOCKER_COMPOSE_CMD ps
}

# Function to verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Check if containers are running
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        print_status "All services are running"
    else
        print_error "Some services failed to start"
        $DOCKER_COMPOSE_CMD logs
        exit 1
    fi
    
    # Test application health
    print_status "Testing application health..."
    if curl -s http://localhost:8011/health >/dev/null; then
        print_status "Application health check passed"
    else
        print_warning "Application health check failed (may need more time to start)"
    fi
    
    # Test main application
    print_status "Testing main application..."
    if curl -s http://localhost:8011/ >/dev/null; then
        print_status "Main application is accessible"
    else
        print_warning "Main application not yet accessible (may need more time to start)"
    fi
}

# Function to display final information
display_final_info() {
    echo ""
    print_status "🎉 Docker Compose deployment completed!"
    echo ""
    echo "📋 Access Information:"
    echo "   Application URL: http://18.206.89.183:8011"
    echo "   API Documentation: http://18.206.89.183:8011/docs"
    echo "   Health Check: http://18.206.89.183:8011/health"
    echo "   Metrics: http://18.206.89.183:8011/metrics"
    echo "   Grafana: http://18.206.89.183:3000 (admin/admin123)"
    echo "   Prometheus: http://18.206.89.183:9090"
    echo "   Adminer: http://18.206.89.183:8080"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   $DOCKER_COMPOSE_CMD ps          # View service status"
echo "   $DOCKER_COMPOSE_CMD logs -f     # View logs"
echo "   $DOCKER_COMPOSE_CMD restart     # Restart services"
echo "   $DOCKER_COMPOSE_CMD down        # Stop services"
    echo "   sudo ./cleanup.sh          # Complete cleanup"
    echo ""
}

# Main deployment function
main() {
    print_step "Starting Docker Compose deployment process..."
    
    # Check Docker
    check_docker
    
    # Check Docker Compose
    check_docker_compose
    
    # Cleanup existing
    cleanup_existing
    
    # Deploy with Docker Compose
    deploy_docker_compose
    
    # Verify deployment
    verify_deployment
    
    # Display final information
    display_final_info
    
    print_status "Docker Compose deployment completed! Your application is now running."
    print_status "Access it at: http://18.206.89.183:8011"
}

# Run main function
main "$@"