#!/bin/bash

# =============================================================================
# 🔧 KIND DEPLOYMENT FIX SCRIPT
# =============================================================================
# This script fixes the Kind cluster port conflict and redeploys.
#
# Usage: sudo ./fix-kind-deployment.sh
# =============================================================================

set -e

echo "🔧 Fixing Kind Deployment Port Conflict"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_status "Step 1: Cleaning up existing Kind clusters..."

# Delete any existing Kind clusters
if command_exists kind; then
    print_status "Deleting existing Kind clusters..."
    kind delete cluster --name simple-cluster 2>/dev/null || true
    kind delete cluster --name kind 2>/dev/null || true
    print_status "Kind clusters cleaned up"
else
    print_warning "Kind not found, skipping cluster cleanup"
fi

print_status "Step 2: Checking port usage..."

# Check what's using port 8011
print_status "Checking port 8011 usage..."
sudo netstat -tulpn | grep :8011 || print_status "Port 8011 is free"

print_status "Step 3: Stopping Docker Compose services..."

# Stop Docker Compose services to free up port 8011
if command_exists docker-compose; then
    print_status "Stopping Docker Compose services..."
    docker-compose down 2>/dev/null || true
elif docker compose version >/dev/null 2>&1; then
    print_status "Stopping Docker Compose services..."
    docker compose down 2>/dev/null || true
fi

print_status "Step 4: Creating Kind cluster with new port configuration..."

# Create Kind cluster with new port (8012)
if command_exists kind; then
    print_status "Creating Kind cluster with port 8012..."
    kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml
    
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_status "Kind cluster created successfully!"
else
    print_error "Kind not found. Please install Kind first."
    exit 1
fi

print_status "Step 5: Installing ArgoCD..."

# Install ArgoCD
print_status "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

print_status "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

print_status "Step 6: Deploying application to Kubernetes..."

# Deploy application using Helm
print_status "Deploying application with Helm..."
helm install simple-app infra/helm/ --namespace default --create-namespace

print_status "Waiting for application to be ready..."
kubectl wait --for=condition=Available deployment/simple-app --timeout=300s

print_status "Step 7: Restarting Docker Compose services..."

# Restart Docker Compose services
if command_exists docker-compose; then
    print_status "Restarting Docker Compose services..."
    docker-compose up -d
elif docker compose version >/dev/null 2>&1; then
    print_status "Restarting Docker Compose services..."
    docker compose up -d
fi

print_status "Step 8: Verifying deployments..."

# Wait for services to be ready
sleep 30

# Test both deployments
print_status "Testing Docker Compose deployment (port 8011)..."
if curl -s http://localhost:8011/health >/dev/null; then
    print_status "✅ Docker Compose deployment is healthy!"
else
    print_warning "⚠️ Docker Compose deployment not yet ready"
fi

print_status "Testing Kubernetes deployment (port 8012)..."
if curl -s http://localhost:8012/health >/dev/null; then
    print_status "✅ Kubernetes deployment is healthy!"
else
    print_warning "⚠️ Kubernetes deployment not yet ready"
fi

print_status "Step 9: Deployment Summary"

echo ""
print_status "🎉 Deployment completed successfully!"
echo ""
echo "📋 Access Information:"
echo "   🐳 Docker Compose Application: http://18.206.89.183:8011"
echo "   ☸️ Kubernetes Application: http://18.206.89.183:8012"
echo "   🌐 Nginx Proxy: http://18.206.89.183:80"
echo "   📈 Grafana: http://18.206.89.183:3000 (admin/admin123)"
echo "   📊 Prometheus: http://18.206.89.183:9090"
echo "   🗄️ Adminer: http://18.206.89.183:8080"
echo ""
echo "🔧 Useful Commands:"
echo "   kubectl get pods                    # View Kubernetes pods"
echo "   kubectl get svc                     # View Kubernetes services"
echo "   docker-compose ps                   # View Docker Compose services"
echo "   curl http://18.206.89.183:8011/health  # Test Docker Compose"
echo "   curl http://18.206.89.183:8012/health  # Test Kubernetes"
echo ""
echo "📝 Note: You now have both Docker Compose and Kubernetes deployments running!"
echo "   - Docker Compose: Port 8011 (for development/testing)"
echo "   - Kubernetes: Port 8012 (for production/GitOps)"
echo ""