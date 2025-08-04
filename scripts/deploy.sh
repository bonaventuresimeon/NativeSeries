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
APP_NAME="NativeSeries"
NAMESPACE="NativeSeries"
ARGOCD_NAMESPACE="argocd"
PRODUCTION_HOST="${PRODUCTION_HOST:-54.166.101.15}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
DOCKER_USERNAME="${DOCKER_USERNAME:-biwunor}"
DOCKER_IMAGE="${DOCKER_USERNAME:+$DOCKER_USERNAME/}NativeSeries"
PYTHON_VERSION="3.11"
ARGOCD_VERSION="v2.9.3"

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
    print_status "Installing tools on Amazon Linux..."
    sudo yum update -y
    sudo yum install -y \
        git \
        curl \
        wget \
        jq \
        tree \
        htop \
        net-tools \
        python3 \
        python3-pip \
        gcc \
        make
}

install_tools_ubuntu() {
    print_status "Installing tools on Ubuntu/Debian..."
    sudo apt-get update
    sudo apt-get install -y \
        git \
        curl \
        wget \
        jq \
        tree \
        htop \
        net-tools \
        python3 \
        python3-pip \
        build-essential
}

# Kubernetes tools installation
install_k8s_tools() {
    print_header "☸️ Installing Kubernetes Tools"
    
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
    
    # Install Kind
    if ! command_exists kind; then
        print_status "Installing Kind..."
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
        sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
        rm kind
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    print_status "✅ Kubernetes tools installed successfully"
}

# Main deployment function
deploy_application() {
    print_header "🚀 Deploying NativeSeries Application"
    
    print_status "Target: $PRODUCTION_HOST:$PRODUCTION_PORT"
    print_status "Docker Image: $DOCKER_IMAGE"
    
    # Build and push Docker image
    print_status "Building Docker image..."
    docker build -t $DOCKER_IMAGE:latest .
    
    print_status "Pushing Docker image..."
    docker push $DOCKER_IMAGE:latest
    
    # Deploy to Kubernetes
    print_status "Deploying to Kubernetes..."
    kubectl apply -f helm-chart/
    
    print_status "✅ Application deployed successfully!"
    print_status "Access your application at: http://$PRODUCTION_HOST:$PRODUCTION_PORT"
}

# Main execution
main() {
    print_header "NativeSeries Deployment"
    
    # Install dependencies
    install_docker
    install_tools
    install_k8s_tools
    
    # Deploy application
    deploy_application
    
    print_status "🎉 Deployment completed successfully!"
}

# Run main function
main "$@"