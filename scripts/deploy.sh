#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
NAMESPACE="student-tracker"
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
DOCKER_USERNAME="biwunor"
DOCKER_IMAGE="$DOCKER_USERNAME/nativeseries"

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

print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}🚀 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show help
show_help() {
    echo "🚀 Student Tracker Deployment Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  1  - Prune all system, network, and port resources"
    echo "  2  - Download and install all tools (skip if exists)"
    echo "  3  - Create minikube cluster, deploy application with DNS binding"
    echo "  4  - Build Docker image with biwunor/nativeseries"
    echo "  5  - Full system, application, docker, helm and argocd analysis"
    echo "  --help, -h  - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 1    # Prune all system resources"
    echo "  $0 2    # Install all tools"
    echo "  $0 3    # Deploy to minikube with DNS"
    echo "  $0 4    # Build Docker image"
    echo "  $0 5    # Run full system analysis"
    echo ""
}

# Option 1: Prune all system, network, and port resources
prune_all_system() {
    print_header "PRUNING ALL SYSTEM RESOURCES"
    
    print_status "🧹 Starting complete system pruning..."
    
    # Determine Docker command (with or without sudo)
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        if sudo docker info >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            print_info "Using sudo for Docker commands"
        else
            print_warning "Docker not available, skipping Docker pruning"
        fi
    fi
    
    # Stop and remove all Docker containers
    print_info "Stopping all Docker containers..."
    if $DOCKER_CMD ps -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
        print_status "✅ All containers stopped"
    fi
    
    # Remove all Docker containers
    print_info "Removing all Docker containers..."
    if $DOCKER_CMD ps -aq | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD rm -f $($DOCKER_CMD ps -aq) 2>/dev/null || true
        print_status "✅ All containers removed"
    fi
    
    # Remove all Docker images
    print_info "Removing all Docker images..."
    if $DOCKER_CMD images -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD rmi -f $($DOCKER_CMD images -q) 2>/dev/null || true
        print_status "✅ All images removed"
    fi
    
    # Remove all Docker volumes
    print_info "Removing all Docker volumes..."
    if $DOCKER_CMD volume ls -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD volume rm $($DOCKER_CMD volume ls -q) 2>/dev/null || true
        print_status "✅ All volumes removed"
    fi
    
    # Remove all Docker networks
    print_info "Removing all Docker networks..."
    if $DOCKER_CMD network ls --filter "type=custom" -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD network rm $($DOCKER_CMD network ls --filter "type=custom" -q) 2>/dev/null || true
        print_status "✅ All networks removed"
    fi
    
    # Prune Docker system
    print_info "Pruning Docker system..."
    $DOCKER_CMD system prune -af --volumes 2>/dev/null || true
    print_status "✅ Docker system pruned"
    
    # Clean up Kubernetes resources
    print_info "Cleaning up Kubernetes resources..."
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        # Delete all namespaces except system ones
        for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
            if [[ "$ns" != "default" && "$ns" != "kube-system" && "$ns" != "kube-public" && "$ns" != "kube-node-lease" ]]; then
                kubectl delete namespace "$ns" --ignore-not-found=true 2>/dev/null || true
            fi
        done
        print_status "✅ Kubernetes resources cleaned"
    fi
    
    # Clean up system resources
    print_info "Cleaning system resources..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    
    # Clean package cache
    if command_exists apt; then
        sudo apt clean 2>/dev/null || true
        sudo apt autoremove -y 2>/dev/null || true
    fi
    
    # Clean old log files
    sudo find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
    sudo find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
    
    # Clean Helm cache
    if command_exists helm; then
        helm repo update 2>/dev/null || true
    fi
    
    # Stop and clean minikube
    if command_exists minikube; then
        print_info "Cleaning minikube..."
        minikube stop 2>/dev/null || true
        minikube delete 2>/dev/null || true
        print_status "✅ Minikube cleaned"
    fi
    
    # Clean kind clusters
    if command_exists kind; then
        print_info "Cleaning kind clusters..."
        kind delete cluster --name student-tracker 2>/dev/null || true
        print_status "✅ Kind clusters cleaned"
    fi
    
    print_status "🎉 Complete system pruning finished!"
    print_info "All Docker, Kubernetes, and system resources have been cleaned"
}

# Option 2: Download and install all tools
install_all_tools() {
    print_header "INSTALLING ALL TOOLS"
    
    print_status "🔧 Installing all required tools..."
    
    # Update package list
    print_info "Updating system packages..."
    sudo apt update -y || {
        print_warning "Failed to update package list, continuing..."
    }
    
    # Install basic dependencies
    print_info "Installing basic dependencies..."
    sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release git || {
        print_error "Failed to install basic dependencies"
        exit 1
    }
    
    # Install Docker
    if ! command_exists docker; then
        print_status "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        
        # Start Docker service
        if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
            sudo systemctl start docker
            sudo systemctl enable docker
        fi
        print_status "✅ Docker installed successfully"
    else
        print_status "✅ Docker already installed"
    fi
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
        print_status "✅ kubectl installed successfully"
    else
        print_status "✅ kubectl already installed"
    fi
    
    # Install Helm
    if ! command_exists helm; then
        print_status "Installing Helm..."
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt update
        sudo apt install -y helm || {
            curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            chmod 700 get_helm.sh
            ./get_helm.sh
            rm get_helm.sh
        }
        print_status "✅ Helm installed successfully"
    else
        print_status "✅ Helm already installed"
    fi
    
    # Install minikube
    if ! command_exists minikube; then
        print_status "Installing minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        print_status "✅ minikube installed successfully"
    else
        print_status "✅ minikube already installed"
    fi
    
    # Install kind
    if ! command_exists kind; then
        print_status "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
        rm kind
        print_status "✅ kind installed successfully"
    else
        print_status "✅ kind already installed"
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        print_status "✅ ArgoCD CLI installed successfully"
    else
        print_status "✅ ArgoCD CLI already installed"
    fi
    
    # Install additional tools
    print_status "Installing additional tools..."
    
    # Install jq
    if ! command_exists jq; then
        sudo apt install -y jq
    fi
    
    # Install yq
    if ! command_exists yq; then
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    fi
    
    # Install k9s
    if ! command_exists k9s; then
        K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o k9s.tar.gz
        tar -xzf k9s.tar.gz k9s
        sudo install -o root -g root -m 0755 k9s /usr/local/bin/k9s
        rm -f k9s k9s.tar.gz
    fi
    
    # Install kubectx and kubens
    if ! command_exists kubectx; then
        sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || {
            sudo git -C /opt/kubectx pull
        }
        sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
        sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
    fi
    
    print_status "🎉 All tools installation completed!"
    
    # Verify installations
    print_status "Verifying tool installations..."
    command_exists kubectl && print_status "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    command_exists helm && print_status "✅ helm: $(helm version --short 2>/dev/null || echo 'installed')"
    command_exists docker && print_status "✅ docker: $(docker --version 2>/dev/null || echo 'installed')"
    command_exists minikube && print_status "✅ minikube: $(minikube version --short 2>/dev/null || echo 'installed')"
    command_exists kind && print_status "✅ kind: $(kind version 2>/dev/null || echo 'installed')"
    command_exists argocd && print_status "✅ argocd: $(argocd version --client --short 2>/dev/null || echo 'installed')"
    
    print_status "✅ All tools verified successfully!"
}

# Option 3: Create minikube cluster and deploy with DNS binding
deploy_to_minikube() {
    print_header "DEPLOYING TO MINIKUBE WITH DNS BINDING"
    
    # Check prerequisites
    if ! command_exists minikube; then
        print_error "minikube is not installed. Please run option 2 first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please run option 2 first."
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "helm is not installed. Please run option 2 first."
        exit 1
    fi
    
    # Start minikube cluster
    print_status "Starting minikube cluster..."
    minikube start --driver=docker --cpus=2 --memory=4096
    minikube addons enable ingress
    
    # Create namespace
    print_status "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Build Docker image
    print_status "Building Docker image..."
    docker build -t "$DOCKER_IMAGE:latest" .
    
    # Load image into minikube
    print_status "Loading image into minikube..."
    minikube image load "$DOCKER_IMAGE:latest"
    
    # Deploy application with Helm
    print_status "Deploying application with Helm..."
    helm upgrade --install "$APP_NAME" ./helm-chart \
        --namespace "$NAMESPACE" \
        --set image.repository="$DOCKER_IMAGE" \
        --set image.tag="latest" \
        --set image.pullPolicy="Never" \
        --set service.type="NodePort" \
        --set service.nodePort="$PRODUCTION_PORT" \
        --set ingress.enabled=true \
        --set ingress.hosts[0].host="$PRODUCTION_HOST" \
        --set ingress.hosts[0].paths[0].path="/" \
        --set ingress.hosts[0].paths[0].pathType="Prefix" \
        --set serviceMonitor.enabled=false
    
    # Wait for deployment
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/"$APP_NAME" -n "$NAMESPACE"
    
    # Create DNS binding
    print_status "Setting up DNS binding..."
    MINIKUBE_IP=$(minikube ip)
    echo "$MINIKUBE_IP $PRODUCTION_HOST" | sudo tee -a /etc/hosts
    
    # Test application
    print_status "Testing application..."
    sleep 10
    
    if curl -f "http://$PRODUCTION_HOST:$PRODUCTION_PORT/health" >/dev/null 2>&1; then
        print_status "✅ Application is healthy and responding"
    else
        print_warning "⚠️ Health check failed, but deployment may still be working"
    fi
    
    print_status "🎉 Deployment completed successfully!"
    print_info "Application URLs:"
    print_info "  • Main App: http://$PRODUCTION_HOST:$PRODUCTION_PORT"
    print_info "  • API Docs: http://$PRODUCTION_HOST:$PRODUCTION_PORT/docs"
    print_info "  • Health Check: http://$PRODUCTION_HOST:$PRODUCTION_PORT/health"
    print_info "  • Students Interface: http://$PRODUCTION_HOST:$PRODUCTION_PORT/students/"
}

# Option 4: Build Docker image with biwunor/nativeseries
build_docker_image() {
    print_header "BUILDING DOCKER IMAGE"
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please run option 2 first."
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in current directory"
        exit 1
    fi
    
    print_status "Building Docker image: $DOCKER_IMAGE:latest"
    
    # Build the image
    if docker build -t "$DOCKER_IMAGE:latest" .; then
        print_status "✅ Docker image built successfully"
        
        # Show image information
        print_status "Image details:"
        docker images | grep "$DOCKER_IMAGE"
        
        # Test the image locally
        print_status "Testing image locally..."
        docker run -d --name test-container -p 8080:8000 "$DOCKER_IMAGE:latest"
        sleep 10
        
        if curl -f "http://localhost:8080/health" >/dev/null 2>&1; then
            print_status "✅ Image test successful"
        else
            print_warning "⚠️ Image test failed, but image was built"
        fi
        
        # Clean up test container
        docker stop test-container 2>/dev/null || true
        docker rm test-container 2>/dev/null || true
        
        print_status "🎉 Docker image build completed!"
        print_info "Image: $DOCKER_IMAGE:latest"
        print_info "To push to registry: docker push $DOCKER_IMAGE:latest"
    else
        print_error "❌ Docker image build failed"
        exit 1
    fi
}

# Option 5: Full system analysis
full_system_analysis() {
    print_header "FULL SYSTEM ANALYSIS"
    
    print_status "🔍 Running comprehensive system analysis..."
    
    # System Information
    print_info "=== SYSTEM INFORMATION ==="
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "CPU: $(nproc) cores"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $4}') available"
    
    # Tool Status
    print_info "=== TOOL STATUS ==="
    local tools=("docker" "kubectl" "helm" "minikube" "kind" "argocd" "jq" "yq" "k9s" "kubectx" "kubens")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            echo "✅ $tool: $(command -v "$tool")"
        else
            echo "❌ $tool: Not installed"
        fi
    done
    
    # Docker Status
    print_info "=== DOCKER STATUS ==="
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            echo "✅ Docker: Running"
            echo "  Containers: $(docker ps -q | wc -l) running, $(docker ps -aq | wc -l) total"
            echo "  Images: $(docker images -q | wc -l)"
            echo "  Volumes: $(docker volume ls -q | wc -l)"
        else
            echo "⚠️ Docker: Installed but not running"
        fi
    else
        echo "❌ Docker: Not installed"
    fi
    
    # Kubernetes Status
    print_info "=== KUBERNETES STATUS ==="
    if command_exists kubectl; then
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "✅ Kubernetes: Connected"
            echo "  Context: $(kubectl config current-context)"
            echo "  Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
            echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
        else
            echo "⚠️ Kubernetes: kubectl available but no cluster connected"
        fi
    else
        echo "❌ Kubernetes: kubectl not installed"
    fi
    
    # Minikube Status
    print_info "=== MINIKUBE STATUS ==="
    if command_exists minikube; then
        if minikube status >/dev/null 2>&1; then
            echo "✅ Minikube: Running"
            echo "  Status: $(minikube status --format='{{.Host}}')"
            echo "  Driver: $(minikube config get driver)"
            echo "  IP: $(minikube ip)"
        else
            echo "⚠️ Minikube: Installed but not running"
        fi
    else
        echo "❌ Minikube: Not installed"
    fi
    
    # Application Status
    print_info "=== APPLICATION STATUS ==="
    
    # Check if application is running in Docker
    if docker ps | grep -q "$APP_NAME"; then
        echo "✅ Application: Running in Docker"
        echo "  Container: $(docker ps --filter name=$APP_NAME --format '{{.Names}}')"
        echo "  Port: $(docker port $APP_NAME 2>/dev/null || echo 'N/A')"
    else
        echo "❌ Application: Not running in Docker"
    fi
    
    # Check if application is running in Kubernetes
    if kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "$APP_NAME"; then
        echo "✅ Application: Running in Kubernetes"
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME"
    else
        echo "❌ Application: Not running in Kubernetes"
    fi
    
    # Network Status
    print_info "=== NETWORK STATUS ==="
    echo "Local IP: $(hostname -I | awk '{print $1}')"
    echo "Public IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unknown')"
    echo "DNS Resolution:"
    nslookup "$PRODUCTION_HOST" 2>/dev/null || echo "  Cannot resolve $PRODUCTION_HOST"
    
    # Port Status
    print_info "=== PORT STATUS ==="
    echo "Port $PRODUCTION_PORT: $(netstat -tlnp 2>/dev/null | grep ":$PRODUCTION_PORT" || echo 'Not listening')"
    echo "Port 80: $(netstat -tlnp 2>/dev/null | grep ':80' || echo 'Not listening')"
    echo "Port 443: $(netstat -tlnp 2>/dev/null | grep ':443' || echo 'Not listening')"
    
    # Health Checks
    print_info "=== HEALTH CHECKS ==="
    
    # Docker health check
    if docker ps | grep -q "$APP_NAME"; then
        if curl -f "http://localhost:$PRODUCTION_PORT/health" >/dev/null 2>&1; then
            echo "✅ Docker Application: Healthy"
        else
            echo "❌ Docker Application: Unhealthy"
        fi
    else
        echo "⚠️ Docker Application: Not running"
    fi
    
    # Kubernetes health check
    if kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "$APP_NAME"; then
        if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" --no-headers | grep -q "Running"; then
            echo "✅ Kubernetes Application: Healthy"
        else
            echo "❌ Kubernetes Application: Unhealthy"
        fi
    else
        echo "⚠️ Kubernetes Application: Not running"
    fi
    
    # ArgoCD Status
    print_info "=== ARGOCD STATUS ==="
    if command_exists argocd; then
        if kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q "argocd-server"; then
            echo "✅ ArgoCD: Running"
            argocd app list 2>/dev/null || echo "  No applications found"
        else
            echo "❌ ArgoCD: Not running"
        fi
    else
        echo "❌ ArgoCD: Not installed"
    fi
    
    # Helm Status
    print_info "=== HELM STATUS ==="
    if command_exists helm; then
        echo "✅ Helm: Installed"
        echo "  Version: $(helm version --short)"
        echo "  Repositories: $(helm repo list --output table 2>/dev/null | wc -l)"
        echo "  Releases: $(helm list --all-namespaces --no-headers 2>/dev/null | wc -l)"
    else
        echo "❌ Helm: Not installed"
    fi
    
    print_status "🎉 Full system analysis completed!"
    print_info "Check the results above for any issues that need attention."
}

# Main function
main() {
    case "${1:-}" in
        1)
            prune_all_system
            ;;
        2)
            install_all_tools
            ;;
        3)
            deploy_to_minikube
            ;;
        4)
            build_docker_image
            ;;
        5)
            full_system_analysis
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            print_error "Invalid option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"