#!/bin/bash

# Student Tracker Deployment Script
# Version: 3.0.0 - Unified Deployment Script
# Merged from: deploy-to-production.sh, get-docker.sh, scripts/deploy.sh, scripts/setup-kind.sh, scripts/install-all.sh, scripts/setup-argocd.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
APP_NAME="student-tracker"
NAMESPACE="student-tracker"
ARGOCD_NAMESPACE="argocd"
PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_IMAGE="${DOCKER_USERNAME:+$DOCKER_USERNAME/}student-tracker"
PYTHON_VERSION="3.11"
ARGOCD_VERSION="v2.9.3"
# Remove conflicting TARGET_IP and TARGET_PORT variables
# Use PRODUCTION_HOST and PRODUCTION_PORT consistently

# Output functions
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}🚀 $1${NC}"
    echo -e "${PURPLE}================================${NC}\n"
}

# Utility functions
command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command_exists yum; then
        echo "amazon"
    elif command_exists apt; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

# Docker installation
install_docker() {
    print_header "🐳 Installing Docker"
    
    if command_exists docker; then
        print_status "Docker already installed"
        docker --version
        return 0
    fi
    
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -a -G docker $USER
    rm get-docker.sh
    
    if command_exists systemctl; then
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    print_status "✅ Docker installed successfully"
    print_warning "You may need to log out and back in for Docker group membership to take effect"
}

# Tool installation
install_tools() {
    local os=$(detect_os)
    print_status "Installing tools for $os..."
    
    case $os in
        "amazon"|"rhel"|"centos")
            install_tools_amazon
            ;;
        "ubuntu"|"debian")
            install_tools_ubuntu
            ;;
        *)
            print_warning "Unknown OS, trying Ubuntu method..."
            install_tools_ubuntu
            ;;
    esac
}

install_tools_amazon() {
    print_status "Installing tools for Amazon Linux..."
    
    sudo yum update -y || print_warning "Failed to update system"
    sudo yum install -y curl wget jq git || {
        print_error "Failed to install basic dependencies"
        return 1
    }
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
    
    # Install Helm
    if ! command_exists helm; then
        print_status "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Install Docker
    if ! command_exists docker; then
        install_docker
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    # Install yq
    if ! command_exists yq; then
        print_status "Installing yq..."
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi
    
    print_status "✅ Tools installation completed"
}

install_tools_ubuntu() {
    print_status "Installing tools for Ubuntu/Debian..."
    
    sudo apt update -y || print_warning "Failed to update system"
    sudo apt install -y curl wget jq git apt-transport-https ca-certificates gnupg lsb-release || {
        print_error "Failed to install basic dependencies"
        return 1
    }
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
    
    # Install Helm
    if ! command_exists helm; then
        print_status "Installing Helm..."
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt update
        sudo apt install -y helm
    fi
    
    # Install Docker
    if ! command_exists docker; then
        install_docker
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    # Install yq
    if ! command_exists yq; then
        print_status "Installing yq..."
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi
    
    print_status "✅ Tools installation completed"
}

# Python environment setup
install_python_env() {
    print_header "🐍 Installing Python ${PYTHON_VERSION}"
    
    if command_exists python${PYTHON_VERSION}; then
        print_status "Python ${PYTHON_VERSION} already installed"
        python${PYTHON_VERSION} --version
    else
        case "$(detect_os)" in
            "amazon"|"rhel"|"centos")
                sudo yum update -y
                sudo yum install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip python${PYTHON_VERSION}-devel gcc curl wget git
                ;;
            "ubuntu"|"debian")
                sudo apt-get update
                sudo apt-get install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip python${PYTHON_VERSION}-venv python${PYTHON_VERSION}-dev build-essential curl wget git
                ;;
        esac
    fi
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python${PYTHON_VERSION} -m venv venv
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
    # Install requirements
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        pip install fastapi uvicorn pytest black flake8 httpx
    fi
    
    print_status "✅ Python environment ready"
}

# Kubernetes cluster setup
install_kind() {
    print_header "🔧 Installing Kind"
    
    if command_exists kind; then
        print_status "Kind already installed"
        kind version
        return 0
    fi
    
    print_status "Installing Kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    print_status "✅ Kind installed successfully"
    kind version
}

create_kind_cluster() {
    print_header "🚀 Creating Kind Cluster"
    
    CLUSTER_NAME="gitops-cluster"
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        print_warning "Cluster '$CLUSTER_NAME' already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    print_status "Creating Kind cluster with configuration..."
    
    # Create Kind cluster config
    mkdir -p infra/kind
    cat <<EOF > infra/kind/cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: gitops-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30011
    hostPort: ${PRODUCTION_PORT}
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF
    
    # Create cluster
    kind create cluster --config infra/kind/cluster-config.yaml
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Install ingress-nginx
    print_status "Installing ingress-nginx..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    
    # Create namespaces
    print_status "Creating namespaces..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "✅ Kind cluster created successfully"
    kubectl cluster-info
}

# ArgoCD installation
install_argocd() {
    print_header "🎯 Installing ArgoCD"
    
    # Create ArgoCD namespace
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    print_status "Installing ArgoCD ${ARGOCD_VERSION}..."
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n $ARGOCD_NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n $ARGOCD_NAMESPACE
    
    # Patch ArgoCD server to disable TLS (for IP-based access)
    print_status "Configuring ArgoCD server for IP access..."
    kubectl patch deployment argocd-server -n $ARGOCD_NAMESPACE -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json
    
    # Create NodePort service for ArgoCD (for external access)
    print_status "Creating NodePort service for ArgoCD..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - name: server
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF
    
    # Wait for the patched server to be ready
    print_status "Waiting for ArgoCD server to restart..."
    sleep 10
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
    
    # Get admin password
    print_status "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $ARGOCD_NAMESPACE -o jsonpath="{.data.password}" | base64 -d)
    echo "$ARGOCD_PASSWORD" > .argocd-password
    
    print_status "✅ ArgoCD installed successfully"
    print_status "ArgoCD admin password saved to .argocd-password"
    print_status "ArgoCD UI will be available at: http://localhost:8080"
    print_status "Username: admin"
    print_status "Password: $ARGOCD_PASSWORD"
}

# Docker image building
build_docker_image() {
    print_header "🐳 Building Docker Image"
    
    local image_name="$DOCKER_IMAGE:latest"
    
    if [ -z "$DOCKER_USERNAME" ]; then
        print_warning "DOCKER_USERNAME not set, using local image name"
        image_name="student-tracker:latest"
    fi
    
    # Try to start Docker daemon if not running
    if ! docker info >/dev/null 2>&1; then
        print_status "Starting Docker daemon..."
        
        # Check if we're in a container environment
        if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
            print_warning "Running in container environment - Docker daemon may not be available"
            print_status "Docker build will be skipped in container environment"
            return 1
        fi
        
        if command_exists systemctl; then
            sudo systemctl start docker || {
                print_warning "Failed to start Docker daemon with systemctl"
            }
        fi
        
        # Wait a moment for Docker to start
        sleep 3
        
        # Try again
        if ! docker info >/dev/null 2>&1; then
            print_warning "Docker daemon still not accessible"
            print_status "You may need to:"
            print_status "1. Log out and back in (for group membership)"
            print_status "2. Start Docker manually: sudo systemctl start docker"
            print_status "3. Or run: newgrp docker"
            return 1
        fi
    fi
    
    # Build the image
    if docker build -t "$image_name" .; then
        print_status "✅ Docker image built successfully: $image_name"
        echo "$image_name" > .docker_image_name
        
        # Load image into Kind cluster if available
        if command_exists kind && kind get clusters | grep -q "gitops-cluster"; then
            print_status "Loading image into Kind cluster..."
            kind load docker-image "$image_name" --name gitops-cluster
        fi
    else
        print_error "Failed to build Docker image"
        return 1
    fi
}

# Production deployment
deploy_production() {
    print_header "🚀 Deploying to Production"
    
    PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
    
    print_status "Deploying Student Tracker to Production"
    print_status "Production URL: ${PRODUCTION_URL}"
    
    # Check if Docker is available
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    # Build the Docker image
    print_status "Building Docker image..."
    docker build -t ${APP_NAME}:latest .
    
    # Check if the image was built successfully
    if [ $? -eq 0 ]; then
        print_status "✅ Docker image built successfully"
    else
        print_error "❌ Failed to build Docker image"
        exit 1
    fi
    
    # Run the application container
    print_status "Starting application container..."
    docker run -d \
        --name ${APP_NAME} \
        --restart unless-stopped \
        -p ${PRODUCTION_PORT}:8000 \
        -e HOST=0.0.0.0 \
        -e PORT=8000 \
        ${APP_NAME}:latest
    
    # Check if container started successfully
    if [ $? -eq 0 ]; then
        print_status "✅ Application container started successfully"
    else
        print_error "❌ Failed to start application container"
        exit 1
    fi
    
    # Wait a moment for the application to start
    print_status "Waiting for application to start..."
    sleep 10
    
    # Test the application
    print_status "Testing application health..."
    if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
        print_status "✅ Application is healthy and responding"
    else
        print_warning "⚠️  Health check failed, but container is running"
    fi
    
    # Show deployment information
    echo ""
    print_status "🎉 Deployment Complete!"
    echo ""
    echo "📋 Deployment Information:"
    echo "   Application: ${APP_NAME}"
    echo "   Production URL: ${PRODUCTION_URL}"
    echo "   API Documentation: ${PRODUCTION_URL}/docs"
    echo "   Health Check: ${PRODUCTION_URL}/health"
    echo "   Metrics: ${PRODUCTION_URL}/metrics"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs: docker logs -f ${APP_NAME}"
    echo "   Stop app: docker stop ${APP_NAME}"
    echo "   Restart app: docker restart ${APP_NAME}"
    echo "   Remove app: docker rm -f ${APP_NAME}"
    echo ""
    print_status "🌐 Your Student Tracker application is now live at: ${PRODUCTION_URL}"
}

# Validation report
create_validation_report() {
    print_status "Creating validation report..."
    
    local report_file="deployment_validation_report.txt"
    
    {
        echo "=== Deployment Validation Report ==="
        echo "Date: $(date)"
        echo "OS: $(detect_os)"
        echo ""
        
        echo "=== Project Structure ==="
        for file in "app/main.py" "helm-chart/Chart.yaml" "argocd/application.yaml" "Dockerfile" "requirements.txt"; do
            if [ -f "$file" ]; then
                echo "✅ $file - Found"
            else
                echo "❌ $file - Missing"
            fi
        done
        echo ""
        
        echo "=== Tools Status ==="
        local tools=("kubectl" "helm" "docker" "argocd" "jq" "yq")
        for tool in "${tools[@]}"; do
            if command_exists "$tool"; then
                echo "✅ $tool - Installed"
            else
                echo "❌ $tool - Not installed"
            fi
        done
        echo ""
        
        echo "=== Environment ==="
        echo "Production Host: $PRODUCTION_HOST"
        echo "Production Port: $PRODUCTION_PORT"
        echo "Docker Username: ${DOCKER_USERNAME:-Not set}"
        echo ""
        
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "=== Kubernetes Cluster ==="
            echo "✅ Cluster available"
            kubectl cluster-info 2>/dev/null || echo "⚠️ Cluster info not available"
        else
            echo "=== Kubernetes Cluster ==="
            echo "❌ No cluster available"
        fi
        
        echo ""
        echo "=== Recommendations ==="
        if ! command_exists docker; then
            echo "• Install Docker for container builds"
        fi
        if ! kubectl cluster-info >/dev/null 2>&1; then
            echo "• Set up a Kubernetes cluster for full deployment"
        fi
        if [ -z "${DOCKER_USERNAME:-}" ]; then
            echo "• Set DOCKER_USERNAME environment variable for Docker Hub pushes"
        fi
    } > "$report_file"
    
    print_status "✅ Validation report created: $report_file"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --setup-cluster      Create Kubernetes cluster and install ArgoCD"
    echo "  --install-tools      Install all required tools (Docker, kubectl, Helm, etc.)"
    echo "  --install-python     Install Python and setup virtual environment"
    echo "  --build-image        Build Docker image"
    echo "  --deploy-prod        Deploy to production server"
    echo "  --argocd-portforward Start ArgoCD port-forward for UI access"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_USERNAME      Your Docker Hub username"
    echo "  PRODUCTION_HOST      Production host IP (default: 18.206.89.183)"
    echo "  PRODUCTION_PORT      Production port (default: 30011)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Standard deployment"
    echo "  $0 --setup-cluster              # Create cluster and install ArgoCD"
    echo "  $0 --install-tools              # Install all tools"
    echo "  $0 --deploy-prod                # Deploy to production"
    echo "  DOCKER_USERNAME=user $0         # Deploy with Docker Hub"
    echo ""
}

# Main function
main() {
    # Parse command line arguments
    local SETUP_CLUSTER=false
    local INSTALL_TOOLS=false
    local INSTALL_PYTHON=false
    local BUILD_IMAGE=false
    local DEPLOY_PROD=false
    local ARGOCD_PORTFORWARD=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-cluster)
                SETUP_CLUSTER=true
                shift
                ;;
            --install-tools)
                INSTALL_TOOLS=true
                shift
                ;;
            --install-python)
                INSTALL_PYTHON=true
                shift
                ;;
            --build-image)
                BUILD_IMAGE=true
                shift
                ;;
            --deploy-prod)
                DEPLOY_PROD=true
                shift
                ;;
            --argocd-portforward)
                ARGOCD_PORTFORWARD=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_header "🚀 Student Tracker Deployment Script"
    
    # Get script directory and change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
    cd "$PROJECT_ROOT"
    
    # Handle ArgoCD port-forward
    if [[ "$ARGOCD_PORTFORWARD" == "true" ]]; then
        if kubectl get namespace argocd >/dev/null 2>&1; then
            print_status "Starting ArgoCD port-forward..."
            print_status "ArgoCD UI will be available at: http://localhost:8080"
            print_status "Press Ctrl+C to stop the port-forward"
            kubectl port-forward svc/argocd-server -n argocd 8080:443
        else
            print_error "ArgoCD not installed"
            exit 1
        fi
        exit 0
    fi
    
    # Install tools if requested
    if [[ "$INSTALL_TOOLS" == "true" ]]; then
        install_tools
    fi
    
    # Install Python if requested
    if [[ "$INSTALL_PYTHON" == "true" ]]; then
        install_python_env
    fi
    
    # Setup cluster if requested
    if [[ "$SETUP_CLUSTER" == "true" ]]; then
        install_kind
        create_kind_cluster
        install_argocd
    fi
    
    # Build image if requested
    if [[ "$BUILD_IMAGE" == "true" ]]; then
        build_docker_image
    fi
    
    # Deploy to production if requested
    if [[ "$DEPLOY_PROD" == "true" ]]; then
        deploy_production
    fi
    
    # If no specific options, do standard deployment
    if [[ "$SETUP_CLUSTER" == "false" && "$INSTALL_TOOLS" == "false" && "$INSTALL_PYTHON" == "false" && "$BUILD_IMAGE" == "false" && "$DEPLOY_PROD" == "false" ]]; then
        print_status "Performing standard deployment..."
        
        # Install tools if needed
        if ! command_exists kubectl || ! command_exists helm || ! command_exists docker; then
            install_tools
        fi
        
        # Setup Python environment
        install_python_env
        
        # Try to build Docker image
        build_docker_image || print_warning "Docker build failed, but continuing..."
        
        # Deploy to production
        deploy_production
    fi
    
    # Create validation report
    create_validation_report
    
    print_status "✅ Deployment completed successfully!"
}

# Run main function
main "$@"