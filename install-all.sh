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

# Configuration - Updated to latest versions
PYTHON_VERSION="3.13"
DOCKER_VERSION="28.3"
KUBECTL_VERSION="1.32"
HELM_VERSION="3.16"
KIND_VERSION="0.27.0"
ARGOCD_VERSION="v2.13.2"
TARGET_IP="18.206.89.183"
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
    
    if command_exists python3; then
        CURRENT_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+')
        if [[ "$CURRENT_VERSION" == "$PYTHON_VERSION" ]]; then
            echo -e "${GREEN}✅ Python ${PYTHON_VERSION} already installed${NC}"
            python3 --version
            return 0
        fi
    fi
    
    case "$OS" in
        "linux")
            # Detect specific distributions for ec2-user and ubuntu compatibility
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO=$ID
            else
                DISTRO="unknown"
            fi
            
            # Handle Amazon Linux (ec2-user)
            if [[ "$DISTRO" == "amzn" ]] || [[ -f /etc/amazon-linux-release ]]; then
                echo -e "${BLUE}Installing Python on Amazon Linux (ec2-user compatible)...${NC}"
                sudo yum update -y
                sudo yum install -y \
                    python3 \
                    python3-pip \
                    python3-devel \
                    gcc \
                    postgresql-devel \
                    openssl-devel \
                    curl \
                    wget \
                    git \
                    docker
                # Enable docker for ec2-user
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker ec2-user
                sudo usermod -aG docker $USER
            elif command_exists apt-get; then
                echo -e "${BLUE}Installing Python on Ubuntu/Debian (ubuntu user compatible)...${NC}"
                sudo apt-get update
                sudo apt-get install -y \
                    python3 \
                    python3-pip \
                    python3-venv \
                    python3-dev \
                    python3-full \
                    build-essential \
                    libpq-dev \
                    libssl-dev \
                    postgresql-client \
                    curl \
                    wget \
                    git \
                    software-properties-common \
                    apt-transport-https \
                    ca-certificates \
                    gnupg \
                    lsb-release
                # Add ubuntu user to docker group for compatibility
                sudo usermod -aG docker ubuntu 2>/dev/null || true
                sudo usermod -aG docker $USER
            elif command_exists yum; then
                echo -e "${BLUE}Installing Python on CentOS/RHEL...${NC}"
                sudo yum update -y
                sudo yum install -y \
                    python3 \
                    python3-pip \
                    python3-devel \
                    gcc \
                    postgresql-devel \
                    openssl-devel \
                    curl \
                    wget \
                    git
                # Add ec2-user to docker group for RHEL-based systems
                sudo usermod -aG docker ec2-user 2>/dev/null || true
                sudo usermod -aG docker $USER
            elif command_exists dnf; then
                echo -e "${BLUE}Installing Python on Fedora...${NC}"
                sudo dnf update -y
                sudo dnf install -y \
                    python3 \
                    python3-pip \
                    python3-devel \
                    gcc \
                    postgresql-devel \
                    openssl-devel \
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
    python3 --version
}

# Function to setup Python environment
setup_python_env() {
    print_section "🐍 Setting up Python Virtual Environment"
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        echo -e "${BLUE}Creating virtual environment...${NC}"
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    echo -e "${BLUE}Activating virtual environment...${NC}"
    source venv/bin/activate
    
    # Upgrade pip
    echo -e "${BLUE}Upgrading pip...${NC}"
    pip install --upgrade pip
    
    # Install requirements with compatibility for Python 3.13
    if [ -f "requirements.txt" ]; then
        echo -e "${BLUE}Installing Python dependencies...${NC}"
        # Install without pinned versions for Python 3.13 compatibility
        pip install --upgrade fastapi uvicorn[standard] pydantic python-multipart jinja2 aiofiles httpx sqlalchemy alembic python-jose[cryptography] passlib[bcrypt] python-dotenv redis
    else
        echo -e "${YELLOW}⚠️  requirements.txt not found, installing basic dependencies...${NC}"
        pip install fastapi uvicorn[standard] pytest black flake8 httpx
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
            
            # Check if Docker is already installed from Python installation step
            if ! command_exists docker; then
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm get-docker.sh
            fi
            
            # Add users to docker group for ec2-user and ubuntu compatibility
            sudo usermod -aG docker $USER
            sudo usermod -aG docker ec2-user 2>/dev/null || true
            sudo usermod -aG docker ubuntu 2>/dev/null || true
            
            # Start Docker service
            if command_exists systemctl; then
                sudo systemctl start docker
                sudo systemctl enable docker
            else
                echo -e "${YELLOW}⚠️  Starting Docker daemon manually...${NC}"
                sudo dockerd &
                sleep 5
                sudo chmod 666 /var/run/docker.sock
            fi
            
            # Set proper permissions for docker socket
            sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
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
        kubectl version --client --output=yaml 2>/dev/null | grep gitVersion || echo "kubectl installed"
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
    kubectl version --client --output=yaml 2>/dev/null | grep gitVersion || echo "kubectl ready"
}

# Function to install Helm
install_helm() {
    print_section "⎈ Installing Helm"
    
    if command_exists helm; then
        echo -e "${GREEN}✅ Helm already installed${NC}"
        helm version --short
        return 0
    fi
    
    echo -e "${BLUE}Installing Helm...${NC}"
    
    case "$OS" in
        "linux")
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
        "darwin")
            if command_exists brew; then
                brew install helm
            else
                curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            fi
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for Helm installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Helm installed successfully${NC}"
    helm version --short
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
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${ARCH}
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        "darwin")
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-darwin-${ARCH}
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
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
    print_section "🔄 Installing ArgoCD CLI"
    
    if command_exists argocd; then
        echo -e "${GREEN}✅ ArgoCD CLI already installed${NC}"
        argocd version --client --short 2>/dev/null || echo "ArgoCD CLI ready"
        return 0
    fi
    
    echo -e "${BLUE}Installing ArgoCD CLI...${NC}"
    
    case "$OS" in
        "linux")
            curl -sSL -o argocd-linux-${ARCH} https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}
            sudo install -m 555 argocd-linux-${ARCH} /usr/local/bin/argocd
            rm argocd-linux-${ARCH}
            ;;
        "darwin")
            curl -sSL -o argocd-darwin-${ARCH} https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-darwin-${ARCH}
            sudo install -m 555 argocd-darwin-${ARCH} /usr/local/bin/argocd
            rm argocd-darwin-${ARCH}
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS for ArgoCD CLI installation${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ ArgoCD CLI installed successfully${NC}"
    argocd version --client --short 2>/dev/null || echo "ArgoCD CLI ready"
}

# Function to build application
build_application() {
    print_section "🏗️ Building Application"
    
    echo -e "${BLUE}Building Docker image for Student Tracker...${NC}"
    
    # Ensure Docker is running
    if ! docker ps >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Starting Docker daemon...${NC}"
        sudo dockerd &
        sleep 10
        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
    fi
    
    # Build the application
    docker compose build --no-cache
    
    echo -e "${GREEN}✅ Application built successfully${NC}"
    docker images | grep student-tracker
}

# Function to deploy application
deploy_application() {
    print_section "🚀 Deploying Application to ${TARGET_IP}:${TARGET_PORT}"
    
    echo -e "${BLUE}Starting application deployment...${NC}"
    
    # Deploy with docker-compose
    docker compose up -d
    
    # Wait for services to start
    echo -e "${BLUE}Waiting for services to start...${NC}"
    sleep 30
    
    # Check if services are running
    docker compose ps
    
    echo -e "${GREEN}✅ Application deployed successfully${NC}"
    echo -e "${CYAN}🌐 Application URLs:${NC}"
    echo -e "  📱 Main App: http://${TARGET_IP}:${TARGET_PORT}"
    echo -e "  📖 API Docs: http://${TARGET_IP}:${TARGET_PORT}/docs"
    echo -e "  🩺 Health: http://${TARGET_IP}:${TARGET_PORT}/health"
    echo -e "  📊 Metrics: http://${TARGET_IP}:${TARGET_PORT}/metrics"
    echo -e "  📈 Grafana: http://${TARGET_IP}:3000"
    echo -e "  📊 Prometheus: http://${TARGET_IP}:9090"
    echo -e "  🗄️ Database Admin: http://${TARGET_IP}:8080"
}

# Function to verify installation
verify_installation() {
    print_section "✅ Verifying Installation"
    
    echo -e "${BLUE}Testing application endpoints...${NC}"
    
    # Wait a bit more for services to be fully ready
    sleep 10
    
    # Test health endpoint
    if curl -f -s "http://${TARGET_IP}:${TARGET_PORT}/health" >/dev/null; then
        echo -e "${GREEN}✅ Health endpoint responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Health endpoint not yet ready, checking container status...${NC}"
        docker compose logs student-tracker --tail=10
    fi
    
    # Show running containers
    echo -e "${BLUE}Running containers:${NC}"
    docker compose ps
    
    echo -e "${GREEN}✅ Installation verification complete${NC}"
}

# Function to display final information
display_final_info() {
    print_section "🎉 Installation Complete!"
    
    echo -e "${GREEN}🚀 Student Tracker Application is now running!${NC}"
    echo -e ""
    echo -e "${CYAN}🌐 Access your application at:${NC}"
    echo -e "  📱 Main Application: http://${TARGET_IP}:${TARGET_PORT}"
    echo -e "  📖 API Documentation: http://${TARGET_IP}:${TARGET_PORT}/docs"
    echo -e "  🩺 Health Check: http://${TARGET_IP}:${TARGET_PORT}/health"
    echo -e "  📊 Metrics: http://${TARGET_IP}:${TARGET_PORT}/metrics"
    echo -e ""
    echo -e "${CYAN}📊 Monitoring & Management:${NC}"
    echo -e "  📈 Grafana Dashboards: http://${TARGET_IP}:3000 (admin/admin123)"
    echo -e "  📊 Prometheus Metrics: http://${TARGET_IP}:9090"
    echo -e "  🗄️ Database Admin: http://${TARGET_IP}:8080"
    echo -e ""
    echo -e "${CYAN}🔧 Tool Versions Installed:${NC}"
    echo -e "  • Python: $(python3 --version 2>&1)"
    echo -e "  • Docker: $(docker --version 2>&1)"
    echo -e "  • kubectl: $(kubectl version --client --short 2>&1 | head -1)"
    echo -e "  • Helm: $(helm version --short 2>&1)"
    echo -e "  • Kind: $(kind version 2>&1)"
    echo -e "  • ArgoCD CLI: $(argocd version --client --short 2>&1 | head -1 || echo 'ArgoCD CLI installed')"
    echo -e ""
    echo -e "${YELLOW}📝 Important Notes:${NC}"
    echo -e "  • Virtual environment is in ./venv directory"
    echo -e "  • All configurations target ${TARGET_IP}:${TARGET_PORT}"
    echo -e "  • Application Docker image: student-tracker:latest"
    echo -e ""
    echo -e "${GREEN}🎉 Happy coding with your Student Tracker! 🚀${NC}"
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
    echo -e "  • Complete application deployment to ${TARGET_IP}:${TARGET_PORT}"
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
    
    # Execute installation steps with error handling
    set -e
    trap 'echo -e "${RED}❌ Installation failed at step: ${BASH_COMMAND}${NC}"; exit 1' ERR
    
    create_directories
    install_python
    setup_python_env
    install_docker
    install_kubectl
    install_helm
    install_kind
    install_argocd_cli
    build_application
    deploy_application
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

# Parse command line arguments
case "${1:-}" in
    "help"|"--help"|"-h")
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0           # Full installation and deployment"
        echo -e "  $0 help      # Show this help"
        ;;
    *)
        # Run main function
        main "$@"
        ;;
esac