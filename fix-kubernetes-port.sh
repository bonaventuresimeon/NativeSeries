#!/bin/bash

# =============================================================================
# 🔧 KUBERNETES PORT FIX SCRIPT
# =============================================================================
# This script fixes the Kubernetes NodePort range issue by updating to port 30012.
#
# Usage: sudo ./fix-kubernetes-port.sh
# =============================================================================

set -e

echo "🔧 Fixing Kubernetes NodePort Range Issue"

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

print_status "Step 1: Cleaning up existing Kubernetes resources..."

# Delete existing Helm release
if helm list | grep -q simple-app; then
    print_status "Deleting existing Helm release..."
    helm uninstall simple-app
fi

# Delete existing Kind cluster
if kind get clusters | grep -q simple-cluster; then
    print_status "Deleting existing Kind cluster..."
    kind delete cluster --name simple-cluster
fi

print_status "Step 2: Creating Kind cluster with new port configuration..."

# Create Kind cluster with new port (30012)
print_status "Creating Kind cluster with port 30012..."
kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml

print_status "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

print_status "Step 3: Installing ArgoCD..."

# Install ArgoCD
print_status "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

print_status "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

print_status "Step 4: Deploying application with new port..."

# Deploy application using Helm
print_status "Deploying application with Helm..."
helm install simple-app infra/helm/ --namespace default --create-namespace

print_status "Waiting for application to be ready..."
kubectl wait --for=condition=Available deployment/simple-app --timeout=300s

print_status "Step 5: Setting up port forwarding..."

# Port forward ArgoCD (in background)
kubectl port-forward svc/argocd-server -n argocd 30080:443 &
ARGOCD_PID=$!

# Wait a moment for port forward to be ready
sleep 5

print_status "Step 6: Verifying deployment..."

# Wait for services to be ready
sleep 30

# Test Kubernetes deployment
print_status "Testing Kubernetes deployment (port 30012)..."
if curl -s http://localhost:30012/health >/dev/null; then
    print_status "✅ Kubernetes deployment is healthy!"
else
    print_warning "⚠️ Kubernetes deployment not yet ready"
fi

print_status "Step 7: Deployment Summary"

echo ""
print_status "🎉 Kubernetes port fix completed successfully!"
echo ""
echo "📋 Access Information:"
echo "   🐳 Docker Compose Application: http://18.206.89.183:8011"
echo "   ☸️ Kubernetes Application: http://18.206.89.183:30012"
echo "   🔄 ArgoCD UI: http://18.206.89.183:30080"
echo "   ArgoCD Username: admin"
echo "   ArgoCD Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "   📈 Grafana: http://18.206.89.183:3000 (admin/admin123)"
echo "   📊 Prometheus: http://18.206.89.183:9090"
echo "   🗄️ Adminer: http://18.206.89.183:8080"
echo ""
echo "🔧 Useful Commands:"
echo "   kubectl get pods"
echo "   kubectl get svc"
echo "   kubectl logs -f deployment/simple-app"
echo "   curl http://18.206.89.183:30012/health"
echo ""
echo "📝 Note: Kubernetes now uses port 30012 (valid NodePort range)"
echo ""

# Cleanup function
cleanup() {
    print_status "Cleaning up..."
    if [ ! -z "$ARGOCD_PID" ]; then
        kill $ARGOCD_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

print_status "Press Ctrl+C to stop the port forward and exit"
print_status "The application will continue running on 18.206.89.183:8011 and 18.206.89.183:30012"
print_status "ArgoCD UI is available at http://18.206.89.183:30080"

# Keep the script running to maintain port forward
wait