#!/bin/bash

set -e

echo "🚀 Starting deployment to 18.206.89.183:8011"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    print_error "kind is not installed. Please install kind first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed. Please install helm first."
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    print_error "docker is not installed. Please install docker first."
    exit 1
fi

print_status "All required tools are installed"

# Delete existing cluster if it exists
if kind get clusters | grep -q "simple-cluster"; then
    print_status "Deleting existing kind cluster..."
    kind delete cluster --name simple-cluster
fi

# Create new kind cluster
print_status "Creating kind cluster..."
kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml

# Wait for cluster to be ready
print_status "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Build Docker image
print_status "Building Docker image..."
docker build -t simple-app:latest .

# Load image into kind cluster
print_status "Loading image into kind cluster..."
kind load docker-image simple-app:latest --name simple-cluster

# Install ArgoCD
print_status "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
print_status "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# Get ArgoCD admin password
print_status "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
print_status "ArgoCD admin password: $ARGOCD_PASSWORD"

# Port forward ArgoCD (in background)
print_status "Starting ArgoCD port forward..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
ARGOCD_PID=$!

# Wait a moment for port forward to be ready
sleep 5

# Apply ArgoCD application
print_status "Applying ArgoCD application..."
kubectl apply -f argocd/app.yaml

# Deploy application using Helm directly (as backup)
print_status "Deploying application with Helm..."
helm install simple-app infra/helm/ --namespace default --create-namespace

# Wait for deployment to be ready
print_status "Waiting for application to be ready..."
kubectl wait --for=condition=Available deployment/simple-app --timeout=300s

# Get service information
print_status "Getting service information..."
kubectl get svc simple-app

# Show access information
echo ""
print_status "🎉 Deployment completed successfully!"
echo ""
echo "📋 Access Information:"
echo "   Application URL: http://18.206.89.183:8011"
echo "   ArgoCD UI: https://localhost:8080"
echo "   ArgoCD Username: admin"
echo "   ArgoCD Password: $ARGOCD_PASSWORD"
echo ""
echo "🔧 Useful Commands:"
echo "   kubectl get pods"
echo "   kubectl get svc"
echo "   kubectl logs -f deployment/simple-app"
echo "   kubectl port-forward svc/simple-app 8011:8011"
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
print_status "The application will continue running on 18.206.89.183:8011"

# Keep the script running to maintain port forward
wait