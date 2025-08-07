#!/bin/bash

# NativeSeries - Complete Installation & Deployment Script (RESTRUCTURED)
# Version: 7.0.0 - Comprehensive fixes for all deployment issues
# This script fixes cluster, namespace, manifests, and resource application issues

set -euo pipefail

# Global error handling
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Production Configuration
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

# Get OS information
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture
case "${ARCH}" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
esac

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
    rm -f get-docker.sh kind kubectl helm yq
    rm -rf argocd
    rm -rf /tmp/helm-* /tmp/kind-* /tmp/kubectl-* /tmp/argocd-* /tmp/yq-*
    
    # Clean up virtual environment if it was created
    if [ -d "venv" ] && [ ! -f "venv/.keep" ]; then
        rm -rf venv
    fi
    
    echo -e "${GREEN}✓ Emergency cleanup completed${NC}"
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

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          🚀 NativeSeries - Complete Installation (FIXED)         ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                  ║"
echo "║              Comprehensive Fixes Applied                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# PHASE 1: SYSTEM REQUIREMENTS CHECK
# ============================================================================

print_section "PHASE 1: System Requirements Check"

# Function to check system requirements
check_system_requirements() {
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
    
    # Check available disk space (minimum 5GB on all mounted filesystems)
    local total_available_space=$(df -k --output=avail | awk 'NR>1 {sum+=$1} END {print sum}')
    local required_total_space=5242880  # 5GB in KB
    if [ "$total_available_space" -gt "$required_total_space" ]; then
        print_status "✓ Total available disk space across all filesystems: $((total_available_space / 1024 / 1024))GB"
    else
        print_error "✗ Insufficient total disk space: $((total_available_space / 1024 / 1024))GB (Minimum 5GB required across all filesystems)"
        requirements_met=false
    fi

    # Check total swap space (minimum 2GB recommended)
    local total_swap=$(free -k | awk '/^Swap:/ {print $2}')
    local required_swap=2097152  # 2GB in KB
    if [ "$total_swap" -ge "$required_swap" ]; then
        print_status "✓ Total swap space: $((total_swap / 1024 / 1024))GB"
    else
        print_warning "⚠ Total swap space is low: $((total_swap / 1024 / 1024))GB (Minimum 2GB recommended for best performance)"
    fi
    
    # Check available memory (minimum 4GB RAM + swap combined)
    local available_memory=$(free -k | awk 'NR==2{print $2}')
    local total_swap=$(free -k | awk '/^Swap:/ {print $2}')
    local total_memory=$((available_memory + total_swap))
    local required_memory=4194304  # 4GB in KB
    if [ "$available_memory" -ge "$required_memory" ]; then
        print_status "✓ Available memory: $((available_memory / 1024 / 1024))GB"
    elif [ "$total_memory" -ge "$required_memory" ]; then
        print_warning "⚠ Available memory: $((available_memory / 1024 / 1024))GB (using $((total_swap / 1024 / 1024))GB swap to meet minimum 4GB requirement)"
    else
        print_error "✗ Insufficient memory: $((available_memory / 1024 / 1024))GB RAM + $((total_swap / 1024 / 1024))GB swap = $((total_memory / 1024 / 1024))GB total (Minimum 4GB required)"
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

check_system_requirements

# Confirmation
echo -e "${YELLOW}This script will install and deploy the complete NativeSeries stack to:${NC}"
echo -e "${WHITE}  • Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}  • ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}  • Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}  • Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo -e "${WHITE}  • Loki:        http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo ""
# Auto-accept installation prompt for automation
echo "Auto-accepting installation prompt (non-interactive mode)"
REPLY="y"
echo
#if [[ ! $REPLY =~ ^[Yy]$ ]]; then
#    echo "Installation cancelled."
#    exit 0
#fi

# ============================================================================
# PHASE 2: TOOL INSTALLATION
# ============================================================================

print_section "PHASE 2: Tool Installation"

# Function to detect package manager and OS
detect_package_manager() {
    echo "DEBUG: Starting package manager detection..."
    if grep -qi 'amazon' /etc/os-release; then
        OS_TYPE="amazon"
        if command -v dnf >/dev/null 2>&1; then
            PKG_MANAGER="dnf"
            echo "DEBUG: Amazon Linux with dnf detected."
        else
            PKG_MANAGER="yum"
            echo "DEBUG: Amazon Linux with yum detected."
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        OS_TYPE="debian"
        echo "DEBUG: Found apt-get, setting PKG_MANAGER=apt"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        OS_TYPE="rhel"
        echo "DEBUG: Found yum, setting PKG_MANAGER=yum"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        OS_TYPE="rhel"
        echo "DEBUG: Found dnf, setting PKG_MANAGER=dnf"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        OS_TYPE="suse"
        echo "DEBUG: Found zypper, setting PKG_MANAGER=zypper"
    else
        print_error "Unsupported package manager detected"
        exit 1
    fi
    echo "DEBUG: Final PKG_MANAGER=$PKG_MANAGER, OS_TYPE=$OS_TYPE"
    print_info "Detected package manager: $PKG_MANAGER on $OS_TYPE"
    export PKG_MANAGER OS_TYPE
}

# Function to install binary tools
install_binary_tool() {
    local tool_name="$1"
    local version="$2"
    local download_url="$3"
    local binary_name="$4"
    
    if command_exists "$tool_name"; then
        print_status "✓ $tool_name is already installed"
        if [ "$tool_name" = "kubectl" ]; then
            echo "DEBUG: Running 'kubectl version --client --short'"
            kubectl version --client --short
        else
            echo "DEBUG: Running '$tool_name --version'"
            $tool_name --version
        fi
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
        if [ "$tool_name" = "kubectl" ]; then
            echo "DEBUG: Running 'kubectl version --client --short'"
            kubectl version --client --short
        else
            echo "DEBUG: Running '$tool_name --version'"
            $tool_name --version
        fi
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

# Add a function for checksum validation
validate_checksum() {
    local file="$1"
    local checksum_file="$2"
    if [ -f "$checksum_file" ]; then
        echo "  Verifying checksum for $file..."
        if echo "$(cat $checksum_file)  $file" | sha256sum --check; then
            rm -f "$checksum_file"
            return 0
        else
            echo "ERROR: $file checksum failed!" >&2
            return 1
        fi
    fi
    return 0
}

# Detect package manager first
detect_package_manager
echo "DEBUG: After detection, PKG_MANAGER=$PKG_MANAGER, OS_TYPE=$OS_TYPE"

# Ensure yum is installed on Amazon Linux before any downloads/installs
if grep -qi 'amazon' /etc/os-release; then
    if ! command -v yum >/dev/null 2>&1; then
        echo "[INFO] Installing yum on Amazon Linux..."
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y yum
        else
            echo "[ERROR] Neither yum nor dnf found. Cannot proceed." >&2
            exit 1
        fi
    fi
fi

# Install basic system tools
print_info "Installing basic system tools..."
echo "DEBUG: PKG_MANAGER=$PKG_MANAGER"
if [ "$OS_TYPE" = "amazon" ]; then
    echo "DEBUG: Using Amazon Linux system tools branch"
    sudo $PKG_MANAGER update -y --allowerasing --skip-broken
    sudo $PKG_MANAGER install -y \
        curl wget git unzip jq gcc gcc-c++ make \
        python3 python3-pip python3-venv python3-devel \
        openssl-devel libffi-devel \
        ca-certificates gnupg2 --allowerasing --skip-broken
elif [ "$PKG_MANAGER" = "apt" ]; then
    echo "DEBUG: Using apt-get branch"
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y \
        curl wget git unzip jq gcc g++ make \
        python3 python3-pip python3-venv python3-dev \
        build-essential libssl-dev libffi-dev \
        ca-certificates gnupg lsb-release \
        software-properties-common apt-transport-https
elif [ "$PKG_MANAGER" = "zypper" ]; then
    echo "DEBUG: Using zypper branch"
    sudo zypper --non-interactive refresh
    sudo zypper --non-interactive install --auto-agree-with-licenses \
        curl wget git unzip jq gcc gcc-c++ make \
        python3 python3-pip python3-venv python3-devel \
        libopenssl-devel libffi-devel \
        ca-certificates gpg2
elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    echo "DEBUG: Using $PKG_MANAGER branch"
    sudo $PKG_MANAGER update -y --allowerasing --skip-broken
    sudo $PKG_MANAGER install -y \
        curl wget git unzip jq gcc gcc-c++ make \
        python3 python3-pip python3-devel \
        openssl-devel libffi-devel \
        ca-certificates gnupg2 --allowerasing --skip-broken
fi
print_status "✓ Basic system tools installed"

# Install Docker
print_info "Checking Docker installation..."
if command_exists docker; then
    print_status "✓ Docker is already installed"
    echo "DEBUG: Running 'docker --version'"
    docker --version
else
    print_info "Installing Docker..."
    if [ "$OS_TYPE" = "amazon" ]; then
        echo "DEBUG: Installing Docker from default Amazon Linux repos"
        sudo $PKG_MANAGER install -y docker
        # Portable Docker start for non-systemd environments
        echo "Attempting to start Docker..."
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl start docker
          sudo systemctl enable docker
        else
          echo "systemctl not found, starting dockerd manually in background."
          sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker $USER
    elif [ "$PKG_MANAGER" = "apt" ]; then
        echo "DEBUG: Installing Docker using official Docker APT repo"
        sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        # Portable Docker start for non-systemd environments
        echo "Attempting to start Docker..."
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl start docker
          sudo systemctl enable docker
        else
          echo "systemctl not found, starting dockerd manually in background."
          sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker $USER
    elif [ "$PKG_MANAGER" = "zypper" ]; then
        echo "DEBUG: Installing Docker using official Docker repo for SUSE"
        sudo zypper --non-interactive install --auto-agree-with-licenses docker
        # Portable Docker start for non-systemd environments
        echo "Attempting to start Docker..."
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl start docker
          sudo systemctl enable docker
        else
          echo "systemctl not found, starting dockerd manually in background."
          sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker $USER
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        if grep -qi 'amazon' /etc/os-release; then
            echo "DEBUG: Detected Amazon Linux, installing docker from default repos"
            sudo $PKG_MANAGER install -y docker
            # Portable Docker start for non-systemd environments
            echo "Attempting to start Docker..."
            if command -v systemctl >/dev/null 2>&1; then
              sudo systemctl start docker
              sudo systemctl enable docker
            else
              echo "systemctl not found, starting dockerd manually in background."
              sudo dockerd > /dev/null 2>&1 &
            fi
            sudo usermod -aG docker $USER
        else
            echo "DEBUG: Installing Docker for RHEL/CentOS using official Docker repo"
            sudo $PKG_MANAGER install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing --skip-broken
            # Portable Docker start for non-systemd environments
            echo "Attempting to start Docker..."
            if command -v systemctl >/dev/null 2>&1; then
              sudo systemctl start docker
              sudo systemctl enable docker
            else
              echo "systemctl not found, starting dockerd manually in background."
              sudo dockerd > /dev/null 2>&1 &
            fi
            sudo usermod -aG docker $USER
        fi
    fi
fi

# Install kubectl
print_info "Installing kubectl v${KUBECTL_VERSION}..."
if [ "$OS_TYPE" = "amazon" ]; then
    echo "DEBUG: Installing kubectl via official binary for Amazon Linux"
    KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
    curl -LO "$KUBECTL_URL"
    curl -LO "$KUBECTL_URL.sha256"
    echo "  Verifying checksum..."
    if echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/kubectl
        rm -f kubectl.sha256
    else
        echo "ERROR: kubectl checksum failed!" >&2
        exit 1
    fi
elif [ "$PKG_MANAGER" = "apt" ]; then
    # Remove deprecated kubernetes-xenial/apt.kubernetes.io repo if present
    if [ -f /etc/apt/sources.list.d/kubernetes.list ]; then
      if grep -q "apt.kubernetes.io" /etc/apt/sources.list.d/kubernetes.list || grep -q "kubernetes-xenial" /etc/apt/sources.list.d/kubernetes.list; then
        echo "Removing deprecated kubernetes-xenial/apt.kubernetes.io repo from /etc/apt/sources.list.d/kubernetes.list"
        sudo rm /etc/apt/sources.list.d/kubernetes.list
      fi
    fi
    # Use new pkgs.k8s.io repo for kubectl (legacy apt.kubernetes.io is deprecated)
    K8S_MAJOR_MINOR=$(echo "$KUBECTL_VERSION" | cut -d. -f1,2)
    K8S_STABLE_VERSION="v$K8S_MAJOR_MINOR"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/$K8S_STABLE_VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_STABLE_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
elif [ "$PKG_MANAGER" = "zypper" ] || [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        if grep -qi 'amazon' /etc/os-release; then
            echo "DEBUG: Detected Amazon Linux, installing kubectl from default repo"
            sudo $PKG_MANAGER install -y kubectl
        else
            echo "DEBUG: Installing kubectl via official binary for $PKG_MANAGER"
            KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
            curl -LO "$KUBECTL_URL"
            curl -LO "$KUBECTL_URL.sha256"
            echo "  Verifying checksum..."
            if echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/kubectl
                rm -f kubectl.sha256
            else
                echo "ERROR: kubectl checksum failed!" >&2
                exit 1
            fi
        fi
    else
        echo "DEBUG: Installing kubectl via official binary for zypper"
        KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
        curl -LO "$KUBECTL_URL"
        curl -LO "$KUBECTL_URL.sha256"
        echo "  Verifying checksum..."
        if echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/kubectl
            rm -f kubectl.sha256
        else
            echo "ERROR: kubectl checksum failed!" >&2
            exit 1
        fi
    fi
else
    if command_exists kubectl; then
        current_version=""
        if kubectl version --client --short >/dev/null 2>&1; then
            current_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 | sed 's/v//')
        fi
        if [ "$current_version" = "$KUBECTL_VERSION" ]; then
            print_status "✓ kubectl v${KUBECTL_VERSION} is already installed"
            echo "DEBUG: Running 'kubectl version --client --short'"
            kubectl version --client --short
        else
            print_info "Updating kubectl from v${current_version} to v${KUBECTL_VERSION}..."
            install_binary_tool "kubectl" "$KUBECTL_VERSION" \
                "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
                "kubectl"
        fi
    else
        install_binary_tool "kubectl" "$KUBECTL_VERSION" \
            "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" \
            "kubectl"
    fi
fi

# Verify kubectl installation and setup
print_info "Verifying kubectl installation..."
if kubectl version --client >/dev/null 2>&1; then
    print_status "✓ kubectl installation verified"
    
    # Setup kubectl configuration directory
    mkdir -p ~/.kube
    chmod 700 ~/.kube
    
    # Create kubectl completion
    if [ ! -f ~/.bashrc ] || ! grep -q "kubectl completion" ~/.bashrc; then
        echo "source <(kubectl completion bash)" >> ~/.bashrc
        echo "alias k=kubectl" >> ~/.bashrc
        echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
        print_status "✓ kubectl completion and aliases added to ~/.bashrc"
    fi
    
    # Verify kubectl can connect to cluster (if one exists)
    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "✓ kubectl can connect to existing cluster"
        echo "DEBUG: Running 'kubectl cluster-info'"
        kubectl cluster-info
    else
        print_info "No existing cluster found - will create one in Phase 5"
    fi
else
    print_error "✗ kubectl installation verification failed"
    exit 1
fi

# Install Helm
if command_exists helm; then
    print_status "✓ Helm is already installed"
    echo "DEBUG: Running 'helm version'"
    helm version
else
    print_info "Installing Helm..."
    HELM_VERSION_LATEST="${HELM_VERSION:-$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
    HELM_URL="https://get.helm.sh/helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz"
    curl -LO "$HELM_URL"
    curl -LO "$HELM_URL.sha256sum"
    echo "  Verifying checksum..."
    grep "helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz" helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz.sha256sum | sha256sum -c -
    tar -zxvf helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz"
    sudo mv ${OS}-${ARCH}/helm /usr/local/bin/helm
    rm -rf ${OS}-${ARCH} helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz helm-v${HELM_VERSION_LATEST}-${OS}-${ARCH}.tar.gz.sha256sum
    print_status "✓ Helm installed"
fi

# Install Kind
KIND_VERSION_LATEST="${KIND_VERSION:-$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
KIND_URL="https://kind.sigs.k8s.io/dl/v${KIND_VERSION_LATEST}/kind-${OS}-${ARCH}"
curl -Lo kind "$KIND_URL"
curl -Lo kind.sha256 "${KIND_URL}.sha256sum" || true
if [ -f kind.sha256 ]; then
    echo "  Verifying checksum..."
    if echo "$(cat kind.sha256)  kind" | sha256sum --check; then
        chmod +x kind
        sudo mv kind /usr/local/bin/kind
        rm -f kind.sha256
    else
        echo "ERROR: kind checksum failed!" >&2
        exit 1
    fi
else
    chmod +x kind
    sudo mv kind /usr/local/bin/kind
fi

# Install yq
if ! command_exists yq; then
    YQ_VERSION_LATEST="${YQ_VERSION:-$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
    YQ_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION_LATEST}/yq_${OS}_${ARCH}"
    curl -Lo yq "$YQ_URL"
    curl -Lo yq.sha256 "${YQ_URL}.sha256sum" || true
    if [ -f yq.sha256 ]; then
        echo "  Verifying checksum..."
        if echo "$(cat yq.sha256)  yq" | sha256sum --check; then
            chmod +x yq
            sudo mv yq /usr/local/bin/yq
            rm -f yq.sha256
        else
            echo "ERROR: yq checksum failed!" >&2
            exit 1
        fi
    else
        chmod +x yq
        sudo mv yq /usr/local/bin/yq
    fi
fi

print_status "✓ All tools installed successfully"

# ============================================================================
# PHASE 3: APPLICATION SETUP
# ============================================================================

print_section "PHASE 3: Application Setup"

# Setup Python virtual environment
if [ ! -d "venv" ]; then
    print_info "Creating Python virtual environment..."
    python3 -m venv venv
    print_status "✓ Virtual environment created"
fi

# Install Python dependencies
print_info "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt || pip install fastapi uvicorn pymongo python-multipart jinja2 aiofiles httpx motor hvac python-jose passlib python-dotenv redis pytest pytest-asyncio black flake8 gunicorn psutil mangum
print_status "✓ Python dependencies installed"

# ============================================================================
# PHASE 4: DOCKER IMAGE BUILD
# ============================================================================

print_section "PHASE 4: Building Docker Image"

print_info "Building Docker image..."
sudo docker build -t ${DOCKER_IMAGE}:latest . --network=host
print_status "✓ Docker image built successfully"

# Test the application locally
print_info "Testing application locally..."
sudo docker run -d --name test-app -p 8001:8000 ${DOCKER_IMAGE}:latest
sleep 30

# Health check
if curl -s http://localhost:8001/health | grep -q "healthy"; then
    print_status "✓ Application health check passed"
else
    print_error "✗ Application health check failed"
    sudo docker logs test-app
    sudo docker stop test-app || true
    sudo docker rm test-app || true
    exit 1
fi

sudo docker stop test-app || true
sudo docker rm test-app || true

# ============================================================================
# PHASE 5: KUBERNETES CLUSTER SETUP
# ============================================================================

print_section "PHASE 5: Setting up Kubernetes Cluster"

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
    
    # Configure kubectl for the new cluster
    print_info "Configuring kubectl for Kind cluster..."
    sudo kind export kubeconfig --name gitops-cluster
    
    # Ensure proper permissions on kubeconfig
    if [ -f ~/.kube/config ]; then
        chmod 600 ~/.kube/config
        print_status "✓ kubectl configured for Kind cluster"
    else
        print_error "✗ Failed to configure kubectl for Kind cluster"
        exit 1
    fi
    
    print_status "✓ Kind cluster created successfully"
else
    print_status "✓ Using existing Kubernetes cluster"
fi

# Verify cluster connectivity
print_info "Verifying cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    print_status "✓ Successfully connected to Kubernetes cluster"
    echo "DEBUG: Running 'kubectl cluster-info'"
    kubectl cluster-info
else
    print_error "✗ Failed to connect to Kubernetes cluster"
    exit 1
fi

# Verify kubectl can access the cluster
print_info "Testing kubectl cluster access..."
if kubectl get nodes >/dev/null 2>&1; then
    print_status "✓ kubectl can access cluster nodes"
    echo "DEBUG: Running 'kubectl get nodes'"
    kubectl get nodes
else
    print_error "✗ kubectl cannot access cluster nodes"
    exit 1
fi

# Load Docker image into Kind cluster
if command -v kind >/dev/null 2>&1 && kind get clusters | grep -q gitops-cluster; then
    print_info "Loading Docker image into Kind cluster..."
    sudo kind load docker-image ${DOCKER_IMAGE}:latest --name gitops-cluster
    print_status "✓ Docker image loaded into cluster"
fi

# Verify cluster is ready for deployments
print_info "Verifying cluster readiness..."
if kubectl get nodes --no-headers | grep -q "Ready"; then
    ready_nodes=$(kubectl get nodes --no-headers | grep "Ready" | wc -l)
    total_nodes=$(kubectl get nodes --no-headers | wc -l)
    # Use printf instead of print_status for parentheses in message to avoid syntax error
    printf "%b\n" "${GREEN}[✅ SUCCESS]${NC} Cluster is ready ( [0m$ready_nodes/$total_nodes nodes ready)"
else
    print_warning "⚠ Cluster nodes may not be fully ready"
fi

# ============================================================================
# PHASE 6: MANIFEST VALIDATION AND FIXES
# ============================================================================

print_section "PHASE 6: Manifest Validation and Fixes"

# Function to validate and fix Helm chart
validate_and_fix_helm_chart() {
    print_info "Validating and fixing Helm chart..."
    
    # Check if helm-chart directory exists
    if [ ! -d "helm-chart" ]; then
        print_error "✗ helm-chart directory not found"
        return 1
    fi
    
    # Fix values.yaml
    print_info "Updating Helm values.yaml..."
    cat > helm-chart/values.yaml << 'EOF'
# Default values for nativeseries
app:
  name: nativeseries
  port: 8000
  env:
    - name: APP_ENV
      value: "production"
    - name: HOST
      value: "0.0.0.0"
    - name: PORT
      value: "8000"
    - name: LOG_LEVEL
      value: "INFO"

image:
  repository: ghcr.io/bonaventuresimeon/nativeseries
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 2

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

healthCheck:
  enabled: true
  path: /health
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

service:
  type: NodePort
  port: 80
  targetPort: 8000
  nodePort: 30011

ingress:
  enabled: false

configMap:
  enabled: true
  data:
    app_name: "NativeSeries API"
    log_level: "INFO"

secret:
  enabled: false
  data: {}

networkPolicy:
  enabled: false

argocd:
  enabled: false

podMonitor:
  enabled: false
  interval: 30s
  path: /metrics
  labels: {}

prometheusRules:
  enabled: false
  rules: []

logging:
  enabled: false
  volume:
    size: 1Gi

cleanup:
  enabled: true

podSecurityContext:
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 1000

nodeSelector: {}
tolerations: []
affinity: {}

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 1

serviceMonitor:
  enabled: false
  interval: 30s
  path: /metrics
EOF

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
    print_info "Validating and fixing ArgoCD application..."
    
    # Check if argocd directory exists
    if [ ! -d "argocd" ]; then
        print_error "✗ argocd directory not found"
        return 1
    fi
    
    # Fix application.yaml
    print_info "Updating ArgoCD application.yaml..."
    cat > argocd/application.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nativeseries
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argocd.argoproj.io
  labels:
    app.kubernetes.io/name: nativeseries
    app.kubernetes.io/part-of: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/bonaventuresimeon/nativeseries.git
    targetRevision: HEAD
    path: helm-chart
    helm:
      values: |
        image:
          repository: ${DOCKER_IMAGE}
          tag: latest
        service:
          type: NodePort
          nodePort: ${PRODUCTION_PORT}
        ingress:
          enabled: false
        networkPolicy:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    # Validate YAML syntax
    if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))" >/dev/null 2>&1; then
        print_status "✓ ArgoCD application validation passed"
        return 0
    else
        print_error "✗ ArgoCD application validation failed"
        return 1
    fi
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

# ============================================================================
# PHASE 7: DEPLOYMENT MANIFESTS CREATION
# ============================================================================

print_section "PHASE 7: Creating Deployment Manifests"

# Create deployment directories
mkdir -p deployment/production

# Generate namespace manifest
print_info "Creating namespace manifest..."
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
print_info "Creating ArgoCD service manifest..."
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
print_info "Creating ArgoCD application manifest..."
sed "s|https://kubernetes.default.svc|https://${PRODUCTION_HOST}|g" argocd/application.yaml > deployment/production/05-argocd-application.yaml

print_status "✓ Deployment manifests created"

# ============================================================================
# PHASE 8: MANIFEST VALIDATION
# ============================================================================

print_section "PHASE 8: Manifest Validation"

# Function to validate YAML files
validate_yaml_file() {
    local file="$1"
    if python3 -c "import yaml; list(yaml.safe_load_all(open('$file')))" >/dev/null 2>&1; then
        print_status "✓ $file validation passed"
        return 0
    else
        print_error "✗ $file validation failed"
        return 1
    fi
}

# Validate all manifests
print_info "Validating all manifests..."
validation_failed=false

for manifest in deployment/production/*.yaml; do
    if [ -f "$manifest" ]; then
        if ! validate_yaml_file "$manifest"; then
            validation_failed=true
        fi
    fi
done

if [ "$validation_failed" = true ]; then
    print_error "Some manifests failed validation. Please check the errors above."
    exit 1
fi

print_status "✓ All manifests validated successfully"

# ============================================================================
# PHASE 9: DEPLOYMENT EXECUTION
# ============================================================================

print_section "PHASE 9: Deploying Resources"

# Function to deploy with retry
deploy_with_retry() {
    local manifest="$1"
    local max_retries=3
    local retry_count=0
    
    print_info "Deploying $manifest..."
    
    while [ $retry_count -lt $max_retries ]; do
        if kubectl apply -f "$manifest"; then
            print_status "✓ Successfully applied $manifest"
            return 0
        else
            retry_count=$((retry_count + 1))
            print_warning "⚠ Failed to apply $manifest (attempt $retry_count/$max_retries)"
            
            # Show detailed error information
            print_info "Error details:"
            kubectl apply -f "$manifest" 2>&1 | head -10
            
            if [ $retry_count -lt $max_retries ]; then
                print_info "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    print_error "✗ Failed to apply $manifest after $max_retries attempts"
    return 1
}

# Function to verify kubectl is working
verify_kubectl() {
    print_info "Verifying kubectl functionality..."
    
    if ! kubectl version --client >/dev/null 2>&1; then
        print_error "✗ kubectl client is not working"
        return 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "✗ kubectl cannot connect to cluster"
        return 1
    fi
    
    if ! kubectl get nodes >/dev/null 2>&1; then
        print_error "✗ kubectl cannot access cluster nodes"
        return 1
    fi
    
    print_status "✓ kubectl is working correctly"
    return 0
}

# Function to troubleshoot kubectl issues
troubleshoot_kubectl() {
    print_info "🔧 Kubectl Troubleshooting Guide"
    echo ""
    echo -e "${YELLOW}Common kubectl issues and solutions:${NC}"
    echo ""
    echo -e "${WHITE}1. kubectl not found:${NC}"
    echo "   - Ensure kubectl is installed: which kubectl"
    echo "   - Check PATH: echo \$PATH"
    echo "   - Reinstall kubectl if needed"
    echo ""
    echo -e "${WHITE}2. Cannot connect to cluster:${NC}"
    echo "   - Check cluster status: kubectl cluster-info"
    echo "   - Verify kubeconfig: kubectl config view"
    echo "   - Check cluster is running: kind get clusters"
    echo ""
    echo -e "${WHITE}3. Permission denied:${NC}"
    echo "   - Check kubeconfig permissions: ls -la ~/.kube/config"
    echo "   - Fix permissions: chmod 600 ~/.kube/config"
    echo "   - Check user permissions: whoami"
    echo ""
    echo -e "${WHITE}4. Context issues:${NC}"
    echo "   - List contexts: kubectl config get-contexts"
    echo "   - Switch context: kubectl config use-context <context-name>"
    echo "   - Set context: kubectl config set-context --current --namespace=<namespace>"
    echo ""
    echo -e "${WHITE}5. Cluster not ready:${NC}"
    echo "   - Check nodes: kubectl get nodes"
    echo "   - Check node status: kubectl describe nodes"
    echo "   - Restart cluster: kind delete cluster && kind create cluster"
    echo ""
    echo -e "${WHITE}6. Resource issues:${NC}"
    echo "   - Check events: kubectl get events --all-namespaces"
    echo "   - Check pod logs: kubectl logs -n <namespace> <pod-name>"
    echo "   - Describe resources: kubectl describe <resource> <name> -n <namespace>"
    echo ""
    echo -e "${WHITE}7. Network issues:${NC}"
    echo "   - Check services: kubectl get services --all-namespaces"
    echo "   - Check endpoints: kubectl get endpoints --all-namespaces"
    echo "   - Test connectivity: kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup <service>"
    echo ""
}

# Function to check kubectl health
check_kubectl_health() {
    print_info "🏥 Checking kubectl health..."
    
    local health_status=true
    
    # Check kubectl installation
    if ! command_exists kubectl; then
        print_error "✗ kubectl is not installed"
        health_status=false
    else
        print_status "✓ kubectl is installed"
        echo "DEBUG: Running 'kubectl version --client --short'"
        kubectl version --client --short
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "✗ Cannot connect to cluster"
        health_status=false
    else
        print_status "✓ Cluster connectivity OK"
        echo "DEBUG: Running 'kubectl cluster-info'"
        kubectl cluster-info
    fi
    
    # Check node access
    if ! kubectl get nodes >/dev/null 2>&1; then
        print_error "✗ Cannot access cluster nodes"
        health_status=false
    else
        print_status "✓ Node access OK"
        echo "DEBUG: Running 'kubectl get nodes'"
        kubectl get nodes
    fi
    
    # Check kubeconfig
    if [ ! -f ~/.kube/config ]; then
        print_error "✗ kubeconfig file not found"
        health_status=false
    else
        print_status "✓ kubeconfig file exists"
        ls -la ~/.kube/config
    fi
    
    # Check context
    if ! kubectl config current-context >/dev/null 2>&1; then
        print_error "✗ No current context set"
        health_status=false
    else
        print_status "✓ Current context: $(kubectl config current-context)"
    fi
    
    if [ "$health_status" = false ]; then
        print_warning "⚠ kubectl health check failed"
        troubleshoot_kubectl
        return 1
    else
        print_status "✓ kubectl health check passed"
        return 0
    fi
}

# Function to setup kubectl context and namespaces
setup_kubectl_context() {
    print_info "🔧 Setting up kubectl context and namespaces..."
    
    # Get current context
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    print_info "Current context: $current_context"
    
    # List all contexts
    print_info "Available contexts:"
    kubectl config get-contexts
    
    # Set default namespace for current context
    if [ -n "$current_context" ]; then
        print_info "Setting default namespace for context: $current_context"
        kubectl config set-context --current --namespace=default
        
        # Create namespaces if they don't exist
        local namespaces=("$NAMESPACE" "$ARGOCD_NAMESPACE" "$MONITORING_NAMESPACE" "$LOGGING_NAMESPACE")
        
        for ns in "${namespaces[@]}"; do
            if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
                print_info "Creating namespace: $ns"
                kubectl create namespace "$ns"
            else
                print_status "✓ Namespace $ns already exists"
            fi
        done
        
        print_status "✓ kubectl context setup completed"
    else
        print_warning "⚠ No current context found"
        return 1
    fi
}

# Setup kubectl context before deployment
print_section "KUBECTL CONTEXT SETUP"
if ! setup_kubectl_context; then
    print_warning "⚠ kubectl context setup failed, but continuing..."
fi

# Add kubectl health check before deployment
print_section "KUBECTL HEALTH CHECK"
if ! check_kubectl_health; then
    print_error "kubectl health check failed. Please fix the issues above before proceeding."
    # Auto-accept continue prompt for automation
    echo "Auto-accepting continue prompt after kubectl health check failure (non-interactive mode)"
    REPLY="y"
    echo
    #if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #    exit 1
    #fi
fi

# Verify kubectl before starting deployment
if ! verify_kubectl; then
    print_error "kubectl verification failed. Cannot proceed with deployment."
    exit 1
fi

# Deploy namespaces first
print_info "Deploying namespaces..."
if ! deploy_with_retry "deployment/production/01-namespace.yaml"; then
    print_error "Failed to deploy namespaces. Cannot proceed."
    exit 1
fi

# Wait for namespaces to be ready
print_info "Waiting for namespaces to be ready..."
if ! kubectl wait --for=condition=Active namespace/${NAMESPACE} --timeout=60s; then
    print_error "Namespace ${NAMESPACE} failed to become active"
    kubectl describe namespace ${NAMESPACE}
    exit 1
fi

if ! kubectl wait --for=condition=Active namespace/${ARGOCD_NAMESPACE} --timeout=60s; then
    print_error "Namespace ${ARGOCD_NAMESPACE} failed to become active"
    kubectl describe namespace ${ARGOCD_NAMESPACE}
    exit 1
fi

print_status "✓ All namespaces are active"

# --- Ensure Helm, Prometheus, Grafana, Loki are installed and running ---

# Ensure Helm is installed
if ! command_exists helm; then
    print_info "Helm not found. Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    print_status "✓ Helm is already installed"
fi

# Ensure Prometheus, Grafana, Loki Helm repos are added
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo add loki https://grafana.github.io/loki/charts || true
helm repo update

# --- Create dedicated namespace and set context ---
APP_NAMESPACE="nativeseries"
if ! kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1; then
    print_info "Creating namespace: $APP_NAMESPACE"
    kubectl create namespace "$APP_NAMESPACE"
else
    print_status "✓ Namespace $APP_NAMESPACE already exists"
fi
kubectl config set-context --current --namespace="$APP_NAMESPACE"

# --- Deploy Prometheus ---
if ! helm list -n "$APP_NAMESPACE" | grep -q prometheus; then
    print_info "Deploying Prometheus via Helm..."
    helm install prometheus prometheus-community/prometheus --namespace "$APP_NAMESPACE" --set server.service.type=NodePort --set server.service.nodePort=30082
else
    print_status "✓ Prometheus already deployed"
fi

# --- Deploy Grafana ---
if ! helm list -n "$APP_NAMESPACE" | grep -q grafana; then
    print_info "Deploying Grafana via Helm..."
    helm install grafana grafana/grafana --namespace "$APP_NAMESPACE" --set service.type=NodePort --set service.nodePort=30081 --set adminPassword='admin' --set persistence.enabled=false
else
    print_status "✓ Grafana already deployed"
fi

# --- Deploy Loki ---
if ! helm list -n "$APP_NAMESPACE" | grep -q loki; then
    print_info "Deploying Loki via Helm..."
    helm install loki grafana/loki --namespace "$APP_NAMESPACE" --set service.type=NodePort --set service.nodePort=30083
else
    print_status "✓ Loki already deployed"
fi

# --- Deploy Application via Helm chart ---
if [ -d helm-chart ]; then
    print_info "Deploying application Helm chart with all features enabled..."
    helm upgrade --install nativeseries ./helm-chart --namespace "$APP_NAMESPACE" -f ./helm-chart/values.yaml
else
    print_error "Helm chart directory not found. Skipping application deployment."
fi

# --- Expose DNS and port info ---
print_info "Service Endpoints:"
APP_NODEPORT=$(kubectl get svc -n $APP_NAMESPACE nativeseries -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo '30011')
PROM_NODEPORT=$(kubectl get svc -n $APP_NAMESPACE prometheus-server -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo '30082')
GRAFANA_NODEPORT=$(kubectl get svc -n $APP_NAMESPACE grafana -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo '30081')
LOKI_NODEPORT=$(kubectl get svc -n $APP_NAMESPACE loki -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo '30083')
APP_INGRESS=$(kubectl get ingress -n $APP_NAMESPACE nativeseries -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo 'nativeseries.local')
echo "Application NodePort: http://<node-ip>:${APP_NODEPORT}"
echo "Application Ingress: http://${APP_INGRESS}"
echo "Prometheus NodePort: http://<node-ip>:${PROM_NODEPORT}"
echo "Grafana NodePort: http://<node-ip>:${GRAFANA_NODEPORT}"
echo "Loki NodePort: http://<node-ip>:${LOKI_NODEPORT}"

# Deploy application
print_info "Deploying application..."
if ! deploy_with_retry "deployment/production/02-application.yaml"; then
    print_error "Failed to deploy application. Checking for issues..."
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
    exit 1
fi

# Install ArgoCD
print_info "Installing ArgoCD..."
if ! kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml; then
    print_error "Failed to install ArgoCD"
    exit 1
fi

# Wait for ArgoCD to be ready
print_info "Waiting for ArgoCD to be ready..."
if ! kubectl wait --for=condition=Available deployment/argocd-server -n ${ARGOCD_NAMESPACE} --timeout=300s; then
    print_error "ArgoCD failed to become available"
    kubectl get pods -n ${ARGOCD_NAMESPACE}
    kubectl describe deployment argocd-server -n ${ARGOCD_NAMESPACE}
    exit 1
fi

# Deploy ArgoCD service
print_info "Deploying ArgoCD service..."
if ! deploy_with_retry "deployment/production/04-argocd-service.yaml"; then
    print_error "Failed to deploy ArgoCD service"
    exit 1
fi

# Deploy ArgoCD application
print_info "Deploying ArgoCD application..."
if ! deploy_with_retry "deployment/production/05-argocd-application.yaml"; then
    print_error "Failed to deploy ArgoCD application"
    exit 1
fi

print_status "✓ All resources deployed successfully"

# Verify all deployments
print_info "Verifying all deployments..."
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces
kubectl get pods --all-namespaces

# ============================================================================
# PHASE 10: VERIFICATION AND MONITORING
# ============================================================================

print_section "PHASE 10: Verification and Monitoring"

# Function to wait for pods
wait_for_pods() {
    local namespace="$1"
    local label_selector="$2"
    local timeout=300
    local interval=10
    
    print_info "Waiting for pods in namespace $namespace..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if kubectl get pods -n "$namespace" -l "$label_selector" --no-headers | grep -q "Running"; then
            local ready_pods=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers | grep "Running" | wc -l)
            local total_pods=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers | wc -l)
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

# Function to test application health
test_application_health() {
    local url="$1"
    local service_name="$2"
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
wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=$APP_NAME"

# Wait for ArgoCD pods
wait_for_pods "$ARGOCD_NAMESPACE" "app.kubernetes.io/name=argocd-server"

# Test application health
test_application_health "http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health" "NativeSeries Application"

# Test ArgoCD health
test_application_health "http://${PRODUCTION_HOST}:${ARGOCD_PORT}" "ArgoCD"

# Check service endpoints
print_info "Checking service endpoints..."
kubectl get endpoints --all-namespaces

# ============================================================================
# PHASE 11: FINAL SUMMARY
# ============================================================================

print_section "PHASE 11: Final Summary"

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

# Show current status
echo -e "${YELLOW}📊 Current Status:${NC}"
echo -e "${WHITE}   • Application Pods: $(kubectl get pods -n $NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • ArgoCD Pods:     $(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo ""

# Create a quick reference file
cat > QUICK_REFERENCE.md << 'EOF'
# NativeSeries Quick Reference

## Access URLs
- **Application:** http://54.166.101.159:30011
- **ArgoCD:** http://54.166.101.159:30080

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
- Check logs with `kubectl logs -n <namespace> <pod-name>`
EOF

print_status "Installation completed successfully!"
print_info "All services are now running and accessible!"
print_info "Quick reference saved to: QUICK_REFERENCE.md"
