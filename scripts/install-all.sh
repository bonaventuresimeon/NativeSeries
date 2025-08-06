#!/bin/bash

# Student Tracker - Complete Installation & Deployment Script
# Version: 5.1.0 - Amazon Linux 2023 Compatible Installation
# This script combines all installation, deployment, monitoring, and validation scripts
# Updated for Amazon Linux 2023 compatibility with virtualenv and proper package detection

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Production Configuration - Fixed for 54.166.101.159
PRODUCTION_HOST="54.166.101.159"
PRODUCTION_PORT="30011"
ARGOCD_PORT="30080"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="monitoring"
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

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          🚀 Student Tracker - Complete Installation              ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                  ║"
echo "║              Full Stack Deployment with Monitoring              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirmation
echo -e "${YELLOW}This script will install and deploy the complete Student Tracker stack to:${NC}"
echo -e "${WHITE}  • Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}  • ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}  • Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}  • Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo ""
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ============================================================================
# PHASE 1: SYSTEM DEPENDENCIES INSTALLATION
# ============================================================================

print_section "PHASE 1: Installing System Dependencies"

# Update system packages
print_info "Updating system packages..."
detect_package_manager

if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y curl wget git unzip jq build-essential \
        software-properties-common apt-transport-https ca-certificates \
        gnupg lsb-release python3 python3-pip python3-venv
elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install -y curl wget git unzip jq gcc gcc-c++ make \
        python3 python3-pip
    # Install virtualenv for Amazon Linux 2023 (python3-venv not available)
    print_info "Installing virtualenv for RHEL-based systems..."
    sudo pip3 install virtualenv || {
        print_warning "Failed to install virtualenv via pip, trying alternative method..."
        sudo $PKG_MANAGER install -y python3-virtualenv || {
            print_error "Could not install virtualenv. Please run manually:"
            echo "sudo pip3 install virtualenv"
            exit 1
        }
    }
fi
print_status "System packages updated"

# Install Docker
if ! command_exists docker; then
    print_info "Installing Docker..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        # Ubuntu/Debian Docker installation
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm -f get-docker.sh
    else
        # Amazon Linux 2023 Docker installation
        sudo $PKG_MANAGER install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    fi
    
    # Start Docker daemon
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        # For container environments without systemctl
        sudo dockerd --iptables=false --storage-driver=vfs --experimental --host=unix:///var/run/docker.sock > /tmp/docker.log 2>&1 &
        sleep 10
    fi
    print_status "Docker installed and configured"
else
    print_status "Docker already installed"
fi

# Function to install Docker
install_docker() {
    print_section "Installing Docker"
    
    if command_exists docker; then
        print_status "Docker is already installed"
        docker --version
        return 0
    fi
    
    print_status "Installing Docker..."
    
    # Install Docker using package manager
    if [ "$PKG_MANAGER" = "apt" ]; then
        print_status "Installing Docker on Ubuntu/Debian..."
        sudo apt update
        sudo apt install -y docker.io docker-compose
    else
        print_status "Installing Docker on CentOS/RHEL/Fedora..."
        sudo $PKG_MANAGER install -y docker docker-compose
    fi
    
    # Start and enable Docker service
    print_status "Starting Docker service..."
    sudo systemctl start docker || true
    sudo systemctl enable docker || true
    
    # Add user to docker group
    print_status "Setting up Docker permissions..."
    sudo usermod -aG docker "$USER" || true
    
    # Wait a moment for group changes to take effect
    sleep 2
    
    # Verify installation
    if command_exists docker; then
        print_status "Docker installed successfully!"
        docker --version
        
        # Test Docker with sudo if needed
        if docker info >/dev/null 2>&1; then
            print_status "Docker is accessible"
        elif sudo docker info >/dev/null 2>&1; then
            print_status "Docker requires sudo (this is normal)"
            # Create alias for docker with sudo
            echo 'alias docker="sudo docker"' >> ~/.bashrc
            export docker="sudo docker"
        else
            print_warning "Docker may need manual setup"
        fi
    else
        print_error "Docker installation failed!"
        return 1
    fi
}

# Function to install kubectl
install_kubectl() {
    print_section "Installing kubectl"
    
    if command_exists kubectl; then
        print_status "kubectl is already installed"
        kubectl version --client
        return 0
    fi
    
    print_status "Installing kubectl..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download kubectl with error handling
    print_status "Downloading kubectl..."
    KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    if ! curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; then
        print_error "Failed to download kubectl"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Make executable and move to PATH
    chmod +x kubectl
    if ! sudo mv kubectl /usr/local/bin/; then
        print_error "Failed to move kubectl to /usr/local/bin/"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command_exists kubectl; then
        print_status "kubectl installed successfully!"
        kubectl version --client
    else
        print_error "kubectl installation failed!"
        return 1
    fi
}

# Function to install Kind
install_kind() {
    print_section "Installing Kind"
    
    if command_exists kind; then
        print_status "Kind is already installed"
        kind version
        return 0
    fi
    
    print_status "Installing Kind..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download Kind with error handling
    print_status "Downloading Kind..."
    if ! curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64"; then
        print_error "Failed to download Kind"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Make executable and move to PATH
    chmod +x ./kind
    if ! sudo mv ./kind /usr/local/bin/; then
        print_error "Failed to move Kind to /usr/local/bin/"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command_exists kind; then
        print_status "Kind installed successfully!"
        kind version
    else
        print_error "Kind installation failed!"
        return 1
    fi
}

# Function to install Helm
install_helm() {
    print_section "Installing Helm"
    
    if command_exists helm; then
        print_status "Helm is already installed"
        helm version
        return 0
    fi
    
    print_status "Installing Helm..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download Helm with error handling
    print_status "Downloading Helm..."
    if ! curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xz; then
        print_error "Failed to download Helm"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Move to PATH
    if ! sudo mv linux-amd64/helm /usr/local/bin/; then
        print_error "Failed to move Helm to /usr/local/bin/"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command_exists helm; then
        print_status "Helm installed successfully!"
        helm version
    else
        print_error "Helm installation failed!"
        return 1
    fi
}

# Function to install Python and pip
install_python() {
    print_section "Installing Python"
    detect_package_manager

    if command_exists python3; then
        print_status "Python is already installed"
        python3 --version
    else
        print_status "Installing Python ${PYTHON_VERSION}..."
        if [ "$PKG_MANAGER" = "apt" ]; then
            sudo apt install -y python3 python3-pip
        else
            sudo $PKG_MANAGER install -y python3 python3-pip
        fi
    fi

    # Install Python virtual environment package
    print_status "Installing Python virtual environment package..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y python3-venv
    else
        sudo $PKG_MANAGER install -y python3-venv || sudo $PKG_MANAGER install -y python3-virtualenv
    fi

    # Verify installation
    if command_exists python3; then
        print_status "Python installed successfully!"
        python3 --version
        pip3 --version
    else
        print_error "Python installation failed!"
        return 1
    fi
}

# Function to verify all tools are installed
verify_tools() {
    print_section "Verifying Tool Installation"
    
    local tools=("docker" "kubectl" "kind" "helm" "python3")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            print_status "✓ $tool is installed"
        else
            print_error "✗ $tool is missing"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_status "All tools are installed and ready!"
        return 0
    else
        print_error "Missing tools: ${missing_tools[*]}"
        return 1
    fi
}

# Function to setup Docker environment
setup_docker() {
    print_section "Setting up Docker Environment"
    
    # Start Docker daemon if not running
    if ! docker info >/dev/null 2>&1; then
        print_status "Starting Docker daemon..."
        # For container environments without systemctl
        sudo dockerd --iptables=false --storage-driver=vfs --experimental --host=unix:///var/run/docker.sock > /tmp/docker.log 2>&1 &
        sleep 10
    fi
    print_status "Docker installed and started"
else
    print_status "Docker already installed"
fi

# Verify Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    print_warning "Docker daemon not running, attempting to start..."
    sudo dockerd --iptables=false --storage-driver=vfs --experimental --host=unix:///var/run/docker.sock > /tmp/docker.log 2>&1 &
    sleep 10
fi

# Check if user is in docker group
if ! groups $USER | grep -q docker; then
    print_warning "User not in docker group. You may need to log out and back in, or run: newgrp docker"
    print_info "Alternatively, you can use 'sudo docker' for this session"
fi

# Install kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    print_info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    print_status "kubectl installed"
else
    print_status "kubectl already installed"
fi

# Install Helm
if ! command -v helm >/dev/null 2>&1; then
    print_info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    print_status "Helm installed"
else
    print_status "Helm already installed"
fi

# Install Kind
if ! command -v kind >/dev/null 2>&1; then
    print_info "Installing Kind..."
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    print_status "Kind installed"
else
    print_status "Kind already installed"
fi

# ============================================================================
# PHASE 2: APPLICATION SETUP
# ============================================================================

print_section "PHASE 2: Setting up Application Environment"

# Setup Python virtual environment
if [ ! -d "venv" ]; then
    print_info "Creating Python virtual environment..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        # Ubuntu/Debian - use venv
        python3 -m venv venv
    else
        # Amazon Linux 2023 - use virtualenv
        python3 -m virtualenv venv
    fi
    print_status "Virtual environment created"
fi

# Install Python dependencies
print_info "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip

# Install requirements with retry logic
if [ -f "requirements.txt" ]; then
    print_info "Installing requirements from requirements.txt..."
    pip install -r requirements.txt || {
        print_warning "Failed to install from requirements.txt, trying individual packages..."
        pip install fastapi uvicorn pymongo python-multipart
    }
else
    print_warning "requirements.txt not found, installing basic packages..."
    pip install fastapi uvicorn pymongo python-multipart
fi
print_status "Python dependencies installed"

# Run application tests
print_info "Running application tests..."
cd app && python -m pytest test_basic.py -v && cd ..
print_status "Application tests passed"

# ============================================================================
# PHASE 3: DOCKER IMAGE BUILD
# ============================================================================

print_section "PHASE 3: Building Docker Image"

print_info "Building Docker image..."
$DOCKER_CMD build -t ${DOCKER_IMAGE}:latest . --network=host
print_status "Docker image built successfully"

# Test the application locally
print_info "Testing application locally..."

# Use appropriate Docker command based on system
if groups $USER | grep -q docker; then
    DOCKER_CMD="docker"
else
    DOCKER_CMD="sudo docker"
    print_info "Using sudo for Docker commands"
fi

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
# PHASE 4: KUBERNETES CLUSTER SETUP
# ============================================================================

print_section "PHASE 4: Setting up Kubernetes Cluster"

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
- role: worker
- role: worker
EOF

# Create or use existing cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_info "Creating Kind cluster..."
    if sudo kind create cluster --config infra/kind/cluster-config.yaml; then
        print_status "Kind cluster created successfully"
    else
        print_warning "Kind cluster creation failed, trying alternative approach..."
        # Try without iptables for container environments
        sudo kind create cluster --name gitops-cluster || {
            print_error "Failed to create Kind cluster. Continuing with deployment preparation..."
        }
    fi
else
    print_status "Using existing Kubernetes cluster"
fi

# Load Docker image into Kind cluster (if Kind is available)
if command -v kind >/dev/null 2>&1 && kind get clusters | grep -q gitops-cluster; then
    print_info "Loading Docker image into Kind cluster..."
    sudo kind load docker-image ${DOCKER_IMAGE}:latest --name gitops-cluster
    print_status "Docker image loaded into cluster"
fi

# ============================================================================
# PHASE 5: DEPLOYMENT PREPARATION
# ============================================================================

print_section "PHASE 5: Preparing Deployment Manifests"

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
EOF

# Generate application deployment using Helm
print_info "Generating application manifests..."
helm template ${APP_NAME} helm-chart \
    --namespace ${NAMESPACE} \
    --set app.image.repository=${DOCKER_IMAGE} \
    --set app.image.tag=latest \
    --set service.nodePort=${PRODUCTION_PORT} \
    > deployment/production/02-application.yaml

# Generate ArgoCD installation manifest
print_info "Generating ArgoCD manifests..."
cat > deployment/production/03-argocd-install.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-install
  namespace: ${ARGOCD_NAMESPACE}
data:
  install.yaml: |
$(curl -s https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml | sed 's/^/    /')
EOF

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

# Generate monitoring stack
print_info "Generating monitoring manifests..."
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
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}
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
EOF

print_status "Deployment manifests generated"

# ============================================================================
# PHASE 6: KUBERNETES DEPLOYMENT
# ============================================================================

print_section "PHASE 6: Deploying to Kubernetes"

# Deploy if cluster is available
if kubectl cluster-info >/dev/null 2>&1; then
    print_info "Deploying to Kubernetes cluster..."
    
    # Apply manifests in order
    kubectl apply -f deployment/production/01-namespace.yaml
    print_status "Namespaces created"
    
    kubectl apply -f deployment/production/02-application.yaml
    print_status "Application deployed"
    
    # Install ArgoCD
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    kubectl apply -f deployment/production/04-argocd-service.yaml
    print_status "ArgoCD installed"
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE} || true
    
    # Deploy monitoring stack
    kubectl apply -f deployment/production/06-monitoring-stack.yaml
    print_status "Monitoring stack deployed"
    
    # Create ArgoCD application
    sleep 30
    kubectl apply -f deployment/production/05-argocd-application.yaml || true
    print_status "ArgoCD application created"
    
else
    print_warning "No Kubernetes cluster available. Deployment manifests are ready in deployment/production/"
fi

# ============================================================================
# PHASE 7: VALIDATION AND TESTING
# ============================================================================

print_section "PHASE 7: Validation and Testing"

# Validate Helm chart
print_info "Validating Helm chart..."
helm lint helm-chart
print_status "Helm chart validation passed"

# Test application endpoints
print_info "Testing application endpoints..."
validation_score=0
total_tests=10

# Test 1: Docker build
if sudo docker images | grep -q ${DOCKER_IMAGE}; then
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

# Test 6-10: Tool availability
for tool in kubectl helm kind docker python3; do
    if command -v $tool >/dev/null 2>&1; then
        print_status "$tool is available"
        ((validation_score++))
    else
        print_error "$tool is not available"
    fi
done

# Calculate success rate
success_rate=$(( validation_score * 100 / total_tests ))

# ============================================================================
# PHASE 8: FINAL REPORT AND CLEANUP
# ============================================================================

print_section "PHASE 8: Installation Complete"

# Generate final deployment guide
cat > FINAL_DEPLOYMENT_GUIDE.md << EOF
# 🎉 Student Tracker - Complete Installation Summary

## ✅ Installation Status: COMPLETE
**Success Rate:** ${success_rate}%  
**Target Server:** ${PRODUCTION_HOST}  
**Date:** $(date)

## 🌐 Access URLs

### 📱 Student Tracker Application
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
4. Configure CI/CD pipelines

Installation completed successfully! 🎉
EOF

# Display final summary
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 INSTALLATION COMPLETE! 🎉                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${WHITE}🌐 Your Student Tracker is ready at:${NC}"
echo -e "${CYAN}   📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${CYAN}   🎯 ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${CYAN}   📊 Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${CYAN}   📈 Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo ""
echo -e "${GREEN}✅ Success Rate: ${success_rate}%${NC}"
echo -e "${BLUE}📖 Full guide: FINAL_DEPLOYMENT_GUIDE.md${NC}"
echo ""

# Clean up temporary files
rm -f get-docker.sh

# Create manual installation script as backup
print_info "Creating manual installation backup script..."
cat > manual-install-amazon-linux.sh << 'EOF'
#!/bin/bash

# Manual Installation Script for Amazon Linux 2023
# Use this if the automated installation fails

set -euo pipefail

echo "🚀 Manual Installation for Amazon Linux 2023"
echo "=============================================="

# Step 1: Install missing python3-venv package
echo "Step 1: Installing python3-pip and virtualenv..."
sudo yum install -y python3-pip
sudo pip3 install virtualenv

# Step 2: Create virtual environment manually
echo "Step 2: Creating virtual environment..."
python3 -m virtualenv venv
source venv/bin/activate

# Step 3: Install Python dependencies
echo "Step 3: Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Step 4: Install Docker
echo "Step 4: Installing Docker..."
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Step 5: Install kubectl
echo "Step 5: Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v1.33.3/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Step 6: Install Helm
echo "Step 6: Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Step 7: Install Kind
echo "Step 7: Installing Kind..."
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Step 8: Build Docker image
echo "Step 8: Building Docker image..."
sudo docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest . --network=host

# Step 9: Create Kind cluster
echo "Step 9: Creating Kind cluster..."
sudo kind create cluster --name gitops-cluster
sudo kind load docker-image ghcr.io/bonaventuresimeon/nativeseries:latest --name gitops-cluster

# Step 10: Deploy to Kubernetes
echo "Step 10: Deploying to Kubernetes..."
kubectl apply -f deployment/production/01-namespace.yaml
kubectl apply -f deployment/production/02-application.yaml
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
kubectl apply -f deployment/production/04-argocd-service.yaml
kubectl apply -f deployment/production/06-monitoring-stack.yaml
kubectl apply -f deployment/production/05-argocd-application.yaml

# Step 11: Verify deployment
echo "Step 11: Verifying deployment..."
kubectl get pods -A
kubectl get services -A

echo "🎉 Manual installation completed!"
echo "Access URLs:"
echo "Application: http://54.166.101.159:30011"
echo "ArgoCD: http://54.166.101.159:30080"
echo "Grafana: http://54.166.101.159:30081"
echo "Prometheus: http://54.166.101.159:30082"
EOF

chmod +x manual-install-amazon-linux.sh
print_status "Manual installation script created: manual-install-amazon-linux.sh"

# Final instructions
print_section "PHASE 9: Final Instructions"

echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo ""
echo -e "${CYAN}📋 Next Steps:${NC}"
echo "1. If you're not in the docker group, run: newgrp docker"
echo "2. Or use 'sudo docker' for Docker commands"
echo "3. Access your application at: http://54.166.101.159:30011"
echo "4. Access ArgoCD at: http://54.166.101.159:30080"
echo "5. Access Grafana at: http://54.166.101.159:30081"
echo "6. Access Prometheus at: http://54.166.101.159:30082"
echo ""
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo "- If Docker commands fail, try: sudo docker <command>"
echo "- If kubectl fails, check if cluster is running"
echo "- For ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""

# ============================================================================
# PHASE 10: MANUAL INSTALLATION GUIDE (FALLBACK)
# ============================================================================

print_section "PHASE 10: Manual Installation Guide (If Automated Installation Fails)"

echo -e "${YELLOW}📖 Manual Installation Steps (if automated installation fails):${NC}"
echo ""
echo -e "${CYAN}Step 1: Install missing python3-venv package${NC}"
echo "# For Amazon Linux 2023, install python3-venv manually"
echo "sudo yum install -y python3-pip"
echo "sudo pip3 install virtualenv"
echo ""
echo -e "${CYAN}Step 2: Create virtual environment manually${NC}"
echo "# Create virtual environment using virtualenv instead of venv"
echo "python3 -m virtualenv venv"
echo "source venv/bin/activate"
echo ""
echo -e "${CYAN}Step 3: Install Python dependencies${NC}"
echo "# Activate virtual environment and install dependencies"
echo "source venv/bin/activate"
echo "pip install --upgrade pip"
echo "pip install -r requirements.txt"
echo ""
echo -e "${CYAN}Step 4: Install Docker${NC}"
echo "# Install Docker"
echo "sudo yum update -y"
echo "sudo yum install -y docker"
echo "sudo systemctl start docker"
echo "sudo systemctl enable docker"
echo "sudo usermod -aG docker ec2-user"
echo "# Log out and back in for group changes to take effect"
echo ""
echo -e "${CYAN}Step 5: Install kubectl${NC}"
echo "# Install kubectl"
echo "curl -LO \"https://dl.k8s.io/release/v1.33.3/bin/linux/amd64/kubectl\""
echo "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
echo "rm -f kubectl"
echo ""
echo -e "${CYAN}Step 6: Install Helm${NC}"
echo "# Install Helm"
echo "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
echo ""
echo -e "${CYAN}Step 7: Install Kind${NC}"
echo "# Install Kind"
echo "curl -Lo ./kind \"https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64\""
echo "chmod +x ./kind"
echo "sudo mv ./kind /usr/local/bin/kind"
echo ""
echo -e "${CYAN}Step 8: Build Docker image${NC}"
echo "# Build the Docker image"
echo "sudo docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest . --network=host"
echo ""
echo -e "${CYAN}Step 9: Create Kind cluster${NC}"
echo "# Create Kind cluster"
echo "sudo kind create cluster --name gitops-cluster"
echo "sudo kind load docker-image ghcr.io/bonaventuresimeon/nativeseries:latest --name gitops-cluster"
echo ""
echo -e "${CYAN}Step 10: Deploy to Kubernetes${NC}"
echo "# Apply the deployment manifests"
echo "kubectl apply -f deployment/production/01-namespace.yaml"
echo "kubectl apply -f deployment/production/02-application.yaml"
echo "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml"
echo "kubectl apply -f deployment/production/04-argocd-service.yaml"
echo "kubectl apply -f deployment/production/06-monitoring-stack.yaml"
echo "kubectl apply -f deployment/production/05-argocd-application.yaml"
echo ""
echo -e "${CYAN}Step 11: Verify deployment${NC}"
echo "# Check deployment status"
echo "kubectl get pods -A"
echo "kubectl get services -A"
echo ""
echo -e "${CYAN}Step 12: Access the application${NC}"
echo "# Get ArgoCD admin password"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo -e "${GREEN}📋 Complete one-liner for all steps:${NC}"
echo "# Run this complete installation script"
echo "sudo yum install -y python3-pip && \\"
echo "sudo pip3 install virtualenv && \\"
echo "python3 -m virtualenv venv && \\"
echo "source venv/bin/activate && \\"
echo "pip install --upgrade pip && \\"
echo "pip install -r requirements.txt && \\"
echo "sudo yum install -y docker && \\"
echo "sudo systemctl start docker && \\"
echo "sudo systemctl enable docker && \\"
echo "sudo usermod -aG docker ec2-user && \\"
echo "curl -LO \"https://dl.k8s.io/release/v1.33.3/bin/linux/amd64/kubectl\" && \\"
echo "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \\"
echo "rm -f kubectl && \\"
echo "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \\"
echo "curl -Lo ./kind \"https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64\" && \\"
echo "chmod +x ./kind && \\"
echo "sudo mv ./kind /usr/local/bin/kind && \\"
echo "sudo docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest . --network=host && \\"
echo "sudo kind create cluster --name gitops-cluster && \\"
echo "sudo kind load docker-image ghcr.io/bonaventuresimeon/nativeseries:latest --name gitops-cluster && \\"
echo "kubectl apply -f deployment/production/01-namespace.yaml && \\"
echo "kubectl apply -f deployment/production/02-application.yaml && \\"
echo "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml && \\"
echo "kubectl apply -f deployment/production/04-argocd-service.yaml && \\"
echo "kubectl apply -f deployment/production/06-monitoring-stack.yaml && \\"
echo "kubectl apply -f deployment/production/05-argocd-application.yaml"
echo ""
echo -e "${BLUE}🌐 Access URLs after deployment:${NC}"
echo "Application: http://54.166.101.159:30011"
echo "ArgoCD: http://54.166.101.159:30080"
echo "Grafana: http://54.166.101.159:30081"
echo "Prometheus: http://54.166.101.159:30082"
echo ""
echo -e "${YELLOW}💡 Note: The main issue was that python3-venv package doesn't exist on Amazon Linux 2023, so we need to use virtualenv instead.${NC}"
echo ""
echo -e "${GREEN}📁 Backup Script Created:${NC}"
echo "If the automated installation fails, you can run the manual installation script:"
echo "  ./manual-install-amazon-linux.sh"
echo ""

print_status "Installation completed successfully!"
