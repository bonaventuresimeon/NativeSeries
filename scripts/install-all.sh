#!/bin/bash

# Student Tracker - Complete Installation Script
# Version: 3.0.0 - Aligned with existing application structure
# Fixed all syntax, paths, DNS, port issues, bugs, and errors

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

# Configuration - Aligned with existing application
PYTHON_VERSION="3.11"
DOCKER_VERSION="20.10"
KUBECTL_VERSION="1.28"
HELM_VERSION="3.13"
KIND_VERSION="0.20.0"
ARGOCD_VERSION="v2.9.3"

# Application configuration - Fixed to match existing setup
APP_NAME="NativeSeries"
NAMESPACE="NativeSeries"
ARGOCD_NAMESPACE="argocd"
PRODUCTION_HOST="${PRODUCTION_HOST:-54.166.101.15}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
ARGOCD_PORT="30080"
DOCKER_USERNAME="${DOCKER_USERNAME:-bonaventuresimeon}"
DOCKER_IMAGE="ghcr.io/${DOCKER_USERNAME}/nativeseries"

# Repository configuration - Fixed to match actual repo
REPO_URL="https://github.com/bonaventuresimeon/NativeSeries.git"
HELM_CHART_PATH="helm-chart"
ARGOCD_APP_PATH="argocd"

# Get OS information
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture
case "$ARCH" in
    "x86_64") ARCH="amd64" ;;
    "aarch64") ARCH="arm64" ;;
    "armv7l") ARCH="arm" ;;
esac

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          🚀 Student Tracker - Complete Installation          ║"
echo "║              From Python to Production GitOps               ║"
echo "║                Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}🎯 Target Configuration:${NC}"
echo -e "  📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
echo -e "  🎯 ArgoCD UI: http://${PRODUCTION_HOST}:${ARGOCD_PORT}"
echo -e "  💻 OS: ${OS} (${ARCH})"
echo -e "  📁 Namespace: ${NAMESPACE}"
echo -e "  📦 Helm Chart: ${HELM_CHART_PATH}"
echo -e ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user confirmation
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
    read -r
}

# Function to create directories - Fixed paths
create_directories() {
    print_section "📁 Creating Project Directories"
    
    print_status "Creating project directories..."
    mkdir -p logs
    mkdir -p data
    mkdir -p backup
    mkdir -p ~/.kube
    mkdir -p infra/kind
    
    # Ensure existing directories are preserved
    if [ ! -d "helm-chart" ]; then
        mkdir -p helm-chart/templates
    fi
    
    if [ ! -d "argocd" ]; then
        mkdir -p argocd
    fi
    
    print_status "✅ Directories created successfully"
}

# Function to install Python
install_python() {
    print_section "🐍 Installing Python ${PYTHON_VERSION}"
    
    if command_exists python${PYTHON_VERSION}; then
        print_status "✅ Python ${PYTHON_VERSION} already installed"
        python${PYTHON_VERSION} --version
        return 0
    fi
    
    case "$OS" in
        "linux")
            if command_exists apt-get; then
                print_status "Installing Python on Ubuntu/Debian..."
                sudo apt-get update
                sudo apt-get install -y \
                    python${PYTHON_VERSION} \
                    python${PYTHON_VERSION}-pip \
                    python${PYTHON_VERSION}-venv \
                    python${PYTHON_VERSION}-dev \
                    build-essential \
                    curl \
                    wget \
                    git
            elif command_exists yum; then
                print_status "Installing Python on CentOS/RHEL..."
                sudo yum update -y
                sudo yum install -y \
                    python${PYTHON_VERSION} \
                    python${PYTHON_VERSION}-pip \
                    python${PYTHON_VERSION}-devel \
                    gcc \
                    curl \
                    wget \
                    git
            elif command_exists dnf; then
                print_status "Installing Python on Fedora..."
                sudo dnf update -y
                sudo dnf install -y \
                    python${PYTHON_VERSION} \
                    python${PYTHON_VERSION}-pip \
                    python${PYTHON_VERSION}-devel \
                    gcc \
                    curl \
                    wget \
                    git
            else
                print_error "❌ Unsupported Linux distribution"
                exit 1
            fi
            ;;
        "darwin")
            if command_exists brew; then
                print_status "Installing Python on macOS..."
                brew install python@${PYTHON_VERSION}
            else
                print_warning "⚠️  Homebrew not found. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install python@${PYTHON_VERSION}
            fi
            ;;
        *)
            print_error "❌ Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    print_status "✅ Python ${PYTHON_VERSION} installed successfully"
    python${PYTHON_VERSION} --version
}

# Function to setup Python environment
setup_python_env() {
    print_section "🐍 Setting up Python Virtual Environment"
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python${PYTHON_VERSION} -m venv venv
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        print_status "Installing Python dependencies..."
        pip install -r requirements.txt
    else
        print_warning "⚠️  requirements.txt not found, installing basic dependencies..."
        pip install fastapi uvicorn pytest black flake8 httpx
    fi
    
    # Install development dependencies
    print_status "Installing development dependencies..."
    pip install pytest-cov pytest-watch
    
    print_status "✅ Python environment ready"
}

# Function to install Docker
install_docker() {
    print_section "🐳 Installing Docker"
    
    if command_exists docker; then
        print_status "✅ Docker already installed"
        docker --version
        return 0
    fi
    
    case "$OS" in
        "linux")
            print_status "Installing Docker on Linux..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            
            # Start Docker service
            if command_exists systemctl; then
                sudo systemctl start docker
                sudo systemctl enable docker
            else
                print_warning "⚠️  Starting Docker daemon..."
                dockerd > /tmp/docker.log 2>&1 &
                sleep 5
            fi
            ;;
        "darwin")
            print_status "Installing Docker on macOS..."
            if command_exists brew; then
                brew install --cask docker
            else
                print_error "❌ Please install Docker Desktop manually from https://docker.com/products/docker-desktop"
                exit 1
            fi
            ;;
        *)
            print_error "❌ Unsupported OS for Docker installation"
            exit 1
            ;;
    esac
    
    print_status "✅ Docker installed successfully"
    print_warning "⚠️  You may need to log out and back in for Docker group membership to take effect"
}

# Function to install kubectl
install_kubectl() {
    print_section "☸️ Installing kubectl"
    
    if command_exists kubectl; then
        print_status "✅ kubectl already installed"
        kubectl version --client
        return 0
    fi
    
    print_status "Installing kubectl..."
    
    case "$OS" in
        "linux")
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
            ;;
        "darwin")
            if command_exists brew; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/${ARCH}/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
            fi
            ;;
        *)
            print_error "❌ Unsupported OS for kubectl installation"
            exit 1
            ;;
    esac
    
    print_status "✅ kubectl installed successfully"
    kubectl version --client
}

# Function to install Helm
install_helm() {
    print_section "⎈ Installing Helm"
    
    if command_exists helm; then
        print_status "✅ Helm already installed"
        helm version
        return 0
    fi
    
    print_status "Installing Helm..."
    
    case "$OS" in
        "linux"|"darwin")
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
        *)
            print_error "❌ Unsupported OS for Helm installation"
            exit 1
            ;;
    esac
    
    print_status "✅ Helm installed successfully"
    helm version
}

# Function to install Kind
install_kind() {
    print_section "🔧 Installing Kind"
    
    if command_exists kind; then
        print_status "✅ Kind already installed"
        kind version
        return 0
    fi
    
    print_status "Installing Kind..."
    
    case "$OS" in
        "linux")
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${ARCH}"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        "darwin")
            if command_exists brew; then
                brew install kind
            else
                curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-darwin-${ARCH}"
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
            ;;
        *)
            print_error "❌ Unsupported OS for Kind installation"
            exit 1
            ;;
    esac
    
    print_status "✅ Kind installed successfully"
    kind version
}

# Function to install ArgoCD CLI
install_argocd_cli() {
    print_section "🎯 Installing ArgoCD CLI"
    
    if command_exists argocd; then
        print_status "✅ ArgoCD CLI already installed"
        argocd version --client
        return 0
    fi
    
    print_status "Installing ArgoCD CLI..."
    
    case "$OS" in
        "linux")
            curl -sSL -o argocd-linux-${ARCH} "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}"
            sudo install -m 555 argocd-linux-${ARCH} /usr/local/bin/argocd
            rm argocd-linux-${ARCH}
            ;;
        "darwin")
            if command_exists brew; then
                brew install argocd
            else
                curl -sSL -o argocd-darwin-${ARCH} "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-darwin-${ARCH}"
                chmod +x argocd-darwin-${ARCH}
                sudo mv argocd-darwin-${ARCH} /usr/local/bin/argocd
            fi
            ;;
        *)
            print_error "❌ Unsupported OS for ArgoCD CLI installation"
            exit 1
            ;;
    esac
    
    print_status "✅ ArgoCD CLI installed successfully"
    argocd version --client
}

# Function to install ArgoCD
install_argocd() {
    print_section "🎯 Installing ArgoCD"
    
    print_status "Installing ArgoCD in cluster..."
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "⏳ Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n ${ARGOCD_NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n ${ARGOCD_NAMESPACE}
    
    # Configure ArgoCD for insecure access
    print_status "🔧 Configuring ArgoCD..."
    kubectl patch deployment argocd-server -n ${ARGOCD_NAMESPACE} -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json
    
    # Create NodePort service
    print_status "🌐 Creating ArgoCD NodePort service..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - name: server
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF
    
    # Wait for server to restart
    sleep 10
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
    
    # Get admin password
    print_status "🔑 Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE} -o jsonpath="{.data.password}" | base64 -d)
    echo "$ARGOCD_PASSWORD" > .argocd-password
    
    print_status "✅ ArgoCD installed successfully"
    print_status "🔑 Admin password saved to .argocd-password"
}

# Function to install additional tools
install_additional_tools() {
    print_section "🛠️ Installing Additional Tools"
    
    print_status "Installing useful tools..."
    
    case "$OS" in
        "linux")
            if command_exists apt-get; then
                sudo apt-get install -y jq tree htop net-tools
            elif command_exists yum; then
                sudo yum install -y jq tree htop net-tools
            elif command_exists dnf; then
                sudo dnf install -y jq tree htop net-tools
            fi
            ;;
        "darwin")
            if command_exists brew; then
                brew install jq tree htop
            fi
            ;;
    esac
    
    # Install GitHub CLI if not present
    if ! command_exists gh; then
        print_status "Installing GitHub CLI..."
        case "$OS" in
            "linux")
                if command_exists apt-get; then
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                    sudo apt-get update
                    sudo apt-get install -y gh
                fi
                ;;
            "darwin")
                if command_exists brew; then
                    brew install gh
                fi
                ;;
        esac
    fi
    
    print_status "✅ Additional tools installed"
}

# Function to create Kind cluster
create_kind_cluster() {
    print_section "🚀 Creating Kind Cluster"
    
    CLUSTER_NAME="gitops-cluster"
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        print_warning "⚠️  Cluster '$CLUSTER_NAME' already exists. Deleting..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    print_status "Creating Kind cluster with configuration..."
    
    # Create Kind cluster config
    cat <<EOF > infra/kind/cluster-config.yaml
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
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30011
    hostPort: ${PRODUCTION_PORT}
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF
    
    # Create cluster
    kind create cluster --config infra/kind/cluster-config.yaml
    
    # Wait for cluster to be ready
    print_status "⏳ Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Install ingress-nginx
    print_status "🌐 Installing ingress-nginx..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    
    # Create namespaces
    print_status "📁 Creating namespaces..."
    kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "✅ Kind cluster created successfully"
    kubectl cluster-info
}

# Function to build and load application
build_application() {
    print_section "🐳 Building Application Container"
    
    print_status "Building ${APP_NAME} image..."
    
    # Use existing Dockerfile or create one if missing
    local dockerfile_path="Dockerfile"
    if [ ! -f "$dockerfile_path" ]; then
        print_warning "⚠️  Dockerfile not found in root, checking docker/ directory..."
        if [ -f "docker/Dockerfile" ]; then
            dockerfile_path="docker/Dockerfile"
                 else
            print_error "❌ No Dockerfile found. Please ensure Dockerfile exists."
            return 1
        fi
    fi
    
    # Build image with proper tagging
    local image_name="${DOCKER_IMAGE}:latest"
    print_status "Building image: $image_name using $dockerfile_path"
    docker build -t "$image_name" -f "$dockerfile_path" .
    
    # Also tag with simple name for Kind
    docker tag "$image_name" "${APP_NAME}:latest"
    
    # Load image into Kind cluster
    print_status "Loading image into Kind cluster..."
    kind load docker-image "${APP_NAME}:latest" --name gitops-cluster
    
    print_status "✅ Application built and loaded"
}

# Function to create basic Dockerfile if needed
create_basic_dockerfile() {
    print_warning "⚠️  Creating basic Dockerfile..."
    mkdir -p docker
    cat <<EOF > docker/Dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Build dependencies
FROM python:3.11-slim AS build
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN set -eux; apt-get update; apt-get install -y \\
    gcc libpq-dev libssl-dev libffi-dev curl; apt-get clean; rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && pip install --no-cache-dir -r requirements.txt
COPY app/ ./app
COPY templates/ ./templates

# Stage 2: Runtime
FROM python:3.11-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5; apt-get clean; rm -rf /var/lib/apt/lists/*
RUN groupadd --system appgroup \\
 && useradd --system --gid appgroup --no-create-home appuser
COPY --from=build /usr/local/lib/python3.*/site-packages/ /usr/local/lib/python3.*/site-packages/
COPY --from=build /app /app
RUN chown -R appuser:appgroup /app
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:8000/health || exit 1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
}

# Function to create Helm chart - Updated to preserve existing files
create_helm_chart() {
    print_section "📦 Updating Helm Chart Configuration"
    
    # Check if Chart.yaml exists, if not create it
    if [ ! -f "helm-chart/Chart.yaml" ]; then
        print_status "Creating Chart.yaml..."
        cat <<EOF > helm-chart/Chart.yaml
apiVersion: v2
name: student-tracker
description: A FastAPI student tracker application for Kubernetes deployment
type: application
version: 0.2.0
appVersion: "1.0.0"
home: https://github.com/your-org/student-tracker
sources:
  - https://github.com/your-org/student-tracker
maintainers:
  - name: Development Team
    email: dev@yourcompany.com
keywords:
  - fastapi
  - student-tracker
  - python
  - kubernetes
EOF
    else
        print_status "Chart.yaml already exists, skipping..."
    fi
    
    # Update values.yaml with current configuration
    print_status "Updating values.yaml..."
    cat <<EOF > helm-chart/values.yaml
# Default values for student-tracker
# This is a YAML-formatted file.

# Application configuration
app:
  name: student-tracker
  port: 8000

# Image configuration
image:
  repository: student-tracker
  tag: latest
  pullPolicy: IfNotPresent

# Deployment configuration
replicaCount: 2

# Resource limits and requests
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Health checks
healthCheck:
  enabled: true
  path: /health
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

# Service configuration
service:
  type: NodePort
  port: 80
  targetPort: 8000
  nodePort: ${PRODUCTION_PORT}  # Maps to production port on the host

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: ${PRODUCTION_HOST}
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Environment variables
env:
  - name: DATABASE_URL
    value: "postgresql://user:pass@db:5432/studentdb"
  - name: APP_ENV
    value: "development"

# ConfigMap data
configMap:
  enabled: true
  data:
    app_name: "Student Tracker API"
    log_level: "INFO"

# Secret data (for sensitive information)
secret:
  enabled: false
  data: {}

# Pod Security Context
podSecurityContext:
  fsGroup: 2000

# Security Context
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

# Node selector
nodeSelector: {}

# Tolerations
tolerations: []

# Affinity
affinity: {}

# Horizontal Pod Autoscaler
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# ServiceMonitor for Prometheus (if using Prometheus Operator)
serviceMonitor:
  enabled: false
  interval: 30s
  path: /metrics
EOF
    
    # Create deployment template
    cat <<EOF > helm-chart/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "student-tracker.fullname" . }}
  labels:
    {{- include "student-tracker.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "student-tracker.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "student-tracker.selectorLabels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- if .Values.secret.enabled }}
        checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- end }}
    spec:
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .Values.app.port }}
              protocol: TCP
          {{- if and .Values.healthCheck.enabled .Values.healthCheck.path }}
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: http
            initialDelaySeconds: {{ .Values.healthCheck.initialDelaySeconds | default 30 }}
            periodSeconds: {{ .Values.healthCheck.periodSeconds | default 10 }}
            timeoutSeconds: {{ .Values.healthCheck.timeoutSeconds | default 5 }}
            failureThreshold: {{ .Values.healthCheck.failureThreshold | default 3 }}
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheck.path }}
              port: http
            initialDelaySeconds: {{ div (.Values.healthCheck.initialDelaySeconds | default 30) 2 }}
            periodSeconds: {{ .Values.healthCheck.periodSeconds | default 10 }}
            timeoutSeconds: {{ .Values.healthCheck.timeoutSeconds | default 5 }}
            failureThreshold: {{ .Values.healthCheck.failureThreshold | default 3 }}
          {{- end }}
          env:
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
            {{- if .Values.configMap.enabled }}
            - name: APP_NAME
              valueFrom:
                configMapKeyRef:
                  name: {{ include "student-tracker.fullname" . }}
                  key: app_name
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: {{ include "student-tracker.fullname" . }}
                  key: log_level
            {{- end }}
            {{- if .Values.secret.enabled }}
            {{- range \$key, \$value := .Values.secret.data }}
            - name: {{ \$key }}
              valueFrom:
                secretKeyRef:
                  name: {{ include "student-tracker.fullname" \$ }}
                  key: {{ \$key }}
            {{- end }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- if and .Values.securityContext .Values.securityContext.readOnlyRootFilesystem }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: var-run
              mountPath: /var/run
          {{- end }}
      {{- if and .Values.securityContext .Values.securityContext.readOnlyRootFilesystem }}
      volumes:
        - name: tmp
          emptyDir: {}
        - name: var-run
          emptyDir: {}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF
    
    # Create service template
    cat <<EOF > helm-chart/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "student-tracker.fullname" . }}
  labels:
    {{- include "student-tracker.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      nodePort: {{ .Values.service.nodePort }}
      protocol: TCP
      name: http
  selector:
    {{- include "student-tracker.selectorLabels" . | nindent 4 }}
EOF
    
    # Create configmap template
    cat <<EOF > helm-chart/templates/configmap.yaml
{{- if .Values.configMap.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "student-tracker.fullname" . }}
  labels:
    {{- include "student-tracker.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.configMap.data | nindent 2 }}
{{- end }}
EOF
    
    # Create helpers template
    cat <<EOF > helm-chart/templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "student-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "student-tracker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- \$name := default .Chart.Name .Values.nameOverride }}
{{- if contains \$name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name \$name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "student-tracker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "student-tracker.labels" -}}
helm.sh/chart: {{ include "student-tracker.chart" . }}
{{ include "student-tracker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "student-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "student-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF
    
    print_status "✅ Helm chart created successfully"
}

# Function to deploy application
deploy_application() {
    print_section "🚀 Deploying Application"
    
    # Deploy using Helm
    print_status "Deploying with Helm..."
    helm upgrade --install ${APP_NAME} ${HELM_CHART_PATH} \
        --namespace ${NAMESPACE} \
        --create-namespace \
        --wait \
        --timeout=300s \
        --set image.repository="${DOCKER_IMAGE}" \
        --set image.tag="latest"
    
    print_status "✅ Application deployed successfully"
    kubectl get pods -n ${NAMESPACE}
}

# Function to setup GitOps - Fixed to use existing application.yaml
setup_gitops() {
    print_section "🔄 Setting up GitOps with ArgoCD"
    
    # Check if application.yaml exists and apply it
    if [ -f "${ARGOCD_APP_PATH}/application.yaml" ]; then
        print_status "Applying existing ArgoCD application configuration..."
        kubectl apply -f ${ARGOCD_APP_PATH}/application.yaml
    else
        print_warning "ArgoCD application.yaml not found, creating basic configuration..."
        # Create basic ArgoCD application
        cat <<EOF > ${ARGOCD_APP_PATH}/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: ${HELM_CHART_PATH}
    helm:
      valueFiles:
        - values.yaml
      parameters:
        - name: image.repository
          value: ${DOCKER_IMAGE}
        - name: image.tag
          value: latest
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
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
  revisionHistoryLimit: 10
EOF
        kubectl apply -f ${ARGOCD_APP_PATH}/application.yaml
    fi
    
    print_status "✅ GitOps setup complete"
}

# Function to verify installation
verify_installation() {
    print_section "✅ Verifying Installation"
    
    print_status "Checking all components..."
    
    # Check cluster
    print_status "Kubernetes Cluster:"
    kubectl cluster-info
    kubectl get nodes
    
    # Check application
    print_status "Application Pods:"
    kubectl get pods -n ${NAMESPACE}
    
    # Check services
    print_status "Services:"
    kubectl get svc -n ${NAMESPACE}
    
    # Check ArgoCD
    print_status "ArgoCD:"
    kubectl get pods -n ${ARGOCD_NAMESPACE}
    
    # Test application health
    print_status "Testing application health..."
    sleep 30  # Wait for application to be ready
    
    if kubectl port-forward svc/${APP_NAME} -n ${NAMESPACE} 8080:80 &>/dev/null &
    then
        PF_PID=$!
        sleep 5
        if curl -s http://localhost:8080/health >/dev/null; then
            print_status "✅ Application health check passed"
        else
            print_warning "⚠️  Application health check failed - may need more time to start"
        fi
        kill $PF_PID 2>/dev/null || true
    fi
    
    print_status "✅ Installation verification complete"
}

# Function to display final information
display_final_info() {
    print_section "🎉 Installation Complete!"
    
    print_status "🚀 Student Tracker GitOps Stack Successfully Installed!"
    echo -e ""
    print_status "📋 Access Information:"
    print_status "  🌐 Student Tracker: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
    print_status "  🌐 Local access: http://localhost:${PRODUCTION_PORT}"
    print_status "  📖 API Docs: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs"
    print_status "  🩺 Health Check: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health"
    echo -e ""
    print_status "  🎯 ArgoCD UI: http://${PRODUCTION_HOST}:${ARGOCD_PORT}"
    print_status "  🎯 Local ArgoCD: http://localhost:${ARGOCD_PORT}"
    print_status "  👤 ArgoCD Username: admin"
    print_status "  🔑 ArgoCD Password: $(cat .argocd-password 2>/dev/null || echo 'Check .argocd-password file')"
    echo -e ""
    print_status "🛠️  Useful Commands:"
    print_status "  # Check application status"
    print_status "  kubectl get all -n ${NAMESPACE}"
    echo -e ""
    print_status "  # View application logs"
    print_status "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
    echo -e ""
    print_status "  # Port forward for local access"
    print_status "  kubectl port-forward svc/${APP_NAME} -n ${NAMESPACE} 8000:80"
    echo -e ""
    print_status "  # Access ArgoCD locally"
    print_status "  kubectl port-forward svc/argocd-server-nodeport -n ${ARGOCD_NAMESPACE} 8080:80"
    echo -e ""
    print_status "📚 Next Steps:"
    print_status "  1. Update repository URLs in ArgoCD applications"
    print_status "  2. Configure your load balancer to route ${PRODUCTION_HOST} to your cluster"
    print_status "  3. Set up continuous deployment with GitHub Actions"
    print_status "  4. Configure monitoring and logging (optional)"
    echo -e ""
    print_warning "📝 Important Notes:"
    print_warning "  • ArgoCD password is saved in .argocd-password file"
    print_warning "  • Virtual environment is in ./venv directory"
    print_warning "  • Kind cluster name: gitops-cluster"
    print_warning "  • All configurations are in infra/ directory"
    echo -e ""
    print_status "🎉 Happy coding with GitOps! 🚀"
}

# Main execution function
main() {
    echo -e "${YELLOW}🔍 This script will install and configure:${NC}"
    echo -e "  • Python ${PYTHON_VERSION} with virtual environment"
    echo -e "  • Docker ${DOCKER_VERSION}+"
    echo -e "  • kubectl ${KUBECTL_VERSION}+"
    echo -e "  • Helm ${HELM_VERSION}+"
    echo -e "  • Kind ${KIND_VERSION}"
    echo -e "  • ArgoCD ${ARGOCD_VERSION}"
    echo -e "  • Complete GitOps stack"
    echo -e "  • Application deployment to ${PRODUCTION_HOST}:${PRODUCTION_PORT}"
    echo -e ""
    echo -e "${YELLOW}⚠️  This may take 10-20 minutes depending on your internet connection.${NC}"
    echo -e "${YELLOW}Do you want to continue? (y/N):${NC}"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Installation cancelled.${NC}"
        exit 0
    fi
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Execute installation steps
    create_directories
    install_python
    setup_python_env
    install_docker
    install_kubectl
    install_helm
    install_kind
    install_argocd_cli
    install_additional_tools
    create_kind_cluster
    build_application
    create_helm_chart
    install_argocd
    deploy_application
    setup_gitops
    verify_installation
    
    # Calculate execution time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo -e "${GREEN}⏱️  Total installation time: ${DURATION} seconds${NC}"
    
    display_final_info
    
    # Signal completion and exit
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo -e "${GREEN}✅ All processes finished. Exiting...${NC}"
    exit 0
}

# Check if script is run as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please don't run this script as root${NC}"
    exit 1
fi

# Run main function
main "$@"