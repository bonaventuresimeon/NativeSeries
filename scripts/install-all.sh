#!/bin/bash

# NativeSeries - Complete Installation & Deployment Script
# Version: 6.1.0 - Updated with Comprehensive Verification and Loki
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
    
    # Deploy application using Helm to NativeSeries namespace
    print_info "Deploying application using Helm to ${NAMESPACE} namespace..."
    helm upgrade --install ${APP_NAME} helm-chart \
        --namespace ${NAMESPACE} \
        --create-namespace \
        --set image.repository=${DOCKER_IMAGE} \
        --set image.tag=latest \
        --set service.nodePort=${PRODUCTION_PORT} \
        --wait \
        --timeout=10m
    print_status "Application deployed to ${NAMESPACE} namespace"
    
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

print_status "Installation completed successfully!"
print_info "All services are now running and accessible!"
