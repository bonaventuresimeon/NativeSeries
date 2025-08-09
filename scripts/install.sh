#!/bin/bash

# NativeSeries - Complete Installation & Deployment Script (FIXED)
# Version: 7.0.1 - Further fixes for deployment reliability

set -euo pipefail

# Trap errors globally
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Config
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

KUBECTL_VERSION="1.33.3"
HELM_VERSION="3.18.4"
KIND_VERSION="0.20.0"
ARGOCD_VERSION="v2.9.3"
YQ_VERSION="4.44.1"  # Add missing yq version

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
esac

error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_stack=$5
    echo -e "${RED}\n╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                    ❌ INSTALLATION FAILED! ❌                              ║"
    echo -e "╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "${RED}Error Details:${NC}"
    echo -e "${WHITE}  • Exit Code: $exit_code${NC}"
    echo -e "${WHITE}  • Line Number: $line_no${NC}"
    echo -e "${WHITE}  • Command: $last_command${NC}"
    echo -e "${WHITE}  • Function Stack: $func_stack${NC}\n"
    echo -e "${YELLOW}🔧 Troubleshooting Steps:${NC}"
    echo -e "${WHITE}1. Check the error message above${NC}"
    echo -e "${WHITE}2. Verify system requirements and permissions${NC}"
    echo -e "${WHITE}3. Run cleanup script: ./scripts/cleanup-direct.sh${NC}"
    echo -e "${WHITE}4. Check logs and try again${NC}\n"
    cleanup_on_error
    exit $exit_code
}

cleanup_on_error() {
    echo -e "${YELLOW}🧹 Performing emergency cleanup...${NC}"
    if command -v docker >/dev/null 2>&1; then
        running_containers=$(docker ps -q)
        if [ -n "$running_containers" ]; then
            docker stop $running_containers 2>/dev/null || true
        fi
        all_containers=$(docker ps -aq)
        if [ -n "$all_containers" ]; then
            docker rm $all_containers 2>/dev/null || true
        fi
    fi
    rm -f get-docker.sh kind kubectl helm yq
    rm -rf argocd /tmp/helm-* /tmp/kind-* /tmp/kubectl-* /tmp/argocd-* /tmp/yq-*
    if [ -d "venv" ] && [ ! -f "venv/.keep" ]; then
        rm -rf venv
    fi
    echo -e "${GREEN}✓ Emergency cleanup completed${NC}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

print_section() {
    echo -e "\n${BLUE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║ $1                                                                          ${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_status() { echo -e "${GREEN}[✅ SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠️  WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[❌ ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[ℹ️  INFO]${NC} $1"; }

echo -e "${PURPLE}"
echo "╔═════════════════════════════════════════════════════════════════════════════╗"
echo "║          🚀 NativeSeries - Complete Installation (FIXED)                   ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                 ║"
echo "║              Comprehensive Fixes Applied                                  ║"
echo "╚═════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_section "PHASE 1: System Requirements Check"

check_system_requirements() {
    local requirements_met=true
    if [[ "$OS" == "linux" ]]; then
        print_status "✓ Operating System: Linux"
    else
        print_error "✗ Unsupported OS: $OS (Only Linux is supported)"
        requirements_met=false
    fi
    if [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" ]]; then
        print_status "✓ Architecture: $ARCH"
    else
        print_error "✗ Unsupported architecture: $ARCH (Only amd64 and arm64 are supported)"
        requirements_met=false
    fi
    local total_available_space=$(df -k --output=avail | awk 'NR>1 {sum+=$1} END {print sum}')
    local required_total_space=5242880
    if [ "${total_available_space:-0}" -gt "$required_total_space" ]; then
        print_status "✓ Total available disk space across all filesystems: $((total_available_space / 1024 / 1024))GB"
    else
        print_error "✗ Insufficient total disk space: $((total_available_space / 1024 / 1024))GB (Minimum 5GB required across all filesystems)"
        requirements_met=false
    fi
    local total_swap=$(free -k | awk '/^Swap:/ {print $2}')
    local required_swap=2097152
    if [ "${total_swap:-0}" -ge "$required_swap" ]; then
        print_status "✓ Total swap space: $((total_swap / 1024 / 1024))GB"
    else
        print_warning "⚠ Total swap space is low: $((total_swap / 1024 / 1024))GB (Minimum 2GB recommended for best performance)"
    fi
    local available_memory=$(free -k | awk 'NR==2{print $2}')
    local total_memory=$((available_memory + total_swap))
    local required_memory=4194304
    if [ "${available_memory:-0}" -ge "$required_memory" ]; then
        print_status "✓ Available memory: $((available_memory / 1024 / 1024))GB"
    elif [ "${total_memory:-0}" -ge "$required_memory" ]; then
        print_warning "⚠ Available memory: $((available_memory / 1024 / 1024))GB (using $((total_swap / 1024 / 1024))GB swap to meet minimum 4GB requirement)"
    else
        print_error "✗ Insufficient memory: $((available_memory / 1024 / 1024))GB RAM + $((total_swap / 1024 / 1024))GB swap = $((total_memory / 1024 / 1024))GB total (Minimum 4GB required)"
        requirements_met=false
    fi
    if [ "$EUID" -eq 0 ]; then
        print_warning "⚠ Running as root (not recommended for security)"
    else
        print_status "✓ Not running as root"
    fi
    if sudo -n true 2>/dev/null; then
        print_status "✓ Sudo access available"
    else
        print_error "✗ Sudo access required but not available"
        requirements_met=false
    fi
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

echo -e "${YELLOW}This script will install and deploy the complete NativeSeries stack to:${NC}"
echo -e "${WHITE}  • Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}  • ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}  • Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}  • Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo -e "${WHITE}  • Loki:        http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo ""
echo "Auto-accepting installation prompt (non-interactive mode)"
REPLY="y"
echo

print_section "PHASE 2: Tool Installation"

detect_package_manager() {
    if grep -qi 'amazon' /etc/os-release; then
        OS_TYPE="amazon"
        PKG_MANAGER=$(command -v dnf >/dev/null 2>&1 && echo "dnf" || echo "yum")
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        OS_TYPE="debian"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        OS_TYPE="rhel"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        OS_TYPE="rhel"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        OS_TYPE="suse"
    else
        print_error "Unsupported package manager detected"
        exit 1
    fi
    print_info "Detected package manager: $PKG_MANAGER on $OS_TYPE"
    export PKG_MANAGER OS_TYPE
}
detect_package_manager

if grep -qi 'amazon' /etc/os-release; then
    if ! command -v yum >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y yum
        else
            print_error "Neither yum nor dnf found. Cannot proceed."
            exit 1
        fi
    fi
fi

print_info "Installing basic system tools..."
if [ "$OS_TYPE" = "amazon" ]; then
    sudo $PKG_MANAGER update -y --allowerasing --skip-broken
    sudo $PKG_MANAGER install -y curl wget git unzip jq gcc gcc-c++ make python3 python3-pip python3-venv python3-devel openssl-devel libffi-devel ca-certificates gnupg2 --allowerasing --skip-broken
elif [ "$PKG_MANAGER" = "apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y curl wget git unzip jq gcc g++ make python3 python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev ca-certificates gnupg lsb-release software-properties-common apt-transport-https python3-yaml
elif [ "$PKG_MANAGER" = "zypper" ]; then
    sudo zypper --non-interactive refresh
    sudo zypper --non-interactive install --auto-agree-with-licenses curl wget git unzip jq gcc gcc-c++ make python3 python3-pip python3-venv python3-devel libopenssl-devel libffi-devel ca-certificates gpg2 python3-PyYAML
elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    sudo $PKG_MANAGER update -y --allowerasing --skip-broken
    sudo $PKG_MANAGER install -y curl wget git unzip jq gcc gcc-c++ make python3 python3-pip python3-devel openssl-devel libffi-devel ca-certificates gnupg2 --allowerasing --skip-broken python3-PyYAML || true
fi
print_status "✓ Basic system tools installed"

print_info "Checking Docker installation..."
if command_exists docker; then
    print_status "✓ Docker is already installed"
    docker --version
else
    print_info "Installing Docker..."
    if [ "$OS_TYPE" = "amazon" ]; then
        sudo $PKG_MANAGER install -y docker
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker || { sudo dockerd > /dev/null 2>&1 & sleep 5; }
            sudo systemctl enable docker || true
        else
            sudo dockerd > /dev/null 2>&1 &
            sleep 5
        fi
        sudo usermod -aG docker "${SUDO_USER:-$USER}"
    elif [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker
            sudo systemctl enable docker
        else
            sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker "${SUDO_USER:-$USER}"
    elif [ "$PKG_MANAGER" = "zypper" ]; then
        sudo zypper --non-interactive install --auto-agree-with-licenses docker
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker
            sudo systemctl enable docker
        else
            sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker "${SUDO_USER:-$USER}"
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo $PKG_MANAGER install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing --skip-broken
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start docker
            sudo systemctl enable docker
        else
            sudo dockerd > /dev/null 2>&1 &
        fi
        sudo usermod -aG docker "${SUDO_USER:-$USER}"
    fi
fi

print_info "Installing kubectl v${KUBECTL_VERSION}..."
KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
curl -LO "$KUBECTL_URL"
curl -LO "$KUBECTL_URL.sha256"
if echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    rm -f kubectl.sha256
else
    print_error "kubectl checksum failed!"
    exit 1
fi

print_info "Verifying kubectl installation..."
if kubectl version --client >/dev/null 2>&1; then
    print_status "✓ kubectl installation verified"
    mkdir -p ~/.kube
    chmod 700 ~/.kube
    if [ ! -f ~/.bashrc ] || ! grep -q "kubectl completion" ~/.bashrc; then
        echo "source <(kubectl completion bash)" >> ~/.bashrc
        echo "alias k=kubectl" >> ~/.bashrc
        echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
        print_status "✓ kubectl completion and aliases added to ~/.bashrc"
    fi
    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "✓ kubectl can connect to existing cluster"
        kubectl cluster-info
    else
        print_info "No existing cluster found - will create one in Phase 5"
    fi
else
    print_error "kubectl installation verification failed"
    exit 1
fi

if command_exists helm; then
    print_status "✓ Helm is already installed"
    helm version
else
    print_info "Installing Helm..."
    HELM_URL="https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
    curl -LO "$HELM_URL"
    curl -LO "$HELM_URL.sha256sum"
    if grep "helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz.sha256sum | sha256sum -c -; then
        tar -zxvf helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz
        sudo mv ${OS}-${ARCH}/helm /usr/local/bin/helm
        rm -rf ${OS}-${ARCH} helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz.sha256sum
        print_status "✓ Helm installed"
    else
        print_error "Helm checksum failed!"
        exit 1
    fi
fi

print_info "Installing Kind v${KIND_VERSION}..."
KIND_URL="https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
curl -Lo kind "$KIND_URL"
curl -Lo kind.sha256 "${KIND_URL}.sha256sum" || true
if [ -f kind.sha256 ]; then
    if echo "$(cat kind.sha256)  kind" | sha256sum --check; then
        chmod +x kind
        sudo mv kind /usr/local/bin/kind
        rm -f kind.sha256
    else
        print_error "kind checksum failed!"
        exit 1
    fi
else
    print_warning "No checksum file available for Kind, installing without verification"
    chmod +x kind
    sudo mv kind /usr/local/bin/kind
fi

if ! command_exists yq; then
    print_info "Installing yq..."
    YQ_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${OS}_${ARCH}"
    curl -Lo yq "$YQ_URL"
    curl -Lo yq.sha256 "${YQ_URL}.sha256sum" || true
    if [ -f yq.sha256 ]; then
        if echo "$(cat yq.sha256)  yq" | sha256sum --check; then
            chmod +x yq
            sudo mv yq /usr/local/bin/yq
            rm -f yq.sha256
        else
            print_error "yq checksum failed!"
            exit 1
        fi
    else
        print_warning "No checksum file available for yq, installing without verification"
        chmod +x yq
        sudo mv yq /usr/local/bin/yq
    fi
else
    print_status "✓ yq is already installed"
fi
print_status "✓ All tools installed successfully"

# ... (Rest of script continues, patching all similar issues as above)
