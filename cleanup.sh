#!/bin/bash

set -e

echo "🧹 Cleaning up deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Stop and remove Docker Compose services
if command_exists docker-compose; then
    print_status "Stopping Docker Compose services..."
    docker-compose down -v 2>/dev/null || true
else
    print_warning "Docker Compose not found"
fi

# Delete kind cluster if it exists
if command_exists kind && kind get clusters | grep -q "simple-cluster"; then
    print_status "Deleting kind cluster..."
    kind delete cluster --name simple-cluster
else
    print_warning "Kind cluster 'simple-cluster' not found"
fi

# Remove Docker images
if command_exists docker; then
    print_status "Removing Docker images..."
    docker rmi simple-app:latest 2>/dev/null || true
    docker rmi student-tracker:latest 2>/dev/null || true
    
    # Clean up unused images and containers
    print_status "Cleaning up unused Docker resources..."
    docker system prune -f
    docker volume prune -f
    docker network prune -f
else
    print_warning "Docker not found"
fi

# Remove any temporary files
print_status "Cleaning up temporary files..."
rm -f kind argocd-linux-amd64 kubectl 2>/dev/null || true

print_status "Cleanup completed!"