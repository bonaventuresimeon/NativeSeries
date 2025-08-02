#!/bin/bash

set -e

echo "🚀 Starting simple deployment to 18.206.89.183:8011"

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

# Function to install tools
install_tools() {
    print_step "Installing required tools..."
    
    # Install basic tools
    sudo apt-get update
    sudo apt-get install -y curl wget jq tree
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    # Install Kind
    if ! command_exists kind; then
        print_status "Installing Kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x kind
        sudo mv kind /usr/local/bin/
    fi
    
    # Install Helm
    if ! command_exists helm; then
        print_status "Installing Helm..."
        curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar xz
        sudo mv linux-amd64/helm /usr/local/bin/
        rm -rf linux-amd64
    fi
    
    print_status "All tools installed successfully"
}

# Function to start Docker daemon
start_docker() {
    print_step "Starting Docker daemon..."
    
    # Start Docker daemon in background
    sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 &
    DOCKER_PID=$!
    
    # Wait for Docker to be ready
    print_status "Waiting for Docker daemon to be ready..."
    sleep 10
    
    # Test Docker
    if docker ps >/dev/null 2>&1; then
        print_status "Docker daemon started successfully"
    else
        print_error "Failed to start Docker daemon"
        exit 1
    fi
}

# Function to cleanup existing resources
cleanup_existing() {
    print_step "Cleaning up existing resources..."
    
    # Stop and remove existing containers
    if command_exists docker && docker ps >/dev/null 2>&1; then
        print_status "Stopping existing Docker containers..."
        docker stop $(docker ps -q) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
    fi
    
    # Delete existing kind cluster if it exists
    if command_exists kind && kind get clusters | grep -q "simple-cluster" 2>/dev/null; then
        print_status "Deleting existing kind cluster..."
        kind delete cluster --name simple-cluster
    fi
    
    # Remove Docker images
    if command_exists docker && docker ps >/dev/null 2>&1; then
        print_status "Removing old Docker images..."
        docker rmi simple-app:latest 2>/dev/null || true
        docker system prune -f
    fi
    
    print_status "Cleanup completed"
}

# Function to setup Docker Compose
setup_docker_compose() {
    print_step "Setting up Docker Compose environment..."
    
    # Stop any running containers
    if command_exists docker; then
        print_status "Stopping existing Docker Compose services..."
        docker compose down -v 2>/dev/null || true
    fi
    
    # Build and start services
    print_status "Building and starting Docker Compose services..."
    docker compose up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service status
    print_status "Checking service status..."
    docker compose ps
    
    print_status "Docker Compose setup completed"
}

# Function to create kind cluster
create_kind_cluster() {
    print_step "Creating Kind cluster..."
    
    # Create new kind cluster
    kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_status "Kind cluster created successfully"
}

# Function to build and load Docker image
build_and_load_image() {
    print_step "Building and loading Docker image..."
    
    # Build Docker image
    docker build -t simple-app:latest .
    
    # Load image into kind cluster
    kind load docker-image simple-app:latest --name simple-cluster
    
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
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_status "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    # Apply ArgoCD application
    kubectl apply -f argocd/app.yaml
    
    # Deploy application using Helm directly (as backup)
    helm install simple-app infra/helm/ --namespace default --create-namespace
    
    # Wait for deployment to be ready
    print_status "Waiting for application to be ready..."
    kubectl wait --for=condition=Available deployment/simple-app --timeout=300s
    
    print_status "Application deployed successfully"
}

# Function to display final information
display_final_info() {
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo ""
    print_status "🎉 Deployment completed successfully!"
    echo ""
    echo "📋 Access Information:"
    echo "   Application URL: http://18.206.89.183:8011"
    echo "   Docker Compose: http://18.206.89.183:80"
    echo "   ArgoCD UI: https://localhost:8080 (after port forward)"
    echo "   ArgoCD Username: admin"
    echo "   ArgoCD Password: $ARGOCD_PASSWORD"
    echo "   Grafana: http://18.206.89.183:3000 (admin/admin123)"
    echo "   Prometheus: http://18.206.89.183:9090"
    echo "   Adminer: http://18.206.89.183:8080"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   kubectl get pods"
    echo "   kubectl get svc"
    echo "   kubectl logs -f deployment/simple-app"
    echo "   docker-compose ps"
    echo "   docker-compose logs -f"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo ""
}

# Main deployment function
main() {
    print_step "Starting simple deployment process..."
    
    # Install all required tools
    install_tools
    
    # Start Docker daemon
    start_docker
    
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
    
    # Display final information
    display_final_info
    
    print_status "Deployment completed! Your application is now running."
    print_status "Access it at: http://18.206.89.183:8011"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up..."
    if [ ! -z "$DOCKER_PID" ]; then
        kill $DOCKER_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Run main function
main "$@"