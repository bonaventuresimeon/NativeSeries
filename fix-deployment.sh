#!/bin/bash

# =============================================================================
# 🔧 NATIVESERIES - DEPLOYMENT FIX SCRIPT
# =============================================================================
# This script helps troubleshoot and fix Kubernetes deployment issues
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        print_status "Installing kubectl..."
        
        # Install kubectl
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        
        print_status "kubectl installed successfully"
    else
        print_status "kubectl is available"
    fi
}

# Function to check cluster status
check_cluster() {
    print_step "Checking Kubernetes cluster status..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please ensure your cluster is running and accessible"
        return 1
    fi
    
    print_status "Cluster is accessible"
    kubectl cluster-info
    
    print_status "Checking nodes..."
    kubectl get nodes
    
    print_status "Checking namespaces..."
    kubectl get namespaces
}

# Function to check existing deployments
check_deployments() {
    print_step "Checking existing deployments..."
    
    print_status "Checking all namespaces for deployments..."
    kubectl get deployments --all-namespaces
    
    print_status "Checking student-tracker namespace specifically..."
    if kubectl get namespace student-tracker &> /dev/null; then
        kubectl get deployments -n student-tracker
        kubectl get pods -n student-tracker
        kubectl get services -n student-tracker
    else
        print_warning "student-tracker namespace does not exist"
    fi
    
    print_status "Checking for any nativeseries resources..."
    kubectl get all --all-namespaces | grep nativeseries || print_warning "No nativeseries resources found"
}

# Function to check Helm releases
check_helm() {
    print_step "Checking Helm releases..."
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        print_status "Installing Helm..."
        
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        
        print_status "Helm installed successfully"
    else
        print_status "Helm is available"
    fi
    
    print_status "Checking Helm releases..."
    helm list --all-namespaces
}

# Function to redeploy the application
redeploy_application() {
    print_step "Redeploying NativeSeries application..."
    
    # Navigate to the helm directory
    cd infra/helm
    
    # Uninstall existing release if it exists
    if helm list -n student-tracker | grep -q nativeseries; then
        print_status "Uninstalling existing nativeseries release..."
        helm uninstall nativeseries -n student-tracker
    fi
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace student-tracker &> /dev/null; then
        print_status "Creating student-tracker namespace..."
        kubectl create namespace student-tracker
    fi
    
    # Install the Helm chart
    print_status "Installing NativeSeries Helm chart..."
    helm install nativeseries . -n student-tracker --wait --timeout=10m
    
    print_status "Helm chart installed successfully"
    
    # Check deployment status
    print_status "Checking deployment status..."
    kubectl get deployments -n student-tracker
    kubectl get pods -n student-tracker
    kubectl get services -n student-tracker
}

# Function to check application health
check_application_health() {
    print_step "Checking application health..."
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nativeseries -n student-tracker --timeout=300s
    
    # Check pod logs
    print_status "Checking pod logs..."
    kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker --tail=50
    
    # Check service endpoints
    print_status "Checking service endpoints..."
    kubectl get endpoints -n student-tracker
    
    # Test service connectivity
    print_status "Testing service connectivity..."
    kubectl port-forward service/nativeseries 30012:80 -n student-tracker &
    PF_PID=$!
    
    sleep 5
    
    if curl -f http://localhost:30012/health &> /dev/null; then
        print_status "✅ Application is healthy and responding"
    else
        print_warning "⚠️ Application is not responding on health endpoint"
    fi
    
    kill $PF_PID 2>/dev/null || true
}

# Function to update cluster configuration for worker nodes
update_cluster_config() {
    print_step "Updating cluster configuration for worker nodes..."
    
    # Check current cluster configuration
    print_status "Current cluster configuration:"
    kubectl get nodes -o wide
    
    # Create a new cluster configuration with worker nodes
    cat > infra/kind/cluster-config-with-workers.yaml << 'EOF'
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: nativeseries
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30012
    hostPort: 30012
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: KubeletConfiguration
    failSwapOn: false
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    failSwapOn: false
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    failSwapOn: false
EOF
    
    print_status "New cluster configuration created with 2 worker nodes"
    print_warning "To apply this configuration, you'll need to recreate the cluster:"
    print_status "1. kind delete cluster --name nativeseries"
    print_status "2. kind create cluster --name nativeseries --config infra/kind/cluster-config-with-workers.yaml"
    print_status "3. Run this script again to redeploy the application"
}

# Main execution
main() {
    echo "🔧 NativeSeries Deployment Fix Script"
    echo "====================================="
    
    check_kubectl
    check_cluster
    check_deployments
    check_helm
    
    echo ""
    print_step "Choose an action:"
    echo "1. Redeploy the application"
    echo "2. Update cluster configuration for worker nodes"
    echo "3. Check application health"
    echo "4. All of the above"
    echo "5. Exit"
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            redeploy_application
            ;;
        2)
            update_cluster_config
            ;;
        3)
            check_application_health
            ;;
        4)
            redeploy_application
            update_cluster_config
            check_application_health
            ;;
        5)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    print_status "Fix script completed"
}

# Run main function
main "$@"