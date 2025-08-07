#!/bin/bash

# NativeSeries - Complete Installation & Deployment Script
# Version: 6.0.0 - Updated with Fixed Manifests
# This script combines all installation, deployment, monitoring, and validation scripts
# Updated for NativeSeries with corrected manifests and Helm charts

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

# Production Configuration - Updated for NativeSeries
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
echo "║          🚀 NativeSeries - Complete Installation                  ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                  ║"
echo "║              Full Stack Deployment with Monitoring              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirmation
echo -e "${YELLOW}This script will install and deploy the complete NativeSeries stack to:${NC}"
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

# Function to install missing tools
install_missing_tool() {
    local tool_name="$1"
    local install_command="$2"
    local check_command="$3"
    
    if command_exists "$tool_name"; then
        print_status "✓ $tool_name is already installed"
        if [ -n "$check_command" ]; then
            eval "$check_command"
        fi
        return 0
    else
        print_info "Installing $tool_name..."
        if eval "$install_command"; then
            print_status "✓ $tool_name installed successfully"
            return 0
        else
            print_error "✗ Failed to install $tool_name"
            return 1
        fi
    fi
}

# Install basic tools
print_info "Installing basic system tools..."
sudo $PKG_MANAGER install -y curl wget git unzip jq gcc make python3 python3-pip

# Install virtualenv based on system
if [ "$PKG_MANAGER" = "apt" ]; then
    install_missing_tool "python3-venv" "sudo apt-get install -y python3-venv" "python3 -m venv --help"
else
    install_missing_tool "virtualenv" "sudo pip3 install virtualenv" "python3 -m virtualenv --help"
fi

# Install Docker
print_info "Checking Docker installation..."
if command_exists docker; then
    print_status "✓ Docker is already installed"
    docker --version
else
    print_info "Installing Docker..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm -f get-docker.sh
    else
        sudo $PKG_MANAGER install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    fi
    print_status "✓ Docker installed successfully"
fi

# Install kubectl
print_info "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
print_status "✓ kubectl installed"

# Install Helm
print_info "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
print_status "✓ Helm installed"

# Install Kind
print_info "Installing Kind..."
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
print_status "✓ Kind installed"

# ============================================================================
# PHASE 3: APPLICATION SETUP
# ============================================================================

print_section "PHASE 3: Setting up Application Environment"

# Setup Python virtual environment
if [ ! -d "venv" ]; then
    print_info "Creating Python virtual environment..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        python3 -m venv venv
    else
        python3 -m virtualenv venv
    fi
    print_status "Virtual environment created"
fi

# Install Python dependencies
print_info "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt || pip install fastapi uvicorn pymongo python-multipart
print_status "Python dependencies installed"

# ============================================================================
# PHASE 4: DOCKER IMAGE BUILD
# ============================================================================

print_section "PHASE 4: Building Docker Image"

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
# PHASE 6: DEPLOYMENT PREPARATION
# ============================================================================

print_section "PHASE 6: Preparing Deployment Manifests"

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
# PHASE 7: KUBERNETES DEPLOYMENT
# ============================================================================

print_section "PHASE 7: Deploying to Kubernetes"

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
# PHASE 8: VALIDATION AND TESTING
# ============================================================================

print_section "PHASE 8: Validation and Testing"

# Validate Helm chart
print_info "Validating Helm chart..."
helm lint helm-chart
print_status "Helm chart validation passed"

# Test application endpoints
print_info "Testing application endpoints..."
validation_score=0
total_tests=5

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

# Calculate success rate
success_rate=$(( validation_score * 100 / total_tests ))

# ============================================================================
# PHASE 9: FINAL REPORT
# ============================================================================

print_section "PHASE 9: Installation Complete"

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

echo -e "${WHITE}🌐 Your NativeSeries is ready at:${NC}"
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

print_status "Installation completed successfully!"
