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

# Delete kind cluster if it exists
if kind get clusters | grep -q "simple-cluster"; then
    print_status "Deleting kind cluster..."
    kind delete cluster --name simple-cluster
else
    print_warning "Kind cluster 'simple-cluster' not found"
fi

# Remove Docker image if it exists
if docker images | grep -q "simple-app"; then
    print_status "Removing Docker image..."
    docker rmi simple-app:latest 2>/dev/null || true
else
    print_warning "Docker image 'simple-app:latest' not found"
fi

print_status "Cleanup completed!"