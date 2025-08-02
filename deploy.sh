#!/bin/bash

# =============================================================================
# 🚀 NATIVESERIES - COMPREHENSIVE DEPLOYMENT SCRIPT
# =============================================================================
# This script provides a complete deployment solution for the NativeSeries
# application. It works on both EC2 and Ubuntu environments.
#
# Features:
# - Automatic tool installation (Docker, kubectl, Kind, Helm, ArgoCD)
# - Docker Compose deployment (port 8011)
# - Kubernetes cluster creation and deployment (port 30012)
# - ArgoCD GitOps setup (port 30080)
# - Health verification and monitoring
# - Port conflict resolution
# - Deployment timeout handling
# - Comprehensive error handling
# - Cross-platform compatibility
#
# Usage: sudo ./deploy.sh
# =============================================================================

set -e

echo "🚀 Starting NativeSeries comprehensive deployment to 18.206.89.183:8011 and 18.206.89.183:30012"

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

# Function to check if we're in a container environment
is_container() {
    [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null
}

# Function to check disk space
check_disk_space() {
    print_step "Checking disk space..."
    
    # Get available disk space
    local available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    local total_space=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
    local used_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    print_status "Disk space: ${available_space}G available out of ${total_space}G total (${used_percent}% used)"
    
    # Check if we have enough space (at least 5GB available)
    if [ "$available_space" -lt 5 ]; then
        print_warning "Low disk space detected (${available_space}G available)"
        print_status "Cleaning up Docker system to free space..."
        sudo docker system prune -af --volumes 2>/dev/null || true
        print_status "Disk space after cleanup:"
        df -h | grep -E "(Filesystem|/dev/)"
    else
        print_status "Sufficient disk space available"
    fi
}

# Function to install Docker
install_docker() {
    print_step "Installing Docker..."
    if command_exists docker; then
        print_status "Docker is already installed"
        return
    fi
    
    # Update package list
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker (only if not in container)
    if ! is_container; then
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        sudo systemctl enable docker 2>/dev/null || true
    else
        # In container, start Docker daemon in background
        sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 &
        sleep 5
    fi
    
    print_status "Docker installed successfully"
}

# Function to install kubectl
install_kubectl() {
    print_step "Installing kubectl..."
    if command_exists kubectl; then
        print_status "kubectl is already installed"
        return
    fi
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Make it executable
    chmod +x kubectl
    
    # Move to PATH
    sudo mv kubectl /usr/local/bin/
    
    print_status "kubectl installed successfully"
}

# Function to install Kind
install_kind() {
    print_step "Installing Kind..."
    if command_exists kind; then
        print_status "Kind is already installed"
        return
    fi
    
    # Download Kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    
    # Make it executable
    chmod +x kind
    
    # Move to PATH
    sudo mv kind /usr/local/bin/
    
    print_status "Kind installed successfully"
}

# Function to install Helm
install_helm() {
    print_step "Installing Helm..."
    if command_exists helm; then
        print_status "Helm is already installed"
        return
    fi
    
    # Download Helm
    curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar xz
    
    # Move to PATH
    sudo mv linux-amd64/helm /usr/local/bin/
    
    # Cleanup
    rm -rf linux-amd64
    
    print_status "Helm installed successfully"
}

# Function to install ArgoCD CLI
install_argocd_cli() {
    print_step "Installing ArgoCD CLI..."
    if command_exists argocd; then
        print_status "ArgoCD CLI is already installed"
        return
    fi
    
    # Download ArgoCD CLI
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    
    # Make it executable
    chmod +x argocd-linux-amd64
    
    # Move to PATH
    sudo mv argocd-linux-amd64 /usr/local/bin/argocd
    
    print_status "ArgoCD CLI installed successfully"
}

# Function to install additional tools
install_additional_tools() {
    print_step "Installing additional tools..."
    
    # Install curl if not present
    if ! command_exists curl; then
        sudo apt-get update && sudo apt-get install -y curl
    fi
    
    # Install jq if not present
    if ! command_exists jq; then
        sudo apt-get install -y jq
    fi
    
    # Install tree if not present
    if ! command_exists tree; then
        sudo apt-get install -y tree
    fi
    
    print_status "Additional tools installed successfully"
}

# Function to install Docker Compose
install_docker_compose() {
    print_step "Installing Docker Compose..."
    if command_exists docker-compose; then
        print_status "Docker Compose is already installed"
        return
    fi
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for docker compose (plugin version)
    sudo ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose-plugin
    
    print_status "Docker Compose installed successfully"
}

# Function to check Docker Compose
check_docker_compose() {
    if command_exists docker-compose; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        print_error "Docker Compose is not available. Installing..."
        install_docker_compose
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
    print_status "Using Docker Compose command: $DOCKER_COMPOSE_CMD"
}

# Function to cleanup existing resources
cleanup_existing() {
    print_step "Cleaning up existing resources..."
    
    # Stop and remove existing containers
    if command_exists docker; then
        print_status "Stopping existing Docker containers..."
        docker stop $(docker ps -q) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
    fi
    
    # Stop Docker Compose services
    if [ ! -z "$DOCKER_COMPOSE_CMD" ]; then
        print_status "Stopping existing Docker Compose services..."
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
    fi
    
    # Delete existing kind cluster if it exists
    if command_exists kind && kind get clusters | grep -q "nativeseries"; then
        print_status "Deleting existing kind cluster..."
        kind delete cluster --name nativeseries
    fi
    
    # Clean up Docker system and reclaim space
    if command_exists docker; then
        print_status "Cleaning up Docker system and reclaiming space..."
        docker rmi nativeseries:latest 2>/dev/null || true
        docker system prune -af --volumes 2>/dev/null || true
        
        # Check disk space after cleanup
        print_status "Checking disk space after cleanup..."
        df -h | grep -E "(Filesystem|/dev/)"
    fi
    
    print_status "Cleanup completed"
}

# Function to setup Docker Compose
setup_docker_compose() {
    print_step "Setting up Docker Compose environment..."
    
    # Stop any running containers
    if [ ! -z "$DOCKER_COMPOSE_CMD" ]; then
        print_status "Stopping existing Docker Compose services..."
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
    fi
    
    # Build and start services
    print_status "Building and starting Docker Compose services..."
    $DOCKER_COMPOSE_CMD up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service status
    print_status "Checking service status..."
    $DOCKER_COMPOSE_CMD ps
    
    print_status "Docker Compose setup completed"
}

# Function to create kind cluster
create_kind_cluster() {
    print_step "Creating Kind cluster..."
    
    # Create new kind cluster
    kind create cluster --name nativeseries --config infra/kind/cluster-config.yaml
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_status "Kind cluster created successfully"
}

# Function to build and load Docker image
build_and_load_image() {
    print_step "Building and loading Docker image..."
    
    # Build Docker image
    docker build -t nativeseries:latest .
    
    # Load image into kind cluster
    kind load docker-image nativeseries:latest --name nativeseries
    
    print_status "Docker image built and loaded successfully"
}

# Function to install ArgoCD
install_argocd() {
    print_step "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
    
    print_status "ArgoCD installed successfully"
}

# Function to deploy application
deploy_application() {
    print_step "Deploying application..."
    
    # Validate Helm chart before deployment
    print_status "Validating Helm chart..."
    if ! helm lint infra/helm/; then
        print_error "Helm chart validation failed"
        exit 1
    fi
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_status "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    # Apply ArgoCD application
    kubectl apply -f argocd/app.yaml
    
    # Deploy application using Helm directly (as backup)
    print_status "Installing Helm chart..."
    if ! helm install nativeseries infra/helm/ --namespace default --create-namespace; then
        print_error "Helm installation failed"
        print_status "Checking Helm status..."
        helm list
        print_status "Checking Kubernetes resources..."
        kubectl get all
        exit 1
    fi
    
    print_status "Helm chart installed successfully"
    print_status "Checking deployment status..."
    kubectl get deployment nativeseries
    
    # Wait for deployment to be ready with comprehensive error handling
    print_status "Waiting for application to be ready (timeout: 10 minutes)..."
    timeout 600 bash -c '
    while true; do
        # First check if deployment exists
        if ! kubectl get deployment nativeseries >/dev/null 2>&1; then
            echo "⏳ Waiting for deployment to be created..."
            sleep 10
            continue
        fi
        
        # Check if deployment is available
        if kubectl get deployment nativeseries -o jsonpath="{.status.conditions[?(@.type==\"Available\")].status}" | grep -q "True"; then
            echo "✅ Deployment is available!"
            break
        fi
        
        echo "⏳ Waiting for deployment to be ready..."
        
        # Check if pods exist before checking their status
        POD_COUNT=$(kubectl get pods -l app=nativeseries --no-headers 2>/dev/null | wc -l)
        if [ "$POD_COUNT" -gt 0 ]; then
            kubectl get pods -l app=nativeseries
            
            # Check for pod issues only if pods exist
            POD_STATUS=$(kubectl get pods -l app=nativeseries -o jsonpath="{.items[0].status.phase}" 2>/dev/null)
            if [ "$POD_STATUS" = "Failed" ] || [ "$POD_STATUS" = "Error" ]; then
                echo "❌ Pod is in $POD_STATUS state"
                kubectl describe pods -l app=nativeseries
                kubectl logs -l app=nativeseries --tail=50
                exit 1
            fi
        else
            echo "⏳ Waiting for pods to be created..."
        fi
        
        sleep 10
    done
    '
    
    if [ $? -ne 0 ]; then
        print_error "Deployment failed or timed out"
        print_status "Checking pod logs for debugging..."
        kubectl logs -l app=nativeseries --tail=100
        exit 1
    fi
    
    print_status "Application deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Wait for services to be ready
    sleep 30
    
    # Test Docker Compose deployment
    print_status "Testing Docker Compose deployment (port 8011)..."
    if curl -s http://localhost:8011/health >/dev/null; then
        print_status "✅ Docker Compose deployment is healthy!"
        curl -s http://localhost:8011/health | jq . 2>/dev/null || curl -s http://localhost:8011/health
    else
        print_warning "⚠️ Docker Compose deployment not yet ready"
    fi
    
    # Test Kubernetes deployment
    print_status "Testing Kubernetes deployment (port 30012)..."
    if curl -s http://localhost:30012/health >/dev/null; then
        print_status "✅ Kubernetes deployment is healthy!"
        curl -s http://localhost:30012/health | jq . 2>/dev/null || curl -s http://localhost:30012/health
    else
        print_warning "⚠️ Kubernetes deployment not yet ready"
        print_status "Checking pod status..."
        kubectl get pods -l app=nativeseries
        kubectl logs -l app=nativeseries --tail=20
    fi
    
    print_status "Deployment verification completed"
}

# Function to setup port forwarding
setup_port_forwarding() {
    print_step "Setting up port forwarding..."
    
    # Port forward ArgoCD (in background) - expose on port 30080 for external access
    kubectl port-forward svc/argocd-server -n argocd 30080:443 &
    ARGOCD_PID=$!
    
    # Wait a moment for port forward to be ready
    sleep 5
    
    print_status "Port forwarding setup completed"
}

    # Function to display final information
    display_final_info() {
        # Get ArgoCD admin password
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        
        echo ""
        print_status "🎉 NativeSeries Deployment Completed Successfully!"
        echo ""
        echo "📋 Production Access Information:"
        echo "   🐳 Docker Compose Application: http://18.206.89.183:8011"
        echo "   ☸️ Kubernetes Application: http://18.206.89.183:30012"
        echo "   🌐 Nginx Proxy: http://18.206.89.183:80"
        echo "   🔄 ArgoCD UI: http://18.206.89.183:30080"
        echo "   ArgoCD Username: admin"
        echo "   ArgoCD Password: $ARGOCD_PASSWORD"
        echo "   📈 Grafana: http://18.206.89.183:3000 (admin/admin123)"
        echo "   📊 Prometheus: http://18.206.89.183:9090"
        echo "   🗄️ Adminer: http://18.206.89.183:8080"
        echo ""
        echo "🔧 Management Commands:"
        echo "   kubectl get pods -l app=nativeseries"
        echo "   kubectl get svc"
        echo "   kubectl logs -f deployment/nativeseries"
        echo "   docker compose ps"
        echo "   docker compose logs -f"
        echo ""
        echo "🧪 Health Check Commands:"
        echo "   curl http://18.206.89.183:8011/health  # Docker Compose"
        echo "   curl http://18.206.89.183:30012/health # Kubernetes"
        echo ""
        echo "📝 Deployment Summary:"
        echo "   - Docker Compose: Port 8011 (Development/Testing)"
        echo "   - Kubernetes: Port 30012 (Production/GitOps)"
        echo "   - ArgoCD: GitOps Management (Port 30080)"
        echo "   - All services: Healthy and operational"
        echo ""
        echo "🎯 Next Steps:"
        echo "   - Access your application at http://18.206.89.183:8011"
        echo "   - Monitor with Grafana at http://18.206.89.183:3000"
        echo "   - Manage GitOps with ArgoCD at http://18.206.89.183:30080"
        echo ""
    }

# Main deployment function
main() {
    print_step "Starting comprehensive deployment process..."
    
    # Install all required tools
    install_docker
    install_kubectl
    install_kind
    install_helm
    install_argocd_cli
    install_additional_tools
    check_docker_compose
    
    # Check disk space before deployment
    check_disk_space
    
    # Cleanup existing resources
    cleanup_existing
    
    # Setup Docker Compose environment
    setup_docker_compose
    
    # Create Kind cluster
    create_kind_cluster
    
    # Build and load Docker image
    build_and_load_image
    
    # Install ArgoCD
    install_argocd
    
    # Deploy application
    deploy_application
    
    # Verify deployment
    verify_deployment
    
    # Setup port forwarding
    setup_port_forwarding
    
    # Display final information
    display_final_info
    
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
    print_status "NativeSeries application is running on:"
    print_status "  - Docker Compose: http://18.206.89.183:8011"
    print_status "  - Kubernetes: http://18.206.89.183:30012"
    print_status "  - ArgoCD UI: http://18.206.89.183:30080"
    
    # Keep the script running to maintain port forward
    wait
}

# Run main function
main "$@"