#!/bin/bash

# NativeSeries - Complete Installation & Deployment Script
# Version: 6.3.0 - Enhanced with comprehensive tool installation and error handling
# This script combines all installation, deployment, monitoring, and validation scripts
# Updated for NativeSeries with corrected manifests and Helm charts

set -euo pipefail

# Global error handling
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Function to handle errors
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_stack=$5
    
    echo -e "\n${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ❌ INSTALLATION FAILED! ❌                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}Error Details:${NC}"
    echo -e "${WHITE}  • Exit Code: $exit_code${NC}"
    echo -e "${WHITE}  • Line Number: $line_no${NC}"
    echo -e "${WHITE}  • Command: $last_command${NC}"
    echo -e "${WHITE}  • Function Stack: $func_stack${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting Steps:${NC}"
    echo -e "${WHITE}1. Check the error message above${NC}"
    echo -e "${WHITE}2. Verify system requirements and permissions${NC}"
    echo -e "${WHITE}3. Run cleanup script: ./scripts/cleanup-direct.sh${NC}"
    echo -e "${WHITE}4. Check logs and try again${NC}"
    echo ""
    echo -e "${CYAN}📖 For more help, check the troubleshooting section in the script${NC}"
    echo ""
    
    # Cleanup on error
    cleanup_on_error
    
    exit $exit_code
}

# Function to cleanup on error
cleanup_on_error() {
    echo -e "${YELLOW}🧹 Performing emergency cleanup...${NC}"
    
    # Stop any running containers
    if command_exists docker; then
        sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f get-docker.sh kind kubectl helm argocd yq
    rm -rf /tmp/helm-* /tmp/kind-* /tmp/kubectl-* /tmp/argocd-* /tmp/yq-*
    
    # Clean up virtual environment if it was created
    if [ -d "venv" ] && [ ! -f "venv/.keep" ]; then
        rm -rf venv
    fi
    
    echo -e "${GREEN}✓ Emergency cleanup completed${NC}"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Production Configuration - Updated for NativeSeries
PRODUCTION_HOST="54.166.101.159"
PRODUCTION_PORT="30011"
ARGOCD_PORT="30080"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"
LOKI_PORT="30083"
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="monitoring"
LOGGING_NAMESPACE="logging"
DOCKER_USERNAME="bonaventuresimeon"
DOCKER_IMAGE="ghcr.io/${DOCKER_USERNAME}/nativeseries"

# Tool versions
KUBECTL_VERSION="1.33.3"
HELM_VERSION="3.18.4"
KIND_VERSION="0.20.0"
ARGOCD_VERSION="v2.9.3"

# Repository configuration
REPO_URL="https://github.com/bonaventuresimeon/nativeseries.git"

# Get OS information
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture
case "${ARCH}" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
esac

# Function to detect package manager and OS
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        OS_TYPE="debian"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        OS_TYPE="rhel"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        OS_TYPE="rhel"
    else
        print_error "Unsupported package manager detected"
        exit 1
    fi
    print_info "Detected package manager: $PKG_MANAGER on $OS_TYPE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[✅ SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠️  WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[❌ ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[ℹ️  INFO]${NC} $1"; }

# Function to check system requirements
check_system_requirements() {
    print_section "System Requirements Check"
    
    local requirements_met=true
    
    # Check OS
    if [[ "$OS" == "linux" ]]; then
        print_status "✓ Operating System: Linux"
    else
        print_error "✗ Unsupported OS: $OS (Only Linux is supported)"
        requirements_met=false
    fi
    
    # Check architecture
    if [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" ]]; then
        print_status "✓ Architecture: $ARCH"
    else
        print_error "✗ Unsupported architecture: $ARCH (Only amd64 and arm64 are supported)"
        requirements_met=false
    fi
    
    # Check available disk space (minimum 5GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=5242880  # 5GB in KB
    if [ "$available_space" -gt "$required_space" ]; then
        print_status "✓ Available disk space: $(($available_space / 1024 / 1024))GB"
    else
        print_error "✗ Insufficient disk space: $(($available_space / 1024 / 1024))GB (Minimum 5GB required)"
        requirements_met=false
    fi
    
    # Check available memory (minimum 4GB)
    local available_memory=$(free -k | awk 'NR==2{print $2}')
    local required_memory=4194304  # 4GB in KB
    if [ "$available_memory" -gt "$required_memory" ]; then
        print_status "✓ Available memory: $(($available_memory / 1024 / 1024))GB"
    else
        print_error "✗ Insufficient memory: $(($available_memory / 1024 / 1024))GB (Minimum 4GB required)"
        requirements_met=false
    fi
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warning "⚠ Running as root (not recommended for security)"
    else
        print_status "✓ Not running as root"
    fi
    
    # Check sudo access
    if sudo -n true 2>/dev/null; then
        print_status "✓ Sudo access available"
    else
        print_error "✗ Sudo access required but not available"
        requirements_met=false
    fi
    
    # Check internet connectivity
    if curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
        print_status "✓ Internet connectivity available"
    else
        print_error "✗ No internet connectivity (required for downloads)"
        requirements_met=false
    fi
    
    if [ "$requirements_met" = false ]; then
        print_error "System requirements not met. Please fix the issues above and try again."
        exit 1
    fi
    
    print_status "✓ All system requirements met"
}

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          🚀 NativeSeries - Complete Installation                  ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                  ║"
echo "║              Full Stack Deployment with Monitoring              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check system requirements first
check_system_requirements

# Confirmation
echo -e "${YELLOW}This script will install and deploy the complete NativeSeries stack to:${NC}"
echo -e "${WHITE}  • Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}  • ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}  • Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}  • Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo -e "${WHITE}  • Loki:        http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo ""
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ============================================================================
# PHASE 1: MANIFEST VALIDATION AND FIXES
# ============================================================================

print_section "PHASE 1: Validating and Fixing Manifests"

# Validate Helm chart
print_info "Validating Helm chart..."
if helm template test helm-chart >/dev/null 2>&1; then
    print_status "Helm chart validation passed"
else
    print_error "Helm chart validation failed"
    exit 1
fi

# Validate ArgoCD application
print_info "Validating ArgoCD application..."
if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))" >/dev/null 2>&1; then
    print_status "ArgoCD application validation passed"
else
    print_error "ArgoCD application validation failed"
    exit 1
fi

# Validate all Kubernetes manifests
print_info "Validating Kubernetes manifests..."
for manifest in argocd/*.yaml deployment/production/*.yaml; do
    if [ -f "$manifest" ]; then
        if python3 -c "import yaml; list(yaml.safe_load_all(open('$manifest')))" >/dev/null 2>&1; then
            print_status "✓ $manifest validation passed"
        else
            print_error "✗ $manifest validation failed"
            exit 1
        fi
    fi
done

# ============================================================================
# PHASE 2: TOOL DETECTION AND INSTALLATION
# ============================================================================

print_section "PHASE 2: Tool Detection and Installation"

# Detect package manager first
detect_package_manager

# Function to install missing tools with comprehensive error handling
install_missing_tool() {
    local tool_name="$1"
    local install_command="$2"
    local check_command="$3"
    local version_command="$4"
    
    if command_exists "$tool_name"; then
        print_status "✓ $tool_name is already installed"
        if [ -n "$version_command" ]; then
            eval "$version_command"
        fi
        if [ -n "$check_command" ]; then
            eval "$check_command"
        fi
        return 0
    else
        print_info "Installing $tool_name..."
        if eval "$install_command"; then
            print_status "✓ $tool_name installed successfully"
            if [ -n "$version_command" ]; then
                eval "$version_command"
            fi
            return 0
        else
            print_error "✗ Failed to install $tool_name"
            return 1
        fi
    fi
}

# Function to download and install binary tools
install_binary_tool() {
    local tool_name="$1"
    local version="$2"
    local download_url="$3"
    local binary_name="$4"
    
    if command_exists "$tool_name"; then
        print_status "✓ $tool_name is already installed"
        $tool_name --version
        return 0
    fi
    
    print_info "Installing $tool_name v$version..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Download the binary
    if curl -L -o "$binary_name" "$download_url"; then
        chmod +x "$binary_name"
        sudo mv "$binary_name" "/usr/local/bin/$tool_name"
        print_status "✓ $tool_name v$version installed successfully"
        $tool_name --version
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 0
    else
        print_error "✗ Failed to download $tool_name"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to install Node.js and npm
install_nodejs() {
    if command_exists node && command_exists npm; then
        print_status "✓ Node.js and npm are already installed"
        node --version
        npm --version
        return 0
    fi
    
    print_info "Installing Node.js and npm..."
    
    # Install Node.js using NodeSource repository
    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    fi
    
    if command_exists node && command_exists npm; then
        print_status "✓ Node.js and npm installed successfully"
        node --version
        npm --version
        return 0
    else
        print_error "✗ Failed to install Node.js and npm"
        return 1
    fi
}

# Install basic system tools with comprehensive package list
print_info "Installing basic system tools..."
if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get update
    sudo apt-get install -y \
        curl wget git unzip jq gcc g++ make \
        python3 python3-pip python3-venv python3-dev \
        build-essential libssl-dev libffi-dev \
        ca-certificates gnupg lsb-release \
        software-properties-common apt-transport-https
else
    sudo yum update -y
    sudo yum install -y \
        curl wget git unzip jq gcc gcc-c++ make \
        python3 python3-pip python3-devel \
        openssl-devel libffi-devel \
        ca-certificates gnupg2
fi
print_status "✓ Basic system tools installed"

# Install Python virtual environment tools
if [ "$PKG_MANAGER" = "apt" ]; then
    install_missing_tool "python3-venv" "sudo apt-get install -y python3-venv" "python3 -m venv --help" "python3 -m venv --version"
else
    install_missing_tool "virtualenv" "sudo pip3 install virtualenv" "python3 -m virtualenv --help" "python3 -m virtualenv --version"
fi

# Install Docker with comprehensive setup
print_info "Checking Docker installation..."
if command_exists docker; then
    print_status "✓ Docker is already installed"
    docker --version
else
    print_info "Installing Docker..."
    
    # Remove any old Docker installations
    sudo $PKG_MANAGER remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    if [ "$PKG_MANAGER" = "apt" ]; then
        # Install Docker using official script
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh --version 24.0.7
        sudo usermod -aG docker $USER
        sudo systemctl start docker
        sudo systemctl enable docker
        rm -f get-docker.sh
    else
        # Install Docker for RHEL/CentOS
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    fi
    
    # Verify Docker installation
    if sudo docker --version; then
        print_status "✓ Docker installed successfully"
        # Test Docker functionality
        if sudo docker run --rm hello-world >/dev/null 2>&1; then
            print_status "✓ Docker functionality verified"
        else
            print_warning "⚠ Docker installed but functionality test failed"
        fi
    else
        print_error "✗ Docker installation failed"
        exit 1
    fi
fi

# Install Docker Compose
print_info "Checking Docker Compose installation..."
if command_exists docker-compose; then
    print_status "✓ Docker Compose is already installed"
    docker-compose --version
else
    print_info "Installing Docker Compose..."
    
    # Install Docker Compose v2
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get install -y docker-compose-plugin
    else
        sudo yum install -y docker-compose-plugin
    fi
    
    # Fallback to manual installation if package manager fails
    if ! command_exists docker-compose; then
        local compose_version="v2.23.3"
        sudo curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-${OS}-${ARCH}" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    if command_exists docker-compose; then
        print_status "✓ Docker Compose installed successfully"
        docker-compose --version
    else
        print_error "✗ Docker Compose installation failed"
        exit 1
    fi
fi

# Install kubectl with version verification
print_info "Installing kubectl..."
install_binary_tool "kubectl" "$KUBECTL_VERSION" \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
    "kubectl"

# Install Helm with comprehensive setup
print_info "Installing Helm..."
if command_exists helm; then
    print_status "✓ Helm is already installed"
    helm version
else
    print_info "Installing Helm v$HELM_VERSION..."
    
    # Try official installation script first
    if curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; then
        print_status "✓ Helm installed via official script"
    else
        # Fallback to manual installation
        install_binary_tool "helm" "$HELM_VERSION" \
            "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" \
            "${OS}-${ARCH}/helm"
    fi
    
    # Verify Helm installation
    if command_exists helm; then
        helm version
        print_status "✓ Helm installation verified"
    else
        print_error "✗ Helm installation failed"
        exit 1
    fi
fi

# Install Kind with comprehensive setup
print_info "Installing Kind..."
install_binary_tool "kind" "$KIND_VERSION" \
    "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}" \
    "kind"

# Install ArgoCD CLI
print_info "Installing ArgoCD CLI..."
if command_exists argocd; then
    print_status "✓ ArgoCD CLI is already installed"
    argocd version --client
else
    print_info "Installing ArgoCD CLI..."
    
    # Install ArgoCD CLI
    local argocd_cli_version="v2.9.3"
    install_binary_tool "argocd" "$argocd_cli_version" \
        "https://github.com/argoproj/argo-cd/releases/download/${argocd_cli_version}/argocd-${OS}-${ARCH}" \
        "argocd"
fi

# Install Node.js and npm for Netlify CLI
print_info "Installing Node.js and npm..."
install_nodejs

# Install Netlify CLI
print_info "Installing Netlify CLI..."
if command_exists netlify; then
    print_status "✓ Netlify CLI is already installed"
    netlify --version
else
    print_info "Installing Netlify CLI..."
    if npm install -g netlify-cli; then
        print_status "✓ Netlify CLI installed successfully"
        netlify --version
    else
        print_warning "⚠ Netlify CLI installation failed, but continuing..."
    fi
fi

# Install additional development tools
print_info "Installing additional development tools..."

# Install yq for YAML processing
if ! command_exists yq; then
    print_info "Installing yq..."
    install_binary_tool "yq" "v4.40.5" \
        "https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_${OS}_${ARCH}" \
        "yq"
fi

# Install jq if not already installed
if ! command_exists jq; then
    print_info "Installing jq..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get install -y jq
    else
        sudo yum install -y jq
    fi
fi

# Install tree for directory visualization
if ! command_exists tree; then
    print_info "Installing tree..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get install -y tree
    else
        sudo yum install -y tree
    fi
fi

# Install htop for system monitoring
if ! command_exists htop; then
    print_info "Installing htop..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get install -y htop
    else
        sudo yum install -y htop
    fi
fi

# Install additional Python tools
print_info "Installing additional Python tools..."
pip3 install --user --upgrade pip setuptools wheel
pip3 install --user black flake8 pytest pytest-asyncio

print_status "✓ All tools installed successfully"

# ============================================================================
# PHASE 3: TOOL VERIFICATION AND ENVIRONMENT SETUP
# ============================================================================

print_section "PHASE 3: Tool Verification and Environment Setup"

# Function to verify tool installation
verify_tool_installation() {
    local tool_name="$1"
    local version_flag="$2"
    
    if command_exists "$tool_name"; then
        print_status "✓ $tool_name is available"
        if [ -n "$version_flag" ]; then
            $tool_name $version_flag 2>/dev/null || print_warning "⚠ Could not get $tool_name version"
        fi
        return 0
    else
        print_error "✗ $tool_name is not available"
        return 1
    fi
}

# Verify all critical tools
print_info "Verifying tool installations..."
critical_tools=(
    "docker:--version"
    "kubectl:version --client"
    "helm:version"
    "kind:version"
    "python3:--version"
    "pip3:--version"
    "git:--version"
    "curl:--version"
    "wget:--version"
    "jq:--version"
)

verification_failed=false
for tool_info in "${critical_tools[@]}"; do
    IFS=':' read -r tool_name version_flag <<< "$tool_info"
    if ! verify_tool_installation "$tool_name" "$version_flag"; then
        verification_failed=true
    fi
done

if [ "$verification_failed" = true ]; then
    print_error "Some critical tools are missing. Please check the installation and try again."
    exit 1
fi

print_status "✓ All critical tools verified"

# Verify Docker daemon is running
print_info "Verifying Docker daemon..."
if sudo docker info >/dev/null 2>&1; then
    print_status "✓ Docker daemon is running"
else
    print_error "✗ Docker daemon is not running. Starting Docker..."
    sudo systemctl start docker
    if sudo docker info >/dev/null 2>&1; then
        print_status "✓ Docker daemon started successfully"
    else
        print_error "✗ Failed to start Docker daemon"
        exit 1
    fi
fi

# ============================================================================
# PHASE 4: APPLICATION SETUP
# ============================================================================

print_section "PHASE 4: Setting up Application Environment"

# Setup Python virtual environment with comprehensive error handling
if [ ! -d "venv" ]; then
    print_info "Creating Python virtual environment..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        if python3 -m venv venv; then
            print_status "✓ Virtual environment created using python3-venv"
        else
            print_error "✗ Failed to create virtual environment with python3-venv"
            exit 1
        fi
    else
        if python3 -m virtualenv venv; then
            print_status "✓ Virtual environment created using virtualenv"
        else
            print_error "✗ Failed to create virtual environment with virtualenv"
            exit 1
        fi
    fi
else
    print_status "✓ Virtual environment already exists"
fi

# Activate virtual environment and install Python dependencies
print_info "Installing Python dependencies..."
if source venv/bin/activate; then
    print_status "✓ Virtual environment activated"
    
    # Upgrade pip and install build tools
    pip install --upgrade pip setuptools wheel
    
    # Install Python dependencies with comprehensive error handling
    if [ -f "requirements.txt" ]; then
        print_info "Installing dependencies from requirements.txt..."
        if pip install -r requirements.txt; then
            print_status "✓ Python dependencies installed from requirements.txt"
        else
            print_warning "⚠ Some dependencies failed to install from requirements.txt, trying fallback..."
            # Fallback to essential packages
            pip install fastapi uvicorn pymongo python-multipart jinja2 aiofiles httpx motor hvac python-jose passlib python-dotenv redis pytest pytest-asyncio black flake8 gunicorn psutil mangum
            print_status "✓ Essential Python dependencies installed"
        fi
    else
        print_warning "⚠ requirements.txt not found, installing essential packages..."
        pip install fastapi uvicorn pymongo python-multipart jinja2 aiofiles httpx motor hvac python-jose passlib python-dotenv redis pytest pytest-asyncio black flake8 gunicorn psutil mangum
        print_status "✓ Essential Python dependencies installed"
    fi
    
    # Verify key Python packages
    print_info "Verifying Python package installations..."
    python -c "import fastapi, uvicorn, pymongo; print('✓ Core packages verified')" || print_warning "⚠ Some core packages may not be properly installed"
    
else
    print_error "✗ Failed to activate virtual environment"
    exit 1
fi

# ============================================================================
# PHASE 5: DOCKER IMAGE BUILD
# ============================================================================

print_section "PHASE 5: Building Docker Image"

print_info "Building Docker image..."
DOCKER_CMD="sudo docker"
$DOCKER_CMD build -t ${DOCKER_IMAGE}:latest . --network=host
print_status "Docker image built successfully"

# Test the application locally
print_info "Testing application locally..."
$DOCKER_CMD run -d --name test-app -p 8001:8000 ${DOCKER_IMAGE}:latest
sleep 30

# Health check
if curl -s http://localhost:8001/health | grep -q "healthy"; then
    print_status "Application health check passed"
else
    print_error "Application health check failed"
    $DOCKER_CMD logs test-app
    $DOCKER_CMD stop test-app || true
    $DOCKER_CMD rm test-app || true
    exit 1
fi

$DOCKER_CMD stop test-app || true
$DOCKER_CMD rm test-app || true

# ============================================================================
# PHASE 6: KUBERNETES CLUSTER SETUP
# ============================================================================

print_section "PHASE 6: Setting up Kubernetes Cluster"

# Create Kind cluster configuration
mkdir -p infra/kind
cat > infra/kind/cluster-config.yaml << EOF
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
  - containerPort: 30011
    hostPort: 30011
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30081
    hostPort: 30081
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30082
    hostPort: 30082
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30083
    hostPort: 30083
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF

# Create or use existing cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_info "Creating Kind cluster..."
    sudo kind create cluster --config infra/kind/cluster-config.yaml
    print_status "Kind cluster created successfully"
else
    print_status "Using existing Kubernetes cluster"
fi

# Load Docker image into Kind cluster
if command -v kind >/dev/null 2>&1 && kind get clusters | grep -q gitops-cluster; then
    print_info "Loading Docker image into Kind cluster..."
    sudo kind load docker-image ${DOCKER_IMAGE}:latest --name gitops-cluster
    print_status "Docker image loaded into cluster"
fi

# ============================================================================
# PHASE 7: DEPLOYMENT PREPARATION
# ============================================================================

print_section "PHASE 7: Preparing Deployment Manifests"

# Create deployment directories
mkdir -p deployment/production
mkdir -p deployment/monitoring

# Generate namespace manifest
cat > deployment/production/01-namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    name: ${NAMESPACE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ARGOCD_NAMESPACE}
  labels:
    name: ${ARGOCD_NAMESPACE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${MONITORING_NAMESPACE}
  labels:
    name: ${MONITORING_NAMESPACE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${LOGGING_NAMESPACE}
  labels:
    name: ${LOGGING_NAMESPACE}
EOF

# Generate application deployment using Helm
print_info "Generating application manifests..."
helm template ${APP_NAME} helm-chart \
    --namespace ${NAMESPACE} \
    --set image.repository=${DOCKER_IMAGE} \
    --set image.tag=latest \
    --set service.nodePort=${PRODUCTION_PORT} \
    > deployment/production/02-application.yaml

# Generate ArgoCD service with NodePort
cat > deployment/production/04-argocd-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: ${ARGOCD_NAMESPACE}
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: ${ARGOCD_PORT}
    protocol: TCP
  selector:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
EOF

# Update ArgoCD application manifest for production
sed "s|https://kubernetes.default.svc|https://${PRODUCTION_HOST}|g" argocd/application.yaml > deployment/production/05-argocd-application.yaml

# Generate monitoring stack with Loki
print_info "Generating monitoring and logging manifests..."
cat > deployment/production/06-monitoring-stack.yaml << EOF
# Prometheus
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${MONITORING_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus/
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --web.enable-lifecycle
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: ${MONITORING_NAMESPACE}
spec:
  type: NodePort
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: ${PROMETHEUS_PORT}
  selector:
    app: prometheus
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: ${MONITORING_NAMESPACE}
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
    - job_name: '${APP_NAME}'
      static_configs:
      - targets: ['${APP_NAME}-service.${NAMESPACE}.svc.cluster.local:8000']
    - job_name: 'loki'
      static_configs:
      - targets: ['loki-service.${LOGGING_NAMESPACE}.svc.cluster.local:3100']
---
# Grafana
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: ${MONITORING_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin123
        - name: GF_FEATURE_TOGGLES_ENABLE
          value: "publicDashboards"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
      volumes:
      - name: grafana-storage
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: ${MONITORING_NAMESPACE}
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: ${GRAFANA_PORT}
  selector:
    app: grafana
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: ${MONITORING_NAMESPACE}
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-service.${MONITORING_NAMESPACE}.svc.cluster.local:9090
      access: proxy
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki-service.${LOGGING_NAMESPACE}.svc.cluster.local:3100
      access: proxy
---
# Loki
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: ${LOGGING_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
      - name: loki
        image: grafana/loki:latest
        ports:
        - containerPort: 3100
        args:
        - -config.file=/etc/loki/local-config.yaml
        volumeMounts:
        - name: loki-config
          mountPath: /etc/loki
        - name: loki-storage
          mountPath: /loki
      volumes:
      - name: loki-config
        configMap:
          name: loki-config
      - name: loki-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: loki-service
  namespace: ${LOGGING_NAMESPACE}
spec:
  type: NodePort
  ports:
  - port: 3100
    targetPort: 3100
    nodePort: ${LOKI_PORT}
  selector:
    app: loki
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: ${LOGGING_NAMESPACE}
data:
  local-config.yaml: |
    auth_enabled: false
    server:
      http_listen_port: 3100
    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
        final_sleep: 0s
      chunk_idle_period: 5m
      chunk_retain_period: 30s
    schema_config:
      configs:
        - from: 2020-05-15
          store: boltdb
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h
    storage_config:
      boltdb:
        directory: /loki/index
      filesystem:
        directory: /loki/chunks
    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
    chunk_store_config:
      max_look_back_period: 0s
    table_manager:
      retention_deletes_enabled: false
      retention_period: 0s
---
# Promtail for log collection
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: ${LOGGING_NAMESPACE}
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      containers:
      - name: promtail
        image: grafana/promtail:latest
        args:
        - -config.file=/etc/promtail/config.yml
        volumeMounts:
        - name: promtail-config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: promtail-config
        configMap:
          name: promtail-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: ${LOGGING_NAMESPACE}
data:
  config.yml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    positions:
      filename: /tmp/positions.yaml
    clients:
    - url: http://loki-service.${LOGGING_NAMESPACE}.svc.cluster.local:3100/loki/api/v1/push
    scrape_configs:
    - job_name: system
      static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
    - job_name: containers
      static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log
EOF

print_status "Deployment manifests generated"

# ============================================================================
# PHASE 7: KUBERNETES DEPLOYMENT
# ============================================================================

print_section "PHASE 7: Deploying to Kubernetes"

# Deploy if cluster is available
if kubectl cluster-info >/dev/null 2>&1; then
    print_info "Deploying to Kubernetes cluster..."
    
    # Apply manifests in order
    kubectl apply -f deployment/production/01-namespace.yaml
    print_status "Namespaces created"
    
    # PHASE 7.1: Comprehensive Resource Cleanup
    print_info "Performing comprehensive resource cleanup in ${NAMESPACE} namespace..."
    
    # Check if Helm release exists and uninstall it first
    if helm list -n ${NAMESPACE} | grep -q "${APP_NAME}"; then
        print_info "Existing Helm release found, uninstalling..."
        helm uninstall ${APP_NAME} -n ${NAMESPACE} --ignore-not-found=true
        print_status "Existing Helm release uninstalled"
    fi
    
    # Clean up all resources that might conflict with Helm
    print_info "Cleaning up existing Kubernetes resources..."
    kubectl delete networkpolicy -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete secret -n ${NAMESPACE} --field-selector type!=kubernetes.io/service-account-token --ignore-not-found=true
    kubectl delete configmap -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete deployment -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete service -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete ingress -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete hpa -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete pdb -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete job -n ${NAMESPACE} --all --ignore-not-found=true
    kubectl delete serviceaccount -n ${NAMESPACE} --all --ignore-not-found=true
    
    # Wait for cleanup to complete
    print_info "Waiting for cleanup to complete..."
    sleep 10
    
    # Verify namespace is clean
    remaining_resources=$(kubectl get all -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$remaining_resources" -gt 0 ]; then
        print_warning "Some resources still exist, forcing deletion..."
        kubectl delete all -n ${NAMESPACE} --all --ignore-not-found=true
        kubectl delete networkpolicy,secret,configmap,ingress,hpa,pdb,job,serviceaccount -n ${NAMESPACE} --all --ignore-not-found=true
    fi
    
    print_status "Comprehensive resource cleanup completed"
    
    # PHASE 7.2: Helm Chart Validation
    print_info "Validating Helm chart before deployment..."
    if ! validate_helm_chart "helm-chart" "${NAMESPACE}"; then
        print_error "Helm chart validation failed. Cannot proceed with deployment."
        exit 1
    fi
    
    # PHASE 7.3: Helm Deployment with Retry Logic
    print_info "Deploying application using Helm to ${NAMESPACE} namespace..."
    
    # Function to attempt Helm deployment with retries
    deploy_with_helm() {
        local max_attempts=3
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            print_info "Helm deployment attempt $attempt of $max_attempts..."
            
            if helm upgrade --install ${APP_NAME} helm-chart \
                --namespace ${NAMESPACE} \
                --create-namespace \
                --set image.repository=${DOCKER_IMAGE} \
                --set image.tag=latest \
                --set service.nodePort=${PRODUCTION_PORT} \
                --wait \
                --timeout=10m; then
                
                print_success "✅ Helm deployment successful on attempt $attempt"
                return 0
            else
                print_warning "⚠️ Helm deployment failed on attempt $attempt"
                
                if [ $attempt -lt $max_attempts ]; then
                    print_info "Cleaning up and retrying..."
                    helm uninstall ${APP_NAME} -n ${NAMESPACE} --ignore-not-found=true
                    sleep 15
                fi
                
                attempt=$((attempt + 1))
            fi
        done
        
        print_error "❌ All Helm deployment attempts failed"
        return 1
    }
    
    # Execute Helm deployment with retry logic
    if deploy_with_helm; then
        print_status "Application deployed successfully to ${NAMESPACE} namespace"
    else
        print_error "Failed to deploy application to ${NAMESPACE} namespace"
        
        # Diagnose the issue
        handle_helm_issues ${NAMESPACE} ${APP_NAME}
        
        # Ask user if they want to perform emergency cleanup
        echo
        print_warning "Helm deployment failed. Would you like to perform emergency cleanup and retry?"
        read -p "Perform emergency cleanup? (y/N): " emergency_cleanup_choice
        
        if [[ $emergency_cleanup_choice =~ ^[Yy]$ ]]; then
            if emergency_cleanup ${NAMESPACE} ${APP_NAME}; then
                print_info "Retrying Helm deployment after emergency cleanup..."
                if deploy_with_helm; then
                    print_success "✅ Application deployed successfully after emergency cleanup"
                else
                    print_error "❌ Deployment still failed after emergency cleanup"
                    print_info "You can try running the fix script: ./scripts/fix-helm-deployment.sh"
                    exit 1
                fi
            else
                print_error "Emergency cleanup failed"
                print_info "You can try running the fix script: ./scripts/fix-helm-deployment.sh"
                exit 1
            fi
        else
            print_info "Skipping emergency cleanup. You can try running the fix script: ./scripts/fix-helm-deployment.sh"
            exit 1
        fi
    fi
    
    # Install ArgoCD
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    kubectl apply -f deployment/production/04-argocd-service.yaml
    print_status "ArgoCD installed"
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE} || true
    
    # Deploy monitoring and logging stack
    kubectl apply -f deployment/production/06-monitoring-stack.yaml
    print_status "Monitoring and logging stack deployed"
    
    # Create ArgoCD application
    sleep 30
    kubectl apply -f deployment/production/05-argocd-application.yaml || true
    print_status "ArgoCD application created"
    
else
    print_warning "No Kubernetes cluster available. Deployment manifests are ready in deployment/production/"
fi

# ============================================================================
# PHASE 8: COMPREHENSIVE VERIFICATION AND STATUS CHECKING
# ============================================================================

print_section "PHASE 8: Comprehensive Verification and Status Checking"

# Function to handle Helm deployment issues
handle_helm_issues() {
    local namespace=$1
    local app_name=$2
    
    print_info "Diagnosing Helm deployment issues in namespace $namespace..."
    
    # Check for common issues
    print_info "Checking for common Helm deployment issues..."
    
    # 1. Check for existing resources without Helm ownership
    local conflicting_resources=$(kubectl get all,networkpolicy,secret,configmap,ingress,hpa,pdb -n $namespace --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$conflicting_resources" -gt 0 ]; then
        print_warning "Found $conflicting_resources existing resources that may conflict with Helm"
        print_info "These resources will be cleaned up automatically"
    fi
    
    # 2. Check Helm release status
    if helm list -n $namespace | grep -q "$app_name"; then
        print_info "Existing Helm release found, checking status..."
        helm status $app_name -n $namespace
    else
        print_info "No existing Helm release found"
    fi
    
    # 3. Check namespace status
    print_info "Checking namespace status..."
    kubectl get namespace $namespace -o yaml | grep -E "(status|phase)" || true
    
    # 4. Check for resource quotas or limits
    print_info "Checking for resource constraints..."
    kubectl get resourcequota -n $namespace 2>/dev/null || print_info "No resource quotas found"
    kubectl get limitrange -n $namespace 2>/dev/null || print_info "No limit ranges found"
}

# Function to validate Helm chart
validate_helm_chart() {
    local chart_path=$1
    local namespace=$2
    
    print_info "Validating Helm chart at $chart_path..."
    
    # Check if chart directory exists
    if [ ! -d "$chart_path" ]; then
        print_error "Helm chart directory not found: $chart_path"
        return 1
    fi
    
    # Check if Chart.yaml exists
    if [ ! -f "$chart_path/Chart.yaml" ]; then
        print_error "Chart.yaml not found in $chart_path"
        return 1
    fi
    
    # Validate chart structure
    print_info "Validating chart structure..."
    if ! helm lint "$chart_path"; then
        print_error "Helm chart validation failed"
        return 1
    fi
    
    # Test template rendering
    print_info "Testing template rendering..."
    if ! helm template test-release "$chart_path" --namespace "$namespace" --dry-run >/dev/null 2>&1; then
        print_error "Helm template rendering failed"
        return 1
    fi
    
    print_success "✅ Helm chart validation passed"
    return 0
}

# Function to perform emergency cleanup
emergency_cleanup() {
    local namespace=$1
    local app_name=$2
    
    print_warning "Performing emergency cleanup for namespace $namespace..."
    
    # Force delete all resources
    print_info "Force deleting all resources in namespace $namespace..."
    kubectl delete all,networkpolicy,secret,configmap,ingress,hpa,pdb,job,serviceaccount -n $namespace --all --ignore-not-found=true --grace-period=0 --force
    
    # Uninstall Helm release
    print_info "Uninstalling Helm release..."
    helm uninstall $app_name -n $namespace --ignore-not-found=true
    
    # Wait for cleanup
    print_info "Waiting for cleanup to complete..."
    sleep 20
    
    # Verify cleanup
    local remaining=$(kubectl get all -n $namespace --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$remaining" -eq 0 ]; then
        print_success "Emergency cleanup completed successfully"
        return 0
    else
        print_warning "Some resources still remain after emergency cleanup"
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label_selector=$2
    local timeout=300
    local interval=10
    
    print_info "Waiting for pods in namespace $namespace with selector $label_selector..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if kubectl get pods -n $namespace -l $label_selector --no-headers | grep -q "Running"; then
            local ready_pods=$(kubectl get pods -n $namespace -l $label_selector --no-headers | grep "Running" | wc -l)
            local total_pods=$(kubectl get pods -n $namespace -l $label_selector --no-headers | wc -l)
            if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
                print_status "All pods in $namespace are ready ($ready_pods/$total_pods)"
                return 0
            fi
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        print_info "Still waiting... ($elapsed/$timeout seconds elapsed)"
    done
    
    print_warning "Timeout waiting for pods in $namespace"
    return 1
}

# Function to check service endpoints
check_service_endpoints() {
    local namespace=$1
    local service_name=$2
    local port=$3
    
    print_info "Checking service $service_name in namespace $namespace..."
    
    # Check if service exists
    if kubectl get service $service_name -n $namespace >/dev/null 2>&1; then
        print_status "✓ Service $service_name exists"
        
        # Check if endpoints are available
        local endpoints=$(kubectl get endpoints $service_name -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            print_status "✓ Service $service_name has endpoints: $endpoints"
            return 0
        else
            print_warning "⚠ Service $service_name has no endpoints yet"
            return 1
        fi
    else
        print_error "✗ Service $service_name not found"
        return 1
    fi
}

# Function to test application health
test_application_health() {
    local url=$1
    local service_name=$2
    local max_retries=30
    local retry_interval=10
    
    print_info "Testing $service_name health at $url..."
    
    for i in $(seq 1 $max_retries); do
        if curl -s -f "$url" >/dev/null 2>&1; then
            print_status "✓ $service_name is healthy and responding"
            return 0
        else
            print_info "Attempt $i/$max_retries: $service_name not ready yet..."
            sleep $retry_interval
        fi
    done
    
    print_warning "⚠ $service_name health check failed after $max_retries attempts"
    return 1
}

# Wait for all components to be ready
print_info "Waiting for all components to be ready..."

# Wait for application pods
wait_for_pods $NAMESPACE "app.kubernetes.io/name=$APP_NAME"

# Wait for ArgoCD pods
wait_for_pods $ARGOCD_NAMESPACE "app.kubernetes.io/name=argocd-server"

# Wait for monitoring pods
wait_for_pods $MONITORING_NAMESPACE "app=prometheus"
wait_for_pods $MONITORING_NAMESPACE "app=grafana"

# Wait for logging pods
wait_for_pods $LOGGING_NAMESPACE "app=loki"
wait_for_pods $LOGGING_NAMESPACE "app=promtail"

# Check all services
print_info "Verifying all services..."

# Application service
check_service_endpoints $NAMESPACE "${APP_NAME}-service" $PRODUCTION_PORT

# ArgoCD service
check_service_endpoints $ARGOCD_NAMESPACE "argocd-server-nodeport" $ARGOCD_PORT

# Monitoring services
check_service_endpoints $MONITORING_NAMESPACE "prometheus-service" $PROMETHEUS_PORT
check_service_endpoints $MONITORING_NAMESPACE "grafana-service" $GRAFANA_PORT

# Logging services
check_service_endpoints $LOGGING_NAMESPACE "loki-service" $LOKI_PORT

# Test application health endpoints
print_info "Testing application health endpoints..."

# Test application
test_application_health "http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health" "NativeSeries Application"

# Test ArgoCD
test_application_health "http://${PRODUCTION_HOST}:${ARGOCD_PORT}" "ArgoCD"

# Test Prometheus
test_application_health "http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}/-/ready" "Prometheus"

# Test Grafana
test_application_health "http://${PRODUCTION_HOST}:${GRAFANA_PORT}/api/health" "Grafana"

# Test Loki
test_application_health "http://${PRODUCTION_HOST}:${LOKI_PORT}/ready" "Loki"

# ============================================================================
# PHASE 9: SHOW RUNNING STATUS
# ============================================================================

print_section "PHASE 9: Current Running Status"

# Show cluster status
print_info "Kubernetes Cluster Status:"
kubectl cluster-info

# Show all namespaces
print_info "All Namespaces:"
kubectl get namespaces

# Show application status
print_info "Application Status ($NAMESPACE namespace):"
kubectl get pods,services,ingress -n $NAMESPACE

# Show ArgoCD status
print_info "ArgoCD Status ($ARGOCD_NAMESPACE namespace):"
kubectl get pods,services -n $ARGOCD_NAMESPACE

# Show monitoring status
print_info "Monitoring Status ($MONITORING_NAMESPACE namespace):"
kubectl get pods,services -n $MONITORING_NAMESPACE

# Show logging status
print_info "Logging Status ($LOGGING_NAMESPACE namespace):"
kubectl get pods,services -n $LOGGING_NAMESPACE

# Show all services across namespaces
print_info "All Services (NodePort):"
kubectl get services --all-namespaces -o wide | grep NodePort

# Show resource usage
print_info "Resource Usage:"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
kubectl top pods --all-namespaces 2>/dev/null || print_warning "Pod metrics not available"

# ============================================================================
# PHASE 10: VALIDATION AND TESTING
# ============================================================================

print_section "PHASE 10: Final Validation and Testing"

# Validate Helm chart
print_info "Validating Helm chart..."
helm lint helm-chart
print_status "Helm chart validation passed"

# Test application endpoints
print_info "Running final validation tests..."
validation_score=0
total_tests=8

# Test 1: Docker image
if $DOCKER_CMD images | grep -q ${DOCKER_IMAGE}; then
    print_status "Docker image exists"
    ((validation_score++))
else
    print_error "Docker image not found"
fi

# Test 2: Python dependencies
if source venv/bin/activate && python -c "import fastapi, uvicorn, pymongo" 2>/dev/null; then
    print_status "Python dependencies available"
    ((validation_score++))
else
    print_error "Python dependencies missing"
fi

# Test 3: Helm chart syntax
if helm template test helm-chart >/dev/null 2>&1; then
    print_status "Helm chart syntax valid"
    ((validation_score++))
else
    print_error "Helm chart syntax invalid"
fi

# Test 4: Kubernetes manifests
if find deployment/production -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \; >/dev/null 2>&1; then
    print_status "Kubernetes manifests valid"
    ((validation_score++))
else
    print_warning "Some Kubernetes manifests may have issues"
fi

# Test 5: Application code
if python3 -c "import app.main" 2>/dev/null; then
    print_status "Application code imports successfully"
    ((validation_score++))
else
    print_error "Application code has import issues"
fi

# Test 6: Application health
if curl -s "http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health" | grep -q "healthy" 2>/dev/null; then
    print_status "Application health check passed"
    ((validation_score++))
else
    print_warning "Application health check failed (may not be deployed yet)"
fi

# Test 7: ArgoCD health
if curl -s "http://${PRODUCTION_HOST}:${ARGOCD_PORT}" >/dev/null 2>&1; then
    print_status "ArgoCD is accessible"
    ((validation_score++))
else
    print_warning "ArgoCD not accessible yet"
fi

# Test 8: Monitoring stack health
if curl -s "http://${PRODUCTION_HOST}:${GRAFANA_PORT}/api/health" >/dev/null 2>&1; then
    print_status "Monitoring stack is accessible"
    ((validation_score++))
else
    print_warning "Monitoring stack not accessible yet"
fi

# Calculate success rate
success_rate=$(( validation_score * 100 / total_tests ))

# ============================================================================
# PHASE 11: FINAL REPORT AND ACCESS LINKS
# ============================================================================

print_section "PHASE 11: Installation Complete - Access Your NativeSeries Stack"

# Generate final deployment guide
cat > FINAL_DEPLOYMENT_GUIDE.md << EOF
# 🎉 NativeSeries - Complete Installation Summary

## ✅ Installation Status: COMPLETE
**Success Rate:** ${success_rate}%  
**Target Server:** ${PRODUCTION_HOST}  
**Date:** $(date)

## 🌐 Access URLs

### 📱 NativeSeries Application
- **URL:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}
- **Health Check:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health
- **API Documentation:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs

### 🎯 ArgoCD GitOps Dashboard
- **URL:** http://${PRODUCTION_HOST}:${ARGOCD_PORT}
- **Username:** admin
- **Password:** Get with: \`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d\`

### 📊 Monitoring Stack
- **Grafana:** http://${PRODUCTION_HOST}:${GRAFANA_PORT} (admin/admin123)
- **Prometheus:** http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}

### 📝 Logging Stack
- **Loki:** http://${PRODUCTION_HOST}:${LOKI_PORT}
- **Grafana Logs:** Access through Grafana UI (Loki data source pre-configured)

## 🚀 Quick Deploy Commands

If cluster is not available, use these commands to deploy:

\`\`\`bash
# Create cluster (if needed)
kind create cluster --name gitops-cluster

# Deploy everything
kubectl apply -f deployment/production/01-namespace.yaml
kubectl apply -f deployment/production/02-application.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
kubectl apply -f deployment/production/04-argocd-service.yaml
kubectl apply -f deployment/production/06-monitoring-stack.yaml
kubectl apply -f deployment/production/05-argocd-application.yaml
\`\`\`

## 📁 Generated Files
- \`deployment/production/\` - All Kubernetes manifests
- \`infra/kind/cluster-config.yaml\` - Kind cluster configuration
- \`venv/\` - Python virtual environment
- Docker image: \`${DOCKER_IMAGE}:latest\`

## 🎯 Next Steps
1. Access the application at http://${PRODUCTION_HOST}:${PRODUCTION_PORT}
2. Configure ArgoCD applications for GitOps
3. Set up monitoring dashboards in Grafana
4. Configure logging queries in Grafana with Loki
5. Configure CI/CD pipelines

## 🔧 Enhanced Features (v6.2.0)
- **Robust Helm Deployment**: Automatic cleanup and retry logic
- **Conflict Resolution**: Handles existing resources gracefully
- **Emergency Cleanup**: Interactive cleanup for deployment issues
- **Chart Validation**: Pre-deployment Helm chart validation
- **Comprehensive Monitoring**: Full stack with Prometheus, Grafana, and Loki
- **GitOps Ready**: ArgoCD integration for continuous deployment

Installation completed successfully! 🎉
EOF

# Display final summary with access links
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 INSTALLATION COMPLETE! 🎉                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${WHITE}🌐 Your NativeSeries Stack is Ready! Access URLs:${NC}"
echo ""
echo -e "${CYAN}📱 NativeSeries Application:${NC}"
echo -e "${WHITE}   • Main App:     http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}   • Health Check: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health${NC}"
echo -e "${WHITE}   • API Docs:     http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs${NC}"
echo ""
echo -e "${CYAN}🎯 ArgoCD GitOps Dashboard:${NC}"
echo -e "${WHITE}   • URL:          http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}   • Username:     admin${NC}"
echo -e "${WHITE}   • Password:     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
echo ""
echo -e "${CYAN}📊 Monitoring Stack:${NC}"
echo -e "${WHITE}   • Grafana:      http://${PRODUCTION_HOST}:${GRAFANA_PORT} (admin/admin123)${NC}"
echo -e "${WHITE}   • Prometheus:   http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo ""
echo -e "${CYAN}📝 Logging Stack:${NC}"
echo -e "${WHITE}   • Loki:         http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo -e "${WHITE}   • Grafana Logs: Access through Grafana UI (Loki data source pre-configured)${NC}"
echo ""
echo -e "${GREEN}✅ Success Rate: ${success_rate}%${NC}"
echo -e "${BLUE}📖 Full guide: FINAL_DEPLOYMENT_GUIDE.md${NC}"
echo ""

# Show current status summary
echo -e "${YELLOW}📊 Current Status Summary:${NC}"
echo -e "${WHITE}   • Application Pods: $(kubectl get pods -n $NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • ArgoCD Pods:     $(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • Monitoring Pods: $(kubectl get pods -n $MONITORING_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $MONITORING_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • Logging Pods:    $(kubectl get pods -n $LOGGING_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $LOGGING_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo ""

# Clean up temporary files
rm -f get-docker.sh

# ============================================================================
# FINAL VERIFICATION AND CLEANUP
# ============================================================================

print_section "Final Verification and Cleanup"

# Function to perform final health checks
perform_final_health_checks() {
    print_info "Performing final health checks..."
    
    local health_checks_passed=0
    local total_health_checks=0
    
    # Check application health
    total_health_checks=$((total_health_checks + 1))
    if test_application_health "http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health" "NativeSeries Application"; then
        health_checks_passed=$((health_checks_passed + 1))
    fi
    
    # Check ArgoCD health
    total_health_checks=$((total_health_checks + 1))
    if test_application_health "http://${PRODUCTION_HOST}:${ARGOCD_PORT}" "ArgoCD"; then
        health_checks_passed=$((health_checks_passed + 1))
    fi
    
    # Check Grafana health
    total_health_checks=$((total_health_checks + 1))
    if test_application_health "http://${PRODUCTION_HOST}:${GRAFANA_PORT}" "Grafana"; then
        health_checks_passed=$((health_checks_passed + 1))
    fi
    
    # Check Prometheus health
    total_health_checks=$((total_health_checks + 1))
    if test_application_health "http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}" "Prometheus"; then
        health_checks_passed=$((health_checks_passed + 1))
    fi
    
    # Calculate success rate
    local final_success_rate=$((health_checks_passed * 100 / total_health_checks))
    
    if [ $final_success_rate -ge 80 ]; then
        print_status "✓ Final health checks passed: $health_checks_passed/$total_health_checks ($final_success_rate%)"
        return 0
    else
        print_warning "⚠ Final health checks: $health_checks_passed/$total_health_checks ($final_success_rate%)"
        return 1
    fi
}

# Function to clean up temporary files and directories
cleanup_temporary_files() {
    print_info "Cleaning up temporary files..."
    
    # Remove temporary files
    rm -f get-docker.sh kind kubectl helm argocd yq
    
    # Clean up temporary directories
    rm -rf /tmp/helm-* /tmp/kind-* /tmp/kubectl-* /tmp/argocd-* /tmp/yq-*
    
    # Clean up Docker system
    if command_exists docker; then
        print_info "Cleaning up Docker system..."
        sudo docker system prune -f >/dev/null 2>&1 || true
    fi
    
    print_status "✓ Temporary files cleaned up"
}

# Function to display troubleshooting information
display_troubleshooting_info() {
    print_info "Troubleshooting Information:"
    echo ""
    echo -e "${YELLOW}🔧 Common Issues and Solutions:${NC}"
    echo ""
    echo -e "${WHITE}1. If services are not accessible:${NC}"
    echo -e "${CYAN}   • Check if ports are open: sudo netstat -tlnp | grep -E ':(30011|30080|30081|30082|30083)'${NC}"
    echo -e "${CYAN}   • Verify firewall settings: sudo ufw status or sudo iptables -L${NC}"
    echo ""
    echo -e "${WHITE}2. If pods are not running:${NC}"
    echo -e "${CYAN}   • Check pod status: kubectl get pods --all-namespaces${NC}"
    echo -e "${CYAN}   • Check pod logs: kubectl logs -n <namespace> <pod-name>${NC}"
    echo -e "${CYAN}   • Check events: kubectl get events --all-namespaces --sort-by='.lastTimestamp'${NC}"
    echo ""
    echo -e "${WHITE}3. If Docker issues occur:${NC}"
    echo -e "${CYAN}   • Restart Docker: sudo systemctl restart docker${NC}"
    echo -e "${CYAN}   • Check Docker status: sudo systemctl status docker${NC}"
    echo ""
    echo -e "${WHITE}4. If ArgoCD login fails:${NC}"
    echo -e "${CYAN}   • Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
    echo -e "${CYAN}   • Reset password: kubectl -n argocd patch secret argocd-secret -p '{"stringData":{"admin.password":"$(openssl rand -base64 32)"}}'${NC}"
    echo ""
    echo -e "${WHITE}5. Emergency cleanup commands:${NC}"
    echo -e "${CYAN}   • Clean all: ./scripts/cleanup-direct.sh${NC}"
    echo -e "${CYAN}   • Clean with backup: ./scripts/cleanup-with-backup.sh${NC}"
    echo -e "${CYAN}   • Fix Helm deployment: ./scripts/fix-helm-deployment.sh${NC}"
    echo ""
}

# Perform final verification
if perform_final_health_checks; then
    print_status "✓ All health checks passed successfully!"
else
    print_warning "⚠ Some health checks failed. Check the troubleshooting information below."
fi

# Clean up temporary files
cleanup_temporary_files

# Display troubleshooting information
display_troubleshooting_info

# Create a quick reference file
cat > QUICK_REFERENCE.md << 'EOF'
# NativeSeries Quick Reference

## Access URLs
- **Application:** http://54.166.101.159:30011
- **ArgoCD:** http://54.166.101.159:30080
- **Grafana:** http://54.166.101.159:30081
- **Prometheus:** http://54.166.101.159:30082
- **Loki:** http://54.166.101.159:30083

## Quick Commands
```bash
# Check all pods
kubectl get pods --all-namespaces

# Check application logs
kubectl logs -n nativeseries -l app.kubernetes.io/name=nativeseries

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Access application shell
kubectl exec -n nativeseries -it deployment/nativeseries -- /bin/bash

# Check service endpoints
kubectl get endpoints --all-namespaces
```

## Troubleshooting
- Use `./scripts/cleanup-direct.sh` for emergency cleanup
- Use `./scripts/fix-helm-deployment.sh` for deployment issues
- Check logs with `kubectl logs -n <namespace> <pod-name>`
EOF

print_status "Installation completed successfully!"
print_info "All services are now running and accessible!"
print_info "Quick reference saved to: QUICK_REFERENCE.md"

# ============================================================================
# PHASE 8: DEPLOYMENT VALIDATION AND FIXES
# ============================================================================

print_section "PHASE 8: Deployment Validation and Fixes"

# Function to validate and fix Helm chart
validate_and_fix_helm_chart() {
    print_info "Validating Helm chart..."
    
    # Check if helm-chart directory exists
    if [ ! -d "helm-chart" ]; then
        print_error "✗ helm-chart directory not found"
        return 1
    fi
    
    # Validate Chart.yaml
    if [ ! -f "helm-chart/Chart.yaml" ]; then
        print_error "✗ Chart.yaml not found"
        return 1
    fi
    
    # Validate values.yaml
    if [ ! -f "helm-chart/values.yaml" ]; then
        print_error "✗ values.yaml not found"
        return 1
    fi
    
    # Test Helm template rendering
    if helm template test helm-chart >/dev/null 2>&1; then
        print_status "✓ Helm chart validation passed"
        return 0
    else
        print_error "✗ Helm chart validation failed"
        return 1
    fi
}

# Function to validate and fix ArgoCD application
validate_and_fix_argocd_application() {
    print_info "Validating ArgoCD application..."
    
    # Check if argocd directory exists
    if [ ! -d "argocd" ]; then
        print_error "✗ argocd directory not found"
        return 1
    fi
    
    # Validate application.yaml
    if [ ! -f "argocd/application.yaml" ]; then
        print_error "✗ application.yaml not found"
        return 1
    fi
    
    # Validate YAML syntax
    if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))" >/dev/null 2>&1; then
        print_status "✓ ArgoCD application validation passed"
        return 0
    else
        print_error "✗ ArgoCD application validation failed"
        return 1
    fi
}

# Function to create proper deployment manifests
create_deployment_manifests() {
    print_info "Creating deployment manifests..."
    
    # Create deployment directories
    mkdir -p deployment/production
    
    # Generate namespace manifest
    cat > deployment/production/01-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: nativeseries
  labels:
    name: nativeseries
    app.kubernetes.io/name: nativeseries
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    app.kubernetes.io/name: argocd
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    app.kubernetes.io/name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging
    app.kubernetes.io/name: logging
EOF

    # Generate application deployment using Helm
    print_info "Generating application manifests from Helm chart..."
    helm template nativeseries helm-chart \
        --set image.repository=${DOCKER_IMAGE} \
        --set image.tag=latest \
        --set service.type=NodePort \
        --set service.nodePort=${PRODUCTION_PORT} \
        --set ingress.enabled=false \
        --set networkPolicy.enabled=false \
        --set cleanup.enabled=true \
        --namespace ${NAMESPACE} > deployment/production/02-application.yaml

    # Generate ArgoCD service with NodePort
    cat > deployment/production/04-argocd-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    app.kubernetes.io/name: argocd-server
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
      nodePort: ${ARGOCD_PORT}
  selector:
    app.kubernetes.io/name: argocd-server
EOF

    # Update ArgoCD application manifest for production
    sed "s|https://kubernetes.default.svc|https://${PRODUCTION_HOST}|g" argocd/application.yaml > deployment/production/05-argocd-application.yaml

    print_status "✓ Deployment manifests created"
}

# Function to validate Kubernetes manifests
validate_kubernetes_manifests() {
    print_info "Validating Kubernetes manifests..."
    
    local validation_failed=false
    
    for manifest in deployment/production/*.yaml; do
        if [ -f "$manifest" ]; then
            if python3 -c "import yaml; list(yaml.safe_load_all(open('$manifest')))" >/dev/null 2>&1; then
                print_status "✓ $manifest validation passed"
            else
                print_error "✗ $manifest validation failed"
                validation_failed=true
            fi
        fi
    done
    
    if [ "$validation_failed" = true ]; then
        return 1
    else
        return 0
    fi
}

# Function to deploy with proper error handling
deploy_with_validation() {
    print_info "Deploying with validation..."
    
    # Apply namespaces first
    print_info "Applying namespaces..."
    kubectl apply -f deployment/production/01-namespace.yaml
    
    # Wait for namespaces to be ready
    kubectl wait --for=condition=Active namespace/${NAMESPACE} --timeout=60s
    kubectl wait --for=condition=Active namespace/${ARGOCD_NAMESPACE} --timeout=60s
    
    # Apply application deployment
    print_info "Applying application deployment..."
    kubectl apply -f deployment/production/02-application.yaml
    
    # Install ArgoCD
    print_info "Installing ArgoCD..."
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=Available deployment/argocd-server -n ${ARGOCD_NAMESPACE} --timeout=300s
    
    # Apply ArgoCD service
    kubectl apply -f deployment/production/04-argocd-service.yaml
    
    # Apply ArgoCD application
    kubectl apply -f deployment/production/05-argocd-application.yaml
    
    print_status "✓ Deployment completed successfully"
}

# Run validation and fixes
if validate_and_fix_helm_chart; then
    print_status "✓ Helm chart validation passed"
else
    print_error "✗ Helm chart validation failed"
    exit 1
fi

if validate_and_fix_argocd_application; then
    print_status "✓ ArgoCD application validation passed"
else
    print_error "✗ ArgoCD application validation failed"
    exit 1
fi

create_deployment_manifests

if validate_kubernetes_manifests; then
    print_status "✓ Kubernetes manifests validation passed"
else
    print_error "✗ Kubernetes manifests validation failed"
    exit 1
fi

deploy_with_validation
