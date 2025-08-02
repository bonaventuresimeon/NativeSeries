#!/bin/bash

# =============================================================================
# 🔧 DEPLOYMENT TIMEOUT FIX SCRIPT
# =============================================================================
# This script fixes the Kubernetes deployment timeout issue.
#
# Usage: sudo ./fix-deployment-timeout.sh
# =============================================================================

set -e

echo "🔧 Fixing Kubernetes Deployment Timeout Issue"

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

print_status "Step 1: Checking current deployment status..."

# Check if deployment exists
if kubectl get deployment simple-app 2>/dev/null; then
    print_status "Found existing deployment, checking status..."
    kubectl get pods -l app=simple-app
    kubectl describe deployment simple-app
else
    print_status "No existing deployment found"
fi

print_status "Step 2: Cleaning up existing resources..."

# Delete existing Helm release
if helm list | grep -q simple-app; then
    print_status "Deleting existing Helm release..."
    helm uninstall simple-app
fi

# Delete existing ArgoCD application
if kubectl get application student-tracker -n argocd 2>/dev/null; then
    print_status "Deleting existing ArgoCD application..."
    kubectl delete application student-tracker -n argocd
fi

print_status "Step 3: Building and loading Docker image..."

# Build the Docker image
print_status "Building Docker image..."
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .

# Load image into Kind cluster
print_status "Loading image into Kind cluster..."
kind load docker-image ghcr.io/bonaventuresimeon/nativeseries:latest --name simple-cluster

print_status "Step 4: Deploying application with updated configuration..."

# Deploy application using Helm
print_status "Deploying application with Helm..."
helm install simple-app infra/helm/ --namespace default --create-namespace

print_status "Step 5: Monitoring deployment..."

# Wait for deployment with increased timeout and better error handling
print_status "Waiting for deployment to be ready (timeout: 10 minutes)..."
timeout 600 bash -c '
while true; do
    if kubectl get deployment simple-app -o jsonpath="{.status.conditions[?(@.type==\"Available\")].status}" | grep -q "True"; then
        echo "✅ Deployment is available!"
        break
    fi
    
    echo "⏳ Waiting for deployment to be ready..."
    kubectl get pods -l app=simple-app
    
    # Check for pod issues
    POD_STATUS=$(kubectl get pods -l app=simple-app -o jsonpath="{.items[0].status.phase}")
    if [ "$POD_STATUS" = "Failed" ] || [ "$POD_STATUS" = "Error" ]; then
        echo "❌ Pod is in $POD_STATUS state"
        kubectl describe pods -l app=simple-app
        kubectl logs -l app=simple-app --tail=50
        exit 1
    fi
    
    sleep 10
done
'

if [ $? -eq 0 ]; then
    print_status "✅ Deployment successful!"
else
    print_error "❌ Deployment failed or timed out"
    print_status "Checking pod logs for debugging..."
    kubectl logs -l app=simple-app --tail=100
    exit 1
fi

print_status "Step 6: Setting up ArgoCD application..."

# Create ArgoCD application
print_status "Creating ArgoCD application..."
kubectl apply -f argocd/app.yaml

print_status "Step 7: Setting up port forwarding..."

# Port forward ArgoCD (in background)
kubectl port-forward svc/argocd-server -n argocd 30080:443 &
ARGOCD_PID=$!

# Wait a moment for port forward to be ready
sleep 5

print_status "Step 8: Verifying deployment..."

# Wait for services to be ready
sleep 30

# Test Kubernetes deployment
print_status "Testing Kubernetes deployment (port 30012)..."
if curl -s http://localhost:30012/health >/dev/null; then
    print_status "✅ Kubernetes deployment is healthy!"
    curl -s http://localhost:30012/health | jq . 2>/dev/null || curl -s http://localhost:30012/health
else
    print_warning "⚠️ Kubernetes deployment not yet ready"
    print_status "Checking pod status..."
    kubectl get pods -l app=simple-app
    kubectl logs -l app=simple-app --tail=20
fi

print_status "Step 9: Deployment Summary"

echo ""
print_status "🎉 Deployment timeout fix completed!"
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
echo "📝 Note: Kubernetes deployment now uses simplified configuration"
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