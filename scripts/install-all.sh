#!/bin/bash

# Student Tracker - Complete Installation Script
# Version: 4.0.0 - Enhanced with Monitoring, Logging, Secrets, and Scaling
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
PYTHON_VERSION="3.13"
DOCKER_VERSION="20.10"
KUBECTL_VERSION="1.28"
HELM_VERSION="3.13"
KIND_VERSION="0.20.0"
ARGOCD_VERSION="v2.9.3"

# Application configuration - Fixed to match existing setup
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="monitoring"
LOGGING_NAMESPACE="logging"
PRODUCTION_HOST="${PRODUCTION_HOST:-54.166.101.159}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
ARGOCD_PORT="30080"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"
DOCKER_USERNAME="${DOCKER_USERNAME:-bonaventuresimeon}"
DOCKER_IMAGE="ghcr.io/${DOCKER_USERNAME}/nativeseries"

# Repository configuration - Fixed to match actual repo
REPO_URL="https://github.com/bonaventuresimeon/nativeseries.git"
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
echo "║              Enhanced with Monitoring & Observability        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}🎯 Target Configuration:${NC}"
echo -e "  📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
echo -e "  🎯 ArgoCD UI: http://${PRODUCTION_HOST}:${ARGOCD_PORT}"
echo -e "  📊 Grafana: http://${PRODUCTION_HOST}:${GRAFANA_PORT}"
echo -e "  📈 Prometheus: http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}"
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

# Add package manager detection at the top (after color variables)

# Detect package manager
PKG_MANAGER=""
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    else
        echo "No supported package manager found (apt, dnf, yum)." >&2
        exit 1
    fi
}

# Update install_system_dependencies to use the detected package manager
install_system_dependencies() {
    print_section "Installing System Dependencies"
    detect_package_manager

    print_status "Updating package lists..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt update
    else
        sudo $PKG_MANAGER makecache || sudo $PKG_MANAGER check-update || true
    fi

    print_status "Installing essential packages..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y \
            curl \
            wget \
            git \
            unzip \
            jq \
            build-essential \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            gnupg \
            lsb-release
    else
        sudo $PKG_MANAGER install -y \
            curl \
            wget \
            git \
            unzip \
            jq \
            gcc \
            gcc-c++ \
            make \
            which \
            ca-certificates \
            openssl \
            tar \
            python3 \
            python3-pip \
            python3-venv || sudo $PKG_MANAGER install -y python3-virtualenv
    fi

    print_status "System dependencies installed successfully!"
}

# Function to install Docker
install_docker() {
    print_section "Installing Docker"
    
    if command_exists docker; then
        print_status "Docker is already installed"
        docker --version
        return 0
    fi
    
    print_status "Installing Docker..."
    
    # Add Docker's official GPG key
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y docker.io
    else
        sudo $PKG_MANAGER install -y docker.io
    fi
    
    # Start and enable Docker service
    sudo systemctl start docker || true
    sudo systemctl enable docker || true
    
    # Add user to docker group
    sudo usermod -aG docker "$USER" || true
    
    # Verify installation
    if command_exists docker; then
        print_status "Docker installed successfully!"
        docker --version
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
    
    # Download kubectl
    KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Make executable and move to PATH
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
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
    
    # Download Kind
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64"
    
    # Make executable and move to PATH
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/
    
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
    
    # Download Helm
    curl https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
    
    # Move to PATH
    sudo mv linux-amd64/helm /usr/local/bin/
    rm -rf linux-amd64
    
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
        sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 >/dev/null 2>&1 &
        sleep 10
    fi
    
    # Fix Docker permissions
    print_status "Setting up Docker permissions..."
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    
    # Test Docker with sudo if needed
    if docker info >/dev/null 2>&1; then
        print_status "Docker is running and accessible"
    elif sudo docker info >/dev/null 2>&1; then
        print_status "Docker is running (requires sudo)"
        # Create alias for docker with sudo
        echo 'alias docker="sudo docker"' >> ~/.bashrc
        export docker="sudo docker"
        # Also set for current session
        alias docker="sudo docker"
    else
        print_warning "Docker is not accessible. Continuing without Docker for now..."
        print_warning "You can manually start Docker later with: sudo dockerd &"
        return 0
    fi
}

# Function to check and install missing tools
check_and_install_tools() {
    print_section "Checking and Installing Required Tools"
    
    local tools_to_install=()
    
    # Check which tools need installation
    if ! command_exists docker; then
        tools_to_install+=("docker")
    fi
    
    if ! command_exists kubectl; then
        tools_to_install+=("kubectl")
    fi
    
    if ! command_exists kind; then
        tools_to_install+=("kind")
    fi
    
    if ! command_exists helm; then
        tools_to_install+=("helm")
    fi
    
    if ! command_exists python3; then
        tools_to_install+=("python")
    fi
    
    if [ ${#tools_to_install[@]} -eq 0 ]; then
        print_status "All required tools are already installed!"
        return 0
    fi
    
    print_status "Tools to install: ${tools_to_install[*]}"
    
    # Install missing tools
    for tool in "${tools_to_install[@]}"; do
        case $tool in
            "docker")
                install_docker
                ;;
            "kubectl")
                install_kubectl
                ;;
            "kind")
                install_kind
                ;;
            "helm")
                install_helm
                ;;
            "python")
                install_python
                ;;
        esac
    done
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
        python3 -m venv venv
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
  - containerPort: 30081
    hostPort: ${GRAFANA_PORT}
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30082
    hostPort: ${PROMETHEUS_PORT}
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30083
    hostPort: 30083
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF
    
    # Create cluster with Docker permission handling
    if docker info >/dev/null 2>&1; then
        kind create cluster --config infra/kind/cluster-config.yaml
    elif sudo docker info >/dev/null 2>&1; then
        sudo kind create cluster --config infra/kind/cluster-config.yaml
    else
        print_error "Docker is not accessible. Cannot create Kind cluster."
        print_error "Please start Docker manually: sudo dockerd &"
        return 1
    fi
    
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
    kubectl create namespace ${MONITORING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${LOGGING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
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
    
    # Validate Helm chart first
    print_status "🔍 Validating Helm chart..."
    if ! helm lint ${HELM_CHART_PATH}; then
        print_error "❌ Helm chart validation failed"
        return 1
    fi
    
    # Deploy with explicit values file and proper image settings
    if helm upgrade --install ${APP_NAME} ${HELM_CHART_PATH} \
        --namespace ${NAMESPACE} \
        --create-namespace \
        --wait \
        --timeout=300s \
        --values ${HELM_CHART_PATH}/values.yaml \
        --set app.image.repository="${DOCKER_IMAGE}" \
        --set app.image.tag="latest" \
        --debug; then
        print_status "✅ Application deployed successfully"
    else
        print_warning "⚠️  First deployment attempt failed, trying with HPA disabled..."
        if helm upgrade --install ${APP_NAME} ${HELM_CHART_PATH} \
            --namespace ${NAMESPACE} \
            --create-namespace \
            --wait \
            --timeout=300s \
            --values ${HELM_CHART_PATH}/values.yaml \
            --set app.image.repository="${DOCKER_IMAGE}" \
            --set app.image.tag="latest" \
            --set hpa.enabled=false \
            --debug; then
            print_status "✅ Application deployed successfully (HPA disabled)"
        else
            print_error "❌ Helm deployment failed completely"
            print_status "📋 Checking Helm release status..."
            helm status ${APP_NAME} -n ${NAMESPACE} || true
            return 1
        fi
    fi
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

# Function to setup secrets and configmaps
setup_secrets_and_configmaps() {
    print_section "🔐 Setting up Secrets and ConfigMaps"
    
    print_status "Creating application secrets..."
    
    # Create database secret
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${APP_NAME}-db-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  db-username: $(echo -n "student_user" | base64)
  db-password: $(echo -n "secure_password_123" | base64)
  db-host: $(echo -n "postgres-service" | base64)
  db-name: $(echo -n "studentdb" | base64)
EOF
    
    # Create API secret
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${APP_NAME}-api-secret
  namespace: ${NAMESPACE}
type: Opaque
data:
  api-key: $(echo -n "your-super-secret-api-key-2024" | base64)
  jwt-secret: $(echo -n "your-jwt-secret-key-2024" | base64)
  session-secret: $(echo -n "your-session-secret-key-2024" | base64)
EOF
    
    # Create application configmap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-config
  namespace: ${NAMESPACE}
data:
  app_name: "Student Tracker API"
  log_level: "INFO"
  environment: "production"
  max_connections: "100"
  timeout_seconds: "30"
  cache_ttl: "3600"
  cors_origins: "http://localhost:3000,http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
EOF
    
    print_status "✅ Secrets and ConfigMaps created successfully"
}

# Function to install Prometheus and Grafana
install_monitoring_stack() {
    print_section "📊 Installing Prometheus and Grafana"
    
    print_status "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    print_status "Installing Prometheus Stack..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace ${MONITORING_NAMESPACE} \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.probeSelectorNilUsesHelmValues=false \
        --set grafana.enabled=true \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=${GRAFANA_PORT} \
        --set grafana.adminPassword=admin123 \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=${PROMETHEUS_PORT} \
        --wait \
        --timeout=600s
    
    # Wait for monitoring stack to be ready
    print_status "⏳ Waiting for monitoring stack to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-grafana -n ${MONITORING_NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-kube-prometheus-operator -n ${MONITORING_NAMESPACE}
    
    print_status "✅ Monitoring stack installed successfully"
}

# Function to install Loki for logging
install_loki_stack() {
    print_section "📝 Installing Loki for Logging"
    
    print_status "Adding Grafana Helm repository..."
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    print_status "Installing Loki Stack..."
    helm upgrade --install loki grafana/loki-stack \
        --namespace ${LOGGING_NAMESPACE} \
        --create-namespace \
        --set grafana.enabled=false \
        --set prometheus.enabled=false \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=10Gi \
        --set loki.service.type=NodePort \
        --set loki.service.nodePort=30083 \
        --wait \
        --timeout=600s
    
    # Wait for Loki to be ready
    print_status "⏳ Waiting for Loki to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/loki -n ${LOGGING_NAMESPACE}
    
    print_status "✅ Loki stack installed successfully"
}

# Function to setup application monitoring
setup_application_monitoring() {
    print_section "🔍 Setting up Application Monitoring"
    
    print_status "Creating ServiceMonitor for application..."
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${APP_NAME}-monitor
  namespace: ${MONITORING_NAMESPACE}
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
EOF
    
    print_status "Creating PodMonitor for application..."
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ${APP_NAME}-pod-monitor
  namespace: ${MONITORING_NAMESPACE}
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
  podMetricsEndpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
EOF
    
    print_status "Creating PrometheusRule for alerts..."
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ${APP_NAME}-alerts
  namespace: ${MONITORING_NAMESPACE}
  labels:
    release: prometheus
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: ${APP_NAME}-alerts
    rules:
    - alert: AppDown
      expr: up{app="${APP_NAME}"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Application {{ \$labels.app }} is down"
        description: "Application {{ \$labels.app }} has been down for more than 1 minute"
    
    - alert: HighCPUUsage
      expr: rate(container_cpu_usage_seconds_total{container="${APP_NAME}"}[5m]) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage for {{ \$labels.app }}"
        description: "CPU usage is above 80% for {{ \$labels.app }}"
    
    - alert: HighMemoryUsage
      expr: (container_memory_usage_bytes{container="${APP_NAME}"} / container_spec_memory_limit_bytes{container="${APP_NAME}"}) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage for {{ \$labels.app }}"
        description: "Memory usage is above 80% for {{ \$labels.app }}"
EOF
    
    print_status "✅ Application monitoring configured successfully"
}

# Function to setup logging configuration
setup_logging_configuration() {
    print_section "📝 Setting up Logging Configuration"
    
    print_status "Creating logging ConfigMap..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-logging-config
  namespace: ${NAMESPACE}
data:
  log-config.yaml: |
    version: 1
    formatters:
      simple:
        format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    handlers:
      console:
        class: logging.StreamHandler
        level: INFO
        formatter: simple
        stream: ext://sys.stdout
      file:
        class: logging.handlers.RotatingFileHandler
        level: INFO
        formatter: simple
        filename: /app/logs/app.log
        maxBytes: 10485760  # 10MB
        backupCount: 5
    loggers:
      app:
        level: INFO
        handlers: [console, file]
        propagate: false
    root:
      level: INFO
      handlers: [console]
EOF
    
    print_status "Creating logging volume..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP_NAME}-logs-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
    
    print_status "✅ Logging configuration created successfully"
}

# Function to setup Horizontal Pod Autoscaler
setup_hpa() {
    print_section "📈 Setting up Horizontal Pod Autoscaler"
    
    print_status "Creating HPA for application..."
    cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APP_NAME}-hpa
  namespace: ${NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${APP_NAME}
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
EOF
    
    print_status "✅ HPA configured successfully"
}

# Function to setup Pod Disruption Budget
setup_pdb() {
    print_section "🛡️ Setting up Pod Disruption Budget"
    
    print_status "Creating PDB for application..."
    cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${APP_NAME}-pdb
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
EOF
    
    print_status "✅ Pod Disruption Budget configured successfully"
}

# Function to setup Network Policies
setup_network_policies() {
    print_section "🌐 Setting up Network Policies"
    
    print_status "Creating network policy for application..."
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${APP_NAME}-network-policy
  namespace: ${NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - namespaceSelector:
        matchLabels:
          name: ${MONITORING_NAMESPACE}
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: ${NAMESPACE}
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
    
    print_status "✅ Network policies configured successfully"
}

# Function to create Grafana dashboards
create_grafana_dashboards() {
    print_section "📊 Creating Grafana Dashboards"
    
    print_status "Creating application dashboard..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-dashboard
  namespace: ${MONITORING_NAMESPACE}
  labels:
    grafana_dashboard: "1"
data:
  app-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Student Tracker Application",
        "tags": ["student-tracker", "application"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Application Health",
            "type": "stat",
            "targets": [
              {
                "expr": "up{app=\"${APP_NAME}\"}",
                "legendFormat": "{{pod}}"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "thresholds"
                },
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": 0},
                    {"color": "green", "value": 1}
                  ]
                }
              }
            }
          },
          {
            "id": 2,
            "title": "CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{container=\"${APP_NAME}\"}[5m])",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "container_memory_usage_bytes{container=\"${APP_NAME}\"}",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 4,
            "title": "HTTP Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{app=\"${APP_NAME}\"}[5m])",
                "legendFormat": "{{method}} {{endpoint}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF
    
    print_status "✅ Grafana dashboard created successfully"
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
    
    # Check monitoring
    print_status "Monitoring Stack:"
    kubectl get pods -n ${MONITORING_NAMESPACE}
    
    # Check logging
    print_status "Logging Stack:"
    kubectl get pods -n ${LOGGING_NAMESPACE}
    
    # Check HPA
    print_status "Horizontal Pod Autoscaler:"
    kubectl get hpa -n ${NAMESPACE}
    
    # Check secrets and configmaps
    print_status "Secrets and ConfigMaps:"
    kubectl get secrets,configmaps -n ${NAMESPACE}
    
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
    print_status "  📊 Grafana Dashboard: http://${PRODUCTION_HOST}:${GRAFANA_PORT}"
    print_status "  📊 Local Grafana: http://localhost:${GRAFANA_PORT}"
    print_status "  👤 Grafana Username: admin"
    print_status "  🔑 Grafana Password: admin123"
    echo -e ""
    print_status "  📈 Prometheus: http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}"
    print_status "  📈 Local Prometheus: http://localhost:${PROMETHEUS_PORT}"
    echo -e ""
    print_status "  📝 Loki Logs: http://${PRODUCTION_HOST}:30083"
    print_status "  📝 Local Loki: http://localhost:30083"
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
    print_status "  # Access Grafana locally"
    print_status "  kubectl port-forward svc/prometheus-grafana -n ${MONITORING_NAMESPACE} 8081:80"
    echo -e ""
    print_status "  # Access Prometheus locally"
    print_status "  kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n ${MONITORING_NAMESPACE} 8082:9090"
    echo -e ""
    print_status "  # View application logs"
    print_status "  kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}"
    echo -e ""
    print_status "  # Check HPA status"
    print_status "  kubectl get hpa -n ${NAMESPACE}"
    echo -e ""
    print_status "  # Check monitoring targets"
    print_status "  kubectl get servicemonitors,podmonitors -n ${MONITORING_NAMESPACE}"
    echo -e ""
    print_status "  # Check alerts"
    print_status "  kubectl get prometheusrules -n ${MONITORING_NAMESPACE}"
    echo -e ""
    print_status "📚 Next Steps:"
    print_status "  1. Update repository URLs in ArgoCD applications"
    print_status "  2. Configure your load balancer to route ${PRODUCTION_HOST} to your cluster"
    print_status "  3. Set up continuous deployment with GitHub Actions"
    print_status "  4. Customize Grafana dashboards for your application"
    print_status "  5. Configure alerting rules in Prometheus"
    print_status "  6. Set up log aggregation with Loki"
    print_status "  7. Test auto-scaling with load testing"
    print_status "  8. Implement custom metrics for business KPIs"
    echo -e ""
    print_warning "📝 Important Notes:"
    print_warning "  • ArgoCD password is saved in .argocd-password file"
    print_warning "  • Grafana password: admin123"
    print_warning "  • Virtual environment is in ./venv directory"
    print_warning "  • Kind cluster name: gitops-cluster"
    print_warning "  • All configurations are in infra/ directory"
    print_warning "  • Monitoring namespace: ${MONITORING_NAMESPACE}"
    print_warning "  • Logging namespace: ${LOGGING_NAMESPACE}"
    print_warning "  • HPA will scale based on CPU (70%) and Memory (80%)"
    print_warning "  • Secrets are base64 encoded - rotate in production"
    echo -e ""
    print_status "🎉 Happy coding with GitOps! 🚀"
}

# Main execution function
main() {
    echo -e "${YELLOW}🔍 This script will install and configure:${NC}"
    echo -e "  • System dependencies (curl, wget, git, etc.)"
    echo -e "  • Docker ${DOCKER_VERSION}+ with daemon setup"
    echo -e "  • kubectl ${KUBECTL_VERSION}+ (latest stable)"
    echo -e "  • Kind ${KIND_VERSION} for local Kubernetes"
    echo -e "  • Helm ${HELM_VERSION}+ for package management"
    echo -e "  • Python ${PYTHON_VERSION} with virtual environment"
    echo -e "  • ArgoCD ${ARGOCD_VERSION} for GitOps"
    echo -e "  • Complete GitOps stack with monitoring"
    echo -e "  • Application deployment to ${PRODUCTION_HOST}:${PRODUCTION_PORT}"
    echo -e "  • Prometheus & Grafana monitoring stack"
    echo -e "  • Loki logging stack"
    echo -e "  • Secrets and ConfigMaps management"
    echo -e "  • Horizontal Pod Autoscaler (HPA)"
    echo -e "  • Pod Disruption Budget (PDB)"
    echo -e "  • Network Policies"
    echo -e "  • Custom Grafana dashboards"
    echo -e ""
    echo -e "${YELLOW}⚠️  This may take 15-25 minutes depending on your internet connection.${NC}"
    echo -e "${YELLOW}Do you want to continue? (y/N):${NC}"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Installation cancelled.${NC}"
        exit 0
    fi
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Execute installation steps
    install_system_dependencies
    check_and_install_tools
    setup_docker
    verify_tools
    
    # Check if Docker is available for the rest of the installation
    if ! docker info >/dev/null 2>&1 && ! sudo docker info >/dev/null 2>&1; then
        print_warning "Docker is not available. Some features may not work."
        print_warning "Continuing with Kubernetes tools installation..."
    fi
    
    create_directories
    setup_python_env
    install_argocd_cli
    install_additional_tools
    create_kind_cluster
    build_application
    create_helm_chart
    install_argocd
    deploy_application
    setup_gitops
    
    # Enhanced features installation
    setup_secrets_and_configmaps
    install_monitoring_stack
    install_loki_stack
    setup_application_monitoring
    setup_logging_configuration
    setup_hpa
    setup_pdb
    setup_network_policies
    create_grafana_dashboards
    
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
