#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PYTHON_VERSION="3.11"
DOCKER_VERSION="20.10"
KUBECTL_VERSION="1.28"
HELM_VERSION="3.13"
KIND_VERSION="0.22.0"
ARGOCD_VERSION="v2.9.3"
TARGET_IP="18.208.149.195"
TARGET_PORT="8011"
ARGOCD_PORT="30080"

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
echo "║                  Target: ${TARGET_IP}:${TARGET_PORT}                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}🎯 Target Configuration:${NC}"
echo -e "  📱 Application: http://${TARGET_IP}:${TARGET_PORT}"
echo -e "  🎯 ArgoCD UI: http://${TARGET_IP}:${ARGOCD_PORT}"
echo -e "  💻 OS: ${OS} (${ARCH})"
echo -e ""

# Function to print section headers
print_section() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user confirmation
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
    read -r
}

# Function to create directories
create_directories() {
    print_section "📁 Creating Project Directories"
    
    echo -e "${BLUE}Creating project directories...${NC}"
    mkdir -p logs
    mkdir -p data
    mkdir -p backup
    mkdir -p ~/.kube
    mkdir -p infra/kind
    mkdir -p infra/helm/templates
    mkdir -p infra/argocd/parent
    mkdir -p k8s/argocd
    
    echo -e "${GREEN}✅ Directories created successfully${NC}"
}

# Function to install Python
install_python() {
    print_section "🐍 Installing Python ${PYTHON_VERSION}"
    
    if command_exists python${PYTHON_VERSION}; then
        echo -e "${GREEN}✅ Python ${PYTHON_VERSION} already installed${NC}"
        python${PYTHON_VERSION} --version
        return 0
    fi
    
    case "$OS" in
        "linux")
            if command_exists apt-get; then
                echo -e "${BLUE}Installing Python on Ubuntu/Debian...${NC}"
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
                echo -e "${BLUE}Installing Python on CentOS/RHEL...${NC}"
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
                echo -e "${BLUE}Installing Python on Fedora...${NC}"
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
                echo -e "${RED}❌ Unsupported Linux distribution${NC}"
                exit 1
            fi
            ;;
        "darwin")
            if command_exists brew; then
                echo -e "${BLUE}Installing Python on macOS...${NC}"
                brew install python@${PYTHON_VERSION}
            else
                echo -e "${YELLOW}⚠️  Homebrew not found. Installing Homebrew first...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install python@${PYTHON_VERSION}
            fi
            ;;
        *)
            echo -e "${RED}❌ Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Python ${PYTHON_VERSION} installed successfully${NC}"
    python${PYTHON_VERSION} --version
}

# Function to setup Python environment
setup_python_env() {
    print_section "🐍 Setting up Python Virtual Environment"
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        echo -e "${BLUE}Creating virtual environment...${NC}"
        python${PYTHON_VERSION} -m venv venv
    fi
    
    # Activate virtual environment
    echo -e "${BLUE}Activating virtual environment...${NC}"
    source venv/bin/activate
    
    # Upgrade pip
    echo -e "${BLUE}Upgrading pip...${NC}"
    pip install --upgrade pip
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        echo -e "${BLUE}Installing Python dependencies...${NC}"
        pip install -r requirements.txt
    else
        echo -e "${YELLOW}⚠️  requirements.txt not found, installing basic dependencies...${NC}"
        pip install fastapi uvicorn pytest black flake8 httpx
    fi
    
    # Install development dependencies
    echo -e "${BLUE}Installing development dependencies...${NC}"
    pip install pytest-cov pytest-watch
    
    echo -e "${GREEN}✅ Python environment ready${NC}"
}

# Function to install Docker
install_docker() {
    print_section "🐳 Installing Docker"
    
    if command_exists docker; then
        echo -e "${GREEN}✅ Docker already installed${NC}"
        docker --version
        return 0
    fi
    
    case "$OS" in
        "linux")
            echo -e "${BLUE}Installing Docker on Linux...${NC}"
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            
            # Start Docker service
            if command_exists systemctl; then
                sudo systemctl start docker
                sudo systemctl enable docker
            else
                echo -e "${YELLOW}⚠️  Starting Docker daemon...${NC}"
                dockerd > /tmp/docker.log 2>&1 &
                sleep 5
            fi
            ;;
        "darwin")
            echo -e "${BLUE}Installing Docker on macOS...${NC}"
            if command_exists brew; then
                brew install --cask docker
            else
                echo -e "${RED}❌ Please install Docker Desktop manually from https://docker.com/products/docker-desktop${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for Docker installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
    echo -e "${YELLOW}⚠️  You may need to log out and back in for Docker group membership to take effect${NC}"
}

# Function to install kubectl
install_kubectl() {
    print_section "☸️ Installing kubectl"
    
    if command_exists kubectl; then
        echo -e "${GREEN}✅ kubectl already installed${NC}"
        kubectl version --client
        return 0
    fi
    
    echo -e "${BLUE}Installing kubectl...${NC}"
    
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
            echo -e "${RED}❌ Unsupported OS for kubectl installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ kubectl installed successfully${NC}"
    kubectl version --client
}

# Function to install Helm
install_helm() {
    print_section "⎈ Installing Helm"
    
    if command_exists helm; then
        echo -e "${GREEN}✅ Helm already installed${NC}"
        helm version
        return 0
    fi
    
    echo -e "${BLUE}Installing Helm...${NC}"
    
    case "$OS" in
        "linux"|"darwin")
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for Helm installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Helm installed successfully${NC}"
    helm version
}

# Function to install Kind
install_kind() {
    print_section "🔧 Installing Kind"
    
    if command_exists kind; then
        echo -e "${GREEN}✅ Kind already installed${NC}"
        kind version
        return 0
    fi
    
    echo -e "${BLUE}Installing Kind...${NC}"
    
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
            echo -e "${RED}❌ Unsupported OS for Kind installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Kind installed successfully${NC}"
    kind version
}

# Function to install ArgoCD CLI
install_argocd_cli() {
    print_section "🎯 Installing ArgoCD CLI"
    
    if command_exists argocd; then
        echo -e "${GREEN}✅ ArgoCD CLI already installed${NC}"
        argocd version --client
        return 0
    fi
    
    echo -e "${BLUE}Installing ArgoCD CLI...${NC}"
    
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
            echo -e "${RED}❌ Unsupported OS for ArgoCD CLI installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ ArgoCD CLI installed successfully${NC}"
    argocd version --client
}

# Function to install ArgoCD
install_argocd() {
    print_section "🎯 Installing ArgoCD"
    
    echo -e "${BLUE}Installing ArgoCD in cluster...${NC}"
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    echo -e "${BLUE}⏳ Waiting for ArgoCD to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
    
    # Configure ArgoCD for insecure access
    echo -e "${BLUE}🔧 Configuring ArgoCD...${NC}"
    kubectl patch deployment argocd-server -n argocd -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json
    
    # Create NodePort service
    echo -e "${BLUE}🌐 Creating ArgoCD NodePort service...${NC}"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
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
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get admin password
    echo -e "${BLUE}🔑 Getting ArgoCD admin password...${NC}"
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
    echo "$ARGOCD_PASSWORD" > .argocd-password
    
    echo -e "${GREEN}✅ ArgoCD installed successfully${NC}"
    echo -e "${GREEN}🔑 Admin password saved to .argocd-password${NC}"
}

# Function to install additional tools
install_additional_tools() {
    print_section "🛠️ Installing Additional Tools"
    
    echo -e "${BLUE}Installing useful tools...${NC}"
    
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
        echo -e "${BLUE}Installing GitHub CLI...${NC}"
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
    
    echo -e "${GREEN}✅ Additional tools installed${NC}"
}

# Function to create Kind cluster
create_kind_cluster() {
    print_section "🚀 Creating Kind Cluster"
    
    CLUSTER_NAME="gitops-cluster"
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        echo -e "${YELLOW}⚠️  Cluster '$CLUSTER_NAME' already exists. Deleting...${NC}"
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    echo -e "${BLUE}Creating Kind cluster with configuration...${NC}"
    
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
    hostPort: ${TARGET_PORT}
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF
    
    # Create cluster
    kind create cluster --config infra/kind/cluster-config.yaml
    
    # Wait for cluster to be ready
    echo -e "${BLUE}⏳ Waiting for cluster to be ready...${NC}"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Install ingress-nginx
    echo -e "${BLUE}🌐 Installing ingress-nginx...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    
    # Create namespaces
    echo -e "${BLUE}📁 Creating namespaces...${NC}"
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}✅ Kind cluster created successfully${NC}"
    kubectl cluster-info
}

# Function to build and load application
build_application() {
    print_section "🐳 Building Application Container"
    
    echo -e "${BLUE}Building student-tracker image...${NC}"
    
    # Ensure Dockerfile exists
    if [ ! -f "docker/Dockerfile" ]; then
        echo -e "${YELLOW}⚠️  Creating basic Dockerfile...${NC}"
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
    fi
    
    # Build image
    docker build -t student-tracker:latest -f docker/Dockerfile .
    
    # Load image into Kind cluster
    echo -e "${BLUE}Loading image into Kind cluster...${NC}"
    kind load docker-image student-tracker:latest --name gitops-cluster
    
    echo -e "${GREEN}✅ Application built and loaded${NC}"
}

# Function to create Helm chart
create_helm_chart() {
    print_section "📦 Creating Helm Chart"
    
    # Create Chart.yaml
    cat <<EOF > infra/helm/Chart.yaml
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
    
    # Create values.yaml
    cat <<EOF > infra/helm/values.yaml
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
  nodePort: 30011  # Maps to 8011 on the host

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: 18.208.149.195
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
    cat <<EOF > infra/helm/templates/deployment.yaml
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
    cat <<EOF > infra/helm/templates/service.yaml
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
    cat <<EOF > infra/helm/templates/configmap.yaml
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
    cat <<EOF > infra/helm/templates/_helpers.tpl
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
    
    echo -e "${GREEN}✅ Helm chart created successfully${NC}"
}

# Function to deploy application
deploy_application() {
    print_section "🚀 Deploying Application"
    
    # Deploy using Helm
    echo -e "${BLUE}Deploying with Helm...${NC}"
    helm upgrade --install student-tracker infra/helm \
        --namespace app-dev \
        --create-namespace \
        --wait \
        --timeout=300s
    
    echo -e "${GREEN}✅ Application deployed successfully${NC}"
    kubectl get pods -n app-dev
}

# Function to setup GitOps
setup_gitops() {
    print_section "🔄 Setting up GitOps with ArgoCD"
    
    # Create app-of-apps application
    cat <<EOF > infra/argocd/parent/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/bonaventuresimeon/Student-Tracker.git
    targetRevision: HEAD
    path: infra/argocd/parent
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    # Apply the app-of-apps
    echo -e "${BLUE}Creating ArgoCD applications...${NC}"
    kubectl apply -f infra/argocd/parent/app-of-apps.yaml
    
    echo -e "${GREEN}✅ GitOps setup complete${NC}"
}

# Function to verify installation
verify_installation() {
    print_section "✅ Verifying Installation"
    
    echo -e "${BLUE}Checking all components...${NC}"
    
    # Check cluster
    echo -e "${CYAN}Kubernetes Cluster:${NC}"
    kubectl cluster-info
    kubectl get nodes
    
    # Check application
    echo -e "${CYAN}Application Pods:${NC}"
    kubectl get pods -n app-dev
    
    # Check services
    echo -e "${CYAN}Services:${NC}"
    kubectl get svc -n app-dev
    
    # Check ArgoCD
    echo -e "${CYAN}ArgoCD:${NC}"
    kubectl get pods -n argocd
    
    # Test application health
    echo -e "${BLUE}Testing application health...${NC}"
    sleep 30  # Wait for application to be ready
    
    if kubectl port-forward svc/student-tracker -n app-dev 8080:80 &>/dev/null &
    then
        PF_PID=$!
        sleep 5
        if curl -s http://localhost:8080/health >/dev/null; then
            echo -e "${GREEN}✅ Application health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  Application health check failed - may need more time to start${NC}"
        fi
        kill $PF_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Installation verification complete${NC}"
}

# Function to display final information
display_final_info() {
    print_section "🎉 Installation Complete!"
    
    echo -e "${GREEN}🚀 Student Tracker GitOps Stack Successfully Installed!${NC}"
    echo -e ""
    echo -e "${CYAN}📋 Access Information:${NC}"
    echo -e "  🌐 Student Tracker: http://${TARGET_IP}:${TARGET_PORT}"
    echo -e "  🌐 Local access: http://localhost:${TARGET_PORT}"
    echo -e "  📖 API Docs: http://${TARGET_IP}:${TARGET_PORT}/docs"
    echo -e "  🩺 Health Check: http://${TARGET_IP}:${TARGET_PORT}/health"
    echo -e ""
    echo -e "  🎯 ArgoCD UI: http://${TARGET_IP}:${ARGOCD_PORT}"
    echo -e "  🎯 Local ArgoCD: http://localhost:${ARGOCD_PORT}"
    echo -e "  👤 ArgoCD Username: admin"
    echo -e "  🔑 ArgoCD Password: $(cat .argocd-password 2>/dev/null || echo 'Check .argocd-password file')"
    echo -e ""
    echo -e "${CYAN}🛠️  Useful Commands:${NC}"
    echo -e "  # Check application status"
    echo -e "  kubectl get all -n app-dev"
    echo -e ""
    echo -e "  # View application logs"
    echo -e "  kubectl logs -f deployment/student-tracker -n app-dev"
    echo -e ""
    echo -e "  # Port forward for local access"
    echo -e "  kubectl port-forward svc/student-tracker -n app-dev 8000:80"
    echo -e ""
    echo -e "  # Access ArgoCD locally"
    echo -e "  kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80"
    echo -e ""
    echo -e "${CYAN}📚 Next Steps:${NC}"
    echo -e "  1. Update repository URLs in ArgoCD applications"
    echo -e "  2. Configure your load balancer to route ${TARGET_IP} to your cluster"
    echo -e "  3. Set up continuous deployment with GitHub Actions"
    echo -e "  4. Configure monitoring and logging (optional)"
    echo -e ""
    echo -e "${YELLOW}📝 Important Notes:${NC}"
    echo -e "  • ArgoCD password is saved in .argocd-password file"
    echo -e "  • Virtual environment is in ./venv directory"
    echo -e "  • Kind cluster name: gitops-cluster"
    echo -e "  • All configurations are in infra/ directory"
    echo -e ""
    echo -e "${GREEN}🎉 Happy coding with GitOps! 🚀${NC}"
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
    echo -e "  • Application deployment to ${TARGET_IP}:${TARGET_PORT}"
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
}

# Check if script is run as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please don't run this script as root${NC}"
    exit 1
fi

# Run main function
main "$@"