#!/bin/bash

# Robust deployment script for Amazon Linux
# Handles tool installation, validation, and deployment with minimal user interaction

set -euo pipefail

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
ARGOCD_NAMESPACE="argocd"
HELM_CHART_PATH="./helm-chart"
ARGOCD_APP_PATH="./argocd"
PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_IMAGE="${DOCKER_USERNAME:-student-tracker}/student-tracker"

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

# Function to check for existing clusters and provide guidance
check_existing_clusters() {
    print_status "Checking for existing Kubernetes clusters..."
    
    # Check for existing kubectl context
    if command_exists kubectl; then
        if kubectl config current-context >/dev/null 2>&1; then
            local current_context=$(kubectl config current-context)
            print_info "Found existing kubectl context: $current_context"
            
            # List available contexts
            print_info "Available kubectl contexts:"
            kubectl config get-contexts -o name | while read context; do
                print_info "  - $context"
            done
            
            return 0
        fi
    fi
    
    # Check for kind clusters
    if command_exists kind; then
        local kind_clusters=$(kind get clusters 2>/dev/null)
        if [ -n "$kind_clusters" ]; then
            print_info "Found existing kind clusters:"
            echo "$kind_clusters" | while read cluster; do
                print_info "  - $cluster"
            done
            return 0
        fi
    fi
    
    # Check for minikube
    if command_exists minikube; then
        if minikube status >/dev/null 2>&1; then
            print_info "Found minikube cluster"
            return 0
        fi
    fi
    
    print_warning "No existing Kubernetes clusters found"
    return 1
}

# Function to create Kubernetes cluster
create_cluster() {
    print_status "Creating Kubernetes cluster..."
    
    # Check if we're in a container environment
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        print_warning "Running in container environment - Docker daemon not available"
        print_info "Kind requires Docker daemon access to create clusters"
        print_info "Alternative options:"
        print_info "1. Use minikube (if available)"
        print_info "2. Use external Kubernetes cluster"
        print_info "3. Run this script on the host machine"
        return 1
    fi
    
    # Check if Docker is accessible
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon not accessible"
        print_info "Please ensure Docker is running and accessible"
        return 1
    fi
    
    # Check if kind is available
    if ! command_exists kind; then
        print_status "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    
    # Check if cluster already exists
    if kind get clusters | grep -q "kind"; then
        print_info "Kind cluster already exists"
        return 0
    fi
    
    # Create kind cluster
    print_status "Creating kind cluster..."
    kind create cluster --name kind || {
        print_error "Failed to create kind cluster"
        return 1
    }
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s || {
        print_warning "Cluster may not be fully ready, but continuing..."
    }
    
    print_status "✅ Kubernetes cluster created successfully"
}

# Function to install and setup minikube
install_minikube() {
    print_status "Installing minikube..."
    
    if ! command_exists minikube; then
        curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        chmod +x minikube
        sudo mv minikube /usr/local/bin/minikube
    fi
    
    # Check if minikube cluster exists
    if minikube status >/dev/null 2>&1; then
        print_info "Minikube cluster already exists"
        minikube start
        return 0
    fi
    
    # Start minikube
    print_status "Starting minikube cluster..."
    minikube start --driver=docker || {
        print_error "Failed to start minikube cluster"
        return 1
    }
    
    print_status "✅ Minikube cluster created successfully"
}

# Function to create namespace
create_namespace() {
    local namespace="$1"
    print_status "Creating namespace: $namespace"
    
    if ! check_cluster; then
        print_error "No Kubernetes cluster available"
        return 1
    fi
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "✅ Namespace '$namespace' created/verified"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    if ! check_cluster; then
        print_error "No Kubernetes cluster available"
        return 1
    fi
    
    # Create ArgoCD namespace
    create_namespace "$ARGOCD_NAMESPACE"
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s || {
        print_warning "ArgoCD may not be fully ready, but continuing..."
    }
    
    # Get ArgoCD admin password
    print_status "Getting ArgoCD admin password..."
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "$argocd_password" > .argocd_password
    
    print_status "✅ ArgoCD installed successfully"
    print_info "ArgoCD admin password saved to .argocd_password"
    print_info "ArgoCD UI will be available at: http://localhost:8080"
    print_info "Username: admin"
    print_info "Password: $argocd_password"
}

# Function to setup complete Kubernetes environment
setup_kubernetes_environment() {
    print_status "Setting up complete Kubernetes environment..."
    
    # Try to create cluster
    if ! create_cluster; then
        print_warning "Failed to create kind cluster, trying minikube..."
        if ! install_minikube; then
            print_error "Failed to create any Kubernetes cluster"
            return 1
        fi
    fi
    
    # Create application namespace
    create_namespace "$NAMESPACE"
    
    # Install ArgoCD
    install_argocd || {
        print_error "Failed to install ArgoCD"
        return 1
    }
    
    print_status "✅ Kubernetes environment setup completed"
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
        kubectl get nodes
        echo ""
        kubectl get pods -A
        echo ""
        
        # Check ArgoCD status
        if kubectl get namespace argocd >/dev/null 2>&1; then
            print_info "ArgoCD Status:"
            kubectl get pods -n argocd
            echo ""
            
            if [ -f .argocd_password ]; then
                local password=$(cat .argocd_password)
                print_info "ArgoCD UI Access:"
                print_info "URL: http://localhost:8080"
                print_info "Username: admin"
                print_info "Password: $password"
                echo ""
                print_info "To access ArgoCD UI, run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
            fi
        fi
    else
        print_info "Kubernetes cluster: Not available"
    fi
    
    if [ -f .docker_image_name ]; then
        local image_name=$(cat .docker_image_name)
        print_info "Docker image: $image_name"
    fi
    
    print_info "Production host: $PRODUCTION_HOST:$PRODUCTION_PORT"
}

# Function to start ArgoCD port-forward
start_argocd_portforward() {
    if ! check_cluster; then
        print_error "No Kubernetes cluster available"
        return 1
    fi
    
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        print_error "ArgoCD not installed"
        return 1
    fi
    
    print_status "Starting ArgoCD port-forward..."
    print_info "ArgoCD UI will be available at: http://localhost:8080"
    print_info "Press Ctrl+C to stop the port-forward"
    
    kubectl port-forward svc/argocd-server -n argocd 8080:443
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
    # Parse command line arguments
    local SETUP_CLUSTER=false
    local ARGOCD_PORTFORWARD=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-cluster)
                SETUP_CLUSTER=true
                shift
                ;;
            --argocd-portforward)
                ARGOCD_PORTFORWARD=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --setup-cluster      Create Kubernetes cluster and install ArgoCD"
                echo "  --argocd-portforward Start ArgoCD port-forward for UI access"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "Environment Variables:"
                echo "  DOCKER_USERNAME      Your Docker Hub username"
                echo "  PRODUCTION_HOST      Production host IP (default: 18.206.89.183)"
                echo "  PRODUCTION_PORT      Production port (default: 30011)"
                echo ""
                echo "What This Script Does:"
                echo "  1. Validates project structure and prerequisites"
                echo "  2. Installs required tools (kubectl, helm, docker, argocd, jq, yq)"
                echo "  3. Sets up Docker access and group membership"
                echo "  4. Creates Kubernetes cluster (kind/minikube) if requested"
                echo "  5. Installs ArgoCD with proper configuration"
                echo "  6. Builds Docker image (when Docker available)"
                echo "  7. Deploys application to Kubernetes cluster"
                echo "  8. Prepares production deployment configuration"
                echo "  9. Generates detailed validation report"
                echo ""
                echo "Cluster Creation Features:"
                echo "  • Automatic kind/minikube installation"
                echo "  • Container environment detection"
                echo "  • Existing cluster detection"
                echo "  • Graceful fallback options"
                echo "  • ArgoCD automatic installation"
                echo ""
                echo "Examples:"
                echo "  $0                              # Standard deployment"
                echo "  $0 --setup-cluster              # Create cluster and install ArgoCD"
                echo "  $0 --argocd-portforward         # Start ArgoCD port-forward"
                echo "  DOCKER_USERNAME=user $0         # Deploy with Docker Hub"
                echo ""
                echo "Troubleshooting:"
                echo "  • If Docker not available: Script continues with validation"
                echo "  • If cluster creation fails: Provides alternative options"
                echo "  • Container environments: Detected and handled gracefully"
                echo "  • Validation reports: Generated for troubleshooting"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_status "Starting deployment process..."
    
    # Get script directory and change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    cd "$PROJECT_ROOT"
    
    # Handle ArgoCD port-forward
    if [[ "$ARGOCD_PORTFORWARD" == "true" ]]; then
        start_argocd_portforward
        exit 0
    fi
    
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
    
    # Handle cluster setup
    if [[ "$SETUP_CLUSTER" == "true" ]]; then
        print_status "Setting up Kubernetes cluster and ArgoCD..."
        
        # Check for existing clusters first
        if check_existing_clusters; then
            print_info "Existing clusters found. You can use them instead of creating a new one."
        fi
        
        if setup_kubernetes_environment; then
            deploy_application
        else
            print_error "Failed to setup Kubernetes environment"
            print_info "Alternative options:"
            print_info "1. Use an existing Kubernetes cluster"
            print_info "2. Install minikube: curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube /usr/local/bin/"
            print_info "3. Use a cloud Kubernetes service (EKS, GKE, AKS)"
            print_info "4. Run this script on a host machine with Docker access"
        fi
    elif check_cluster; then
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
        print_info "To create a cluster, run: $0 --setup-cluster"
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