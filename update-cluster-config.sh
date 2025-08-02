#!/bin/bash

# =============================================================================
# 🔧 UPDATE CLUSTER CONFIGURATION FOR WORKER NODES
# =============================================================================
# This script updates the Kind cluster configuration to include worker nodes
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

# Function to check if kind is available
check_kind() {
    if ! command -v kind &> /dev/null; then
        print_error "kind is not installed"
        print_status "Installing kind..."
        
        # Install kind
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        
        print_status "kind installed successfully"
    else
        print_status "kind is available"
    fi
}

# Function to create new cluster configuration with worker nodes
create_worker_config() {
    print_step "Creating new cluster configuration with worker nodes..."
    
    # Create the new configuration file
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
    
    print_status "✅ New cluster configuration created: infra/kind/cluster-config-with-workers.yaml"
}

# Function to backup existing cluster
backup_cluster() {
    print_step "Backing up existing cluster configuration..."
    
    if [ -f infra/kind/cluster-config.yaml ]; then
        cp infra/kind/cluster-config.yaml infra/kind/cluster-config-backup.yaml
        print_status "✅ Backup created: infra/kind/cluster-config-backup.yaml"
    fi
}

# Function to recreate cluster with worker nodes
recreate_cluster() {
    print_step "Recreating cluster with worker nodes..."
    
    # Check if cluster exists
    if kind get clusters | grep -q nativeseries; then
        print_warning "Existing cluster found. This will delete the current cluster and all its data."
        read -p "Do you want to continue? (y/N): " confirm
        
        if [[ $confirm != [yY] ]]; then
            print_status "Cluster recreation cancelled"
            return 1
        fi
        
        print_status "Deleting existing cluster..."
        kind delete cluster --name nativeseries
    fi
    
    # Create new cluster with worker nodes
    print_status "Creating new cluster with worker nodes..."
    kind create cluster --name nativeseries --config infra/kind/cluster-config-with-workers.yaml
    
    print_status "✅ Cluster created successfully with worker nodes"
    
    # Show cluster info
    print_status "Cluster information:"
    kind cluster-info --name nativeseries
    
    print_status "Nodes in the cluster:"
    kubectl get nodes -o wide
}

# Function to deploy application to new cluster
deploy_application() {
    print_step "Deploying application to new cluster..."
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        print_status "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Navigate to helm directory
    cd infra/helm
    
    # Create namespace
    kubectl create namespace student-tracker --dry-run=client -o yaml | kubectl apply -f -
    
    # Install the Helm chart
    print_status "Installing NativeSeries Helm chart..."
    helm install nativeseries . -n student-tracker --wait --timeout=10m
    
    print_status "✅ Application deployed successfully"
    
    # Show deployment status
    print_status "Deployment status:"
    kubectl get deployments -n student-tracker
    kubectl get pods -n student-tracker
    kubectl get services -n student-tracker
}

# Function to verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nativeseries -n student-tracker --timeout=300s
    
    # Check pod status
    print_status "Pod status:"
    kubectl get pods -n student-tracker -o wide
    
    # Check service endpoints
    print_status "Service endpoints:"
    kubectl get endpoints -n student-tracker
    
    # Test connectivity
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
    
    print_status "✅ Deployment verification completed"
}

# Main execution
main() {
    echo "🔧 Update Cluster Configuration for Worker Nodes"
    echo "================================================"
    
    check_kind
    backup_cluster
    create_worker_config
    
    echo ""
    print_step "Choose an action:"
    echo "1. Recreate cluster with worker nodes"
    echo "2. Deploy application to new cluster"
    echo "3. Verify deployment"
    echo "4. All of the above"
    echo "5. Exit"
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            recreate_cluster
            ;;
        2)
            deploy_application
            ;;
        3)
            verify_deployment
            ;;
        4)
            recreate_cluster
            deploy_application
            verify_deployment
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
    
    print_status "Cluster configuration update completed"
    print_status "Your cluster now has worker nodes for better resource distribution"
}

# Run main function
main "$@"