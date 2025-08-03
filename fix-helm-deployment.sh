#!/bin/bash

set -e

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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_status "🔧 Fixing Helm deployment issues..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_status "📦 Installing kubectl..."
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Verify installation
    kubectl version --client
    print_status "✅ kubectl installed successfully"
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    print_status "📦 Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    print_status "✅ Helm installed successfully"
fi

# Check cluster connectivity
print_status "🔍 Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "❌ Cannot connect to Kubernetes cluster"
    print_info "Please ensure you have:"
    print_info "1. A running Kubernetes cluster (minikube, kind, or cloud provider)"
    print_info "2. kubectl configured to connect to your cluster"
    print_info "3. Proper permissions to access the cluster"
    exit 1
fi

print_status "✅ Connected to Kubernetes cluster"

# Check namespace
print_status "🔍 Checking namespace..."
if ! kubectl get namespace student-tracker &> /dev/null; then
    print_status "📦 Creating namespace..."
    kubectl create namespace student-tracker
fi

# Check existing deployment
print_status "🔍 Checking existing deployment..."
if kubectl get deployment student-tracker -n student-tracker &> /dev/null; then
    print_warning "⚠️  Existing deployment found"
    print_status "🔄 Rolling back to previous version..."
    helm rollback student-tracker -n student-tracker
    sleep 30
fi

# Check pod status
print_status "📊 Current pod status:"
kubectl get pods -n student-tracker

# Check events
print_status "📋 Recent events:"
kubectl get events -n student-tracker --sort-by='.lastTimestamp' | tail -10

# Check if there are any issues with the image
print_status "🔍 Checking image pull issues..."
kubectl describe pods -n student-tracker | grep -A 10 -B 10 "Failed\|Error\|ImagePullBackOff"

# Fix ArgoCD configuration
print_status "🔧 Fixing ArgoCD configuration..."

# Check if ArgoCD is installed
if kubectl get namespace argocd &> /dev/null; then
    print_status "✅ ArgoCD namespace exists"
    
    # Get ArgoCD server address
    ARGOCD_SERVER=$(kubectl get service argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$ARGOCD_SERVER" ]; then
        ARGOCD_SERVER=$(kubectl get service argocd-server -n argocd -o jsonpath='{.spec.clusterIP}')
    fi
    
    if [ -n "$ARGOCD_SERVER" ]; then
        print_status "🌐 ArgoCD server found at: $ARGOCD_SERVER"
        
        # Configure ArgoCD CLI
        print_status "🔧 Configuring ArgoCD CLI..."
        
        # Get ArgoCD admin password
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        echo "ArgoCD admin password: $ARGOCD_PASSWORD"
        
        # Login to ArgoCD
        argocd login $ARGOCD_SERVER:80 --username admin --password "$ARGOCD_PASSWORD" --insecure
        
        # Check ArgoCD application
        print_status "📋 ArgoCD application status:"
        argocd app get student-tracker || echo "Application not found in ArgoCD"
        
    else
        print_warning "⚠️  ArgoCD server not accessible"
    fi
else
    print_warning "⚠️  ArgoCD namespace not found"
    print_info "To install ArgoCD, run:"
    print_info "kubectl create namespace argocd"
    print_info "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
fi

# Check Helm chart values
print_status "🔍 Checking Helm chart configuration..."
if [ -f "helm-chart/values.yaml" ]; then
    print_status "📋 Current Helm values:"
    cat helm-chart/values.yaml | grep -E "(image|repository|tag|port|service)"
fi

# Check if the image exists and is accessible
print_status "🔍 Checking Docker image accessibility..."
IMAGE_REPO=$(grep -A 5 "image:" helm-chart/values.yaml | grep "repository:" | awk '{print $2}' | tr -d '"')
IMAGE_TAG=$(grep -A 5 "image:" helm-chart/values.yaml | grep "tag:" | awk '{print $2}' | tr -d '"')

if [ -n "$IMAGE_REPO" ] && [ -n "$IMAGE_TAG" ]; then
    print_status "🔍 Checking image: $IMAGE_REPO:$IMAGE_TAG"
    
    # Try to pull the image locally to test
    if command -v docker &> /dev/null; then
        print_status "📥 Testing image pull..."
        docker pull "$IMAGE_REPO:$IMAGE_TAG" || print_warning "⚠️  Image pull failed"
    fi
fi

# Provide manual deployment option
print_status "🚀 Manual deployment options:"

echo ""
echo "Option 1: Deploy with Docker (Recommended for testing)"
echo "======================================================"
echo "cd /path/to/your/project"
echo "chmod +x deploy-ec2-user.sh"
echo "./deploy-ec2-user.sh"
echo ""

echo "Option 2: Fix Helm deployment"
echo "============================="
echo "1. Check image accessibility:"
echo "   docker pull $IMAGE_REPO:$IMAGE_TAG"
echo ""
echo "2. Update values.yaml with accessible image:"
echo "   app:"
echo "     image:"
echo "       repository: ghcr.io/bonaventuresimeon/NativeSeries/student-tracker"
echo "       tag: latest"
echo ""
echo "3. Redeploy Helm chart:"
echo "   helm upgrade --install student-tracker helm-chart/ -n student-tracker"
echo ""

echo "Option 3: Use local Docker deployment"
echo "===================================="
echo "sudo docker run -d \\"
echo "  --name student-tracker \\"
echo "  --restart unless-stopped \\"
echo "  -p 30011:8000 \\"
echo "  -e HOST=0.0.0.0 \\"
echo "  -e PORT=8000 \\"
echo "  student-tracker:latest"
echo ""

# Check current status
print_status "📊 Current deployment status:"
echo ""

echo "Kubernetes resources:"
kubectl get all -n student-tracker 2>/dev/null || echo "No resources found in namespace"

echo ""
echo "Docker containers:"
sudo docker ps --filter "name=student-tracker" 2>/dev/null || echo "No Docker containers found"

echo ""
print_status "🔧 Troubleshooting commands:"
echo ""
echo "1. Check pod logs:"
echo "   kubectl logs -f deployment/student-tracker -n student-tracker"
echo ""
echo "2. Check pod events:"
echo "   kubectl describe pod -n student-tracker"
echo ""
echo "3. Check service:"
echo "   kubectl get service -n student-tracker"
echo ""
echo "4. Test local deployment:"
echo "   curl http://localhost:30011/health"
echo ""

print_status "✅ Fix script completed!"
print_info "Choose one of the deployment options above based on your needs."