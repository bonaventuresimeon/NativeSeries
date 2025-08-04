#!/bin/bash

# Robust deployment script for Amazon Linux
# Handles tool installation, validation, and deployment with minimal user interaction

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
NAMESPACE="student-tracker"
ARGOCD_NAMESPACE="argocd"
HELM_CHART_PATH="./helm-chart"
ARGOCD_APP_PATH="./argocd"
PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
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

# Function to install tools based on OS
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

# Install tools for Amazon Linux
install_tools_amazon() {
    print_status "Installing tools for Amazon Linux..."
    
    # Update system
    sudo yum update -y || print_warning "Failed to update system"
    
    # Install basic dependencies
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
        print_status "Installing Docker..."
        sudo yum install -y docker
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -a -G docker $USER
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    # Install additional tools
    if ! command_exists yq; then
        print_status "Installing yq..."
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi
    
    print_status "✅ Tools installation completed"
}

# Install tools for Ubuntu/Debian
install_tools_ubuntu() {
    print_status "Installing tools for Ubuntu/Debian..."
    
    # Update system
    sudo apt update -y || print_warning "Failed to update system"
    
    # Install basic dependencies
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
        print_status "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -a -G docker $USER
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    # Install additional tools
    if ! command_exists yq; then
        print_status "Installing yq..."
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi
    
    print_status "✅ Tools installation completed"
}

# Function to validate project structure
validate_project() {
    print_status "Validating project structure..."
    
    local required_files=(
        "app/main.py"
        "helm-chart/Chart.yaml"
        "argocd/application.yaml"
        "Dockerfile"
        "requirements.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            return 1
        fi
    done
    
    print_status "✅ Project structure validated"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local tools=("kubectl" "helm" "docker" "argocd")
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            print_error "$tool is not installed"
            return 1
        fi
    done
    
    # Check Docker access and fix group membership
    if ! docker info >/dev/null 2>&1; then
        print_status "Setting up Docker access..."
        
        # Add user to docker group if not already
        if ! groups | grep -q docker; then
            print_info "Adding user to docker group..."
            sudo usermod -a -G docker $USER
            print_warning "You may need to log out and back in for group changes to take effect"
        fi
        
        # Try to start Docker daemon
        if command_exists systemctl; then
            sudo systemctl start docker || print_warning "Failed to start Docker daemon"
        fi
        
        # Wait and try again
        sleep 2
        if ! docker info >/dev/null 2>&1; then
            print_warning "Docker still not accessible. Trying with sudo..."
            if ! sudo docker info >/dev/null 2>&1; then
                print_warning "Docker daemon may not be running"
            fi
        fi
    fi
    
    print_status "✅ Prerequisites check completed"
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    
    local image_name="${DOCKER_USERNAME:-student-tracker}/student-tracker:latest"
    
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
            print_info "Docker build will be skipped in container environment"
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
            print_info "You may need to:"
            print_info "1. Log out and back in (for group membership)"
            print_info "2. Start Docker manually: sudo systemctl start docker"
            print_info "3. Or run: newgrp docker"
            return 1
        fi
    fi
    
    # Build the image
    if docker build -t "$image_name" .; then
        print_status "✅ Docker image built successfully: $image_name"
        echo "$image_name" > .docker_image_name
    else
        print_error "Failed to build Docker image"
        return 1
    fi
}

# Function to deploy to production
deploy_production() {
    print_status "Deploying to production..."
    
    if [ ! -f .docker_image_name ]; then
        print_warning "Docker image not built"
        print_info "Production deployment will be prepared but not executed"
        print_info "Production host: $PRODUCTION_HOST:$PRODUCTION_PORT"
        return 0
    fi
    
    local image_name=$(cat .docker_image_name)
    
    # Check if we can connect to production
    if command_exists nc; then
        if ! nc -z "$PRODUCTION_HOST" "$PRODUCTION_PORT" 2>/dev/null; then
            print_warning "Cannot connect to production host $PRODUCTION_HOST:$PRODUCTION_PORT"
            print_info "Make sure the production server is running and accessible"
        fi
    else
        print_warning "netcat not available, skipping production connectivity check"
    fi
    
    print_status "✅ Production deployment ready"
    print_info "Production host: $PRODUCTION_HOST:$PRODUCTION_PORT"
    print_info "Docker image: $image_name"
}

# Function to validate Kubernetes cluster
check_cluster() {
    if command_exists kubectl; then
        if kubectl cluster-info >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    if ! check_cluster; then
        print_error "No Kubernetes cluster available"
        return 1
    fi
    
    # Install ArgoCD
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    print_status "✅ ArgoCD installed"
}

# Function to deploy application
deploy_application() {
    print_status "Deploying application..."
    
    if ! check_cluster; then
        print_error "No Kubernetes cluster available"
        return 1
    fi
    
    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy with Helm
    if [ -d "$HELM_CHART_PATH" ]; then
        helm upgrade --install "$APP_NAME" "$HELM_CHART_PATH" \
            --namespace "$NAMESPACE" \
            --set image.repository="${DOCKER_USERNAME:-student-tracker}/student-tracker" \
            --set image.tag=latest
    else
        print_error "Helm chart not found at $HELM_CHART_PATH"
        return 1
    fi
    
    print_status "✅ Application deployed"
}

# Function to show status
show_status() {
    print_status "Deployment Status:"
    
    if check_cluster; then
        print_info "Kubernetes cluster: Available"
        kubectl get pods -A
    else
        print_info "Kubernetes cluster: Not available"
    fi
    
    if [ -f .docker_image_name ]; then
        local image_name=$(cat .docker_image_name)
        print_info "Docker image: $image_name"
    fi
    
    print_info "Production host: $PRODUCTION_HOST:$PRODUCTION_PORT"
}

# Function to create validation report
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
        
        if check_cluster; then
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
        if ! check_cluster; then
            echo "• Set up a Kubernetes cluster for full deployment"
        fi
        if [ -z "${DOCKER_USERNAME:-}" ]; then
            echo "• Set DOCKER_USERNAME environment variable for Docker Hub pushes"
        fi
    } > "$report_file"
    
    print_status "✅ Validation report created: $report_file"
}

# Main function
main() {
    print_status "Starting deployment process..."
    
    # Get script directory and change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    cd "$PROJECT_ROOT"
    
    # Validate project structure
    validate_project || exit 1
    
    # Install tools if needed
    if ! command_exists kubectl || ! command_exists helm || ! command_exists docker; then
        print_status "Installing required tools..."
        install_tools
    fi
    
    # Check prerequisites
    check_prerequisites || {
        print_error "Prerequisites check failed"
        exit 1
    }
    
    # Try to build Docker image
    if ! build_docker_image; then
        print_warning "Docker build failed, but continuing with validation..."
        print_info "You can manually build the Docker image later"
    fi
    
    # Check if we have a cluster
    if check_cluster; then
        print_status "Kubernetes cluster detected"
        
        # Install ArgoCD if not present
        if ! kubectl get namespace argocd >/dev/null 2>&1; then
            install_argocd
        fi
        
        # Deploy application
        deploy_application
    else
        print_warning "No Kubernetes cluster available"
        print_info "Deploying to production only"
    fi
    
    # Deploy to production
    deploy_production
    
    # Show final status
    show_status
    
    # Create validation report
    create_validation_report
    
    print_status "✅ Deployment completed successfully!"
}

# Run main function
main "$@"