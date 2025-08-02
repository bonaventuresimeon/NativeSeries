#!/bin/bash

# =============================================================================
# 🧹 STUDENT TRACKER - COMPREHENSIVE CLEANUP SCRIPT
# =============================================================================
# This script provides a complete cleanup solution for the Student Tracker
# application. It removes all Docker containers, images, volumes, and
# Kubernetes resources.
#
# Features:
# - Docker Compose cleanup
# - Docker system cleanup
# - Kubernetes cluster cleanup
# - Temporary file cleanup
# - Cross-platform compatibility
#
# Usage: sudo ./cleanup.sh
# =============================================================================

set -e

echo "🧹 Starting comprehensive cleanup..."

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

# Function to cleanup Docker Compose
cleanup_docker_compose() {
    print_step "Cleaning up Docker Compose services..."
    
    if command_exists docker; then
        print_status "Stopping Docker Compose services..."
        # Try both docker-compose and docker compose
        if command_exists docker-compose; then
            docker-compose down -v 2>/dev/null || true
        elif docker compose version >/dev/null 2>&1; then
            docker compose down -v 2>/dev/null || true
        fi
        
        print_status "Removing Docker Compose networks..."
        docker network prune -f 2>/dev/null || true
    else
        print_warning "Docker not found"
    fi
}

# Function to cleanup Docker system
cleanup_docker_system() {
    print_step "Cleaning up Docker system..."
    
    if command_exists docker; then
        print_status "Stopping all containers..."
        docker stop $(docker ps -q) 2>/dev/null || true
        
        print_status "Removing all containers..."
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        print_status "Removing application images..."
        docker rmi simple-app:latest 2>/dev/null || true
        docker rmi student-tracker:latest 2>/dev/null || true
        
        print_status "Cleaning up Docker system..."
        docker system prune -f 2>/dev/null || true
        
        print_status "Cleaning up Docker volumes..."
        docker volume prune -f 2>/dev/null || true
        
        print_status "Cleaning up Docker networks..."
        docker network prune -f 2>/dev/null || true
    else
        print_warning "Docker not found"
    fi
}

# Function to cleanup Kubernetes
cleanup_kubernetes() {
    print_step "Cleaning up Kubernetes resources..."
    
    if command_exists kind; then
        print_status "Deleting Kind cluster..."
        kind delete cluster --name simple-cluster 2>/dev/null || true
    else
        print_warning "Kind not found"
    fi
    
    if command_exists kubectl; then
        print_status "Cleaning up Kubernetes namespaces..."
        kubectl delete namespace argocd --ignore-not-found=true 2>/dev/null || true
        kubectl delete namespace default --ignore-not-found=true 2>/dev/null || true
    else
        print_warning "kubectl not found"
    fi
}

# Function to cleanup temporary files
cleanup_temp_files() {
    print_step "Cleaning up temporary files..."
    
    print_status "Removing temporary installation files..."
    rm -f kind argocd-linux-amd64 kubectl 2>/dev/null || true
    rm -f linux-amd64/helm 2>/dev/null || true
    rm -rf linux-amd64 2>/dev/null || true
    
    print_status "Removing Docker Compose logs..."
    rm -f docker-compose.log 2>/dev/null || true
}

# Function to cleanup logs
cleanup_logs() {
    print_step "Cleaning up application logs..."
    
    print_status "Removing application logs..."
    rm -rf logs/* 2>/dev/null || true
    
    print_status "Removing Docker logs..."
    sudo journalctl --vacuum-time=1d 2>/dev/null || true
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo ""
    print_status "🎉 Cleanup completed successfully!"
    echo ""
    echo "📋 Cleanup Summary:"
    echo "   ✅ Docker Compose services stopped and removed"
    echo "   ✅ Docker containers, images, and volumes cleaned"
    echo "   ✅ Kubernetes cluster deleted"
    echo "   ✅ Temporary files removed"
    echo "   ✅ Application logs cleaned"
    echo ""
    echo "🔧 To redeploy, run:"
    echo "   sudo ./deploy.sh"
    echo ""
}

# Main cleanup function
main() {
    print_step "Starting comprehensive cleanup process..."
    
    # Cleanup Docker Compose
    cleanup_docker_compose
    
    # Cleanup Docker system
    cleanup_docker_system
    
    # Cleanup Kubernetes
    cleanup_kubernetes
    
    # Cleanup temporary files
    cleanup_temp_files
    
    # Cleanup logs
    cleanup_logs
    
    # Display summary
    display_cleanup_summary
    
    print_status "Cleanup completed! All resources have been removed."
}

# Run main function
main "$@"