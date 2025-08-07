#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Print helpers
print_status() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# Trap errors
trap 'print_error "Failed at line $LINENO: $BASH_COMMAND"; exit 1' ERR

# Detect OS and package manager
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
esac

if command -v apt-get >/dev/null 2>&1; then
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
  print_error "Unsupported OS or package manager."
  exit 1
fi
print_info "Detected $OS_TYPE ($PKG_MANAGER) on $ARCH"

# Proxy support
if [ -n "${HTTP_PROXY:-}" ]; then
  print_info "Using HTTP proxy: $HTTP_PROXY"
fi

# Checksum validation
validate_checksum() {
  local file="$1"
  local checksum_file="$2"
  if [ -f "$checksum_file" ]; then
    echo "  Verifying checksum for $file..."
    if echo "$(cat $checksum_file)  $file" | sha256sum --check; then
      rm -f "$checksum_file"
      return 0
    else
      print_error "$file checksum failed!"
      return 1
    fi
  fi
  return 0
}

# Install system tools
install_system_tools() {
  print_info "Installing system tools..."
  if [ "$PKG_MANAGER" = "apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y curl wget git unzip jq gcc g++ make python3 python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev ca-certificates gnupg lsb-release software-properties-common apt-transport-https
  elif [ "$PKG_MANAGER" = "zypper" ]; then
    sudo zypper --non-interactive refresh
    sudo zypper --non-interactive install --auto-agree-with-licenses curl wget git unzip jq gcc gcc-c++ make python3 python3-pip python3-venv python3-devel libopenssl-devel libffi-devel ca-certificates gpg2
  elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    sudo $PKG_MANAGER update -y --allowerasing --skip-broken
    sudo $PKG_MANAGER install -y curl wget git unzip jq gcc gcc-c++ make python3 python3-pip python3-devel openssl-devel libffi-devel ca-certificates gnupg2 --allowerasing --skip-broken
  fi
  print_status "System tools installed"
}

# Install Docker
install_docker() {
  print_info "Installing Docker..."
  if command -v docker >/dev/null 2>&1; then
    print_status "Docker already installed"
    return
  fi
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [ "$PKG_MANAGER" = "zypper" ]; then
    sudo zypper --non-interactive install --auto-agree-with-licenses docker
  elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    if grep -qi 'amazon' /etc/os-release; then
      sudo $PKG_MANAGER install -y docker
    else
      sudo $PKG_MANAGER install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --allowerasing --skip-broken
    fi
  fi
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker $USER
  print_status "Docker installed"
}

# Install kubectl
install_kubectl() {
  print_info "Installing kubectl..."
  KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -s https://dl.k8s.io/release/stable.txt | cut -c 2-)}"
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
  else
    KUBECTL_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
    curl -LO "$KUBECTL_URL"
    curl -LO "$KUBECTL_URL.sha256"
    validate_checksum kubectl kubectl.sha256
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
  fi
  print_status "kubectl installed"
}

# Install Helm
install_helm() {
  print_info "Installing Helm..."
  HELM_VERSION="${HELM_VERSION:-$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
  HELM_URL="https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
  curl -LO "$HELM_URL"
  curl -LO "$HELM_URL.sha256sum"
  validate_checksum helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz.sha256sum
  tar -zxvf helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz
  sudo mv ${OS}-${ARCH}/helm /usr/local/bin/helm
  rm -rf ${OS}-${ARCH} helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz.sha256sum
  print_status "Helm installed"
}

# Install Kind
install_kind() {
  print_info "Installing Kind..."
  KIND_VERSION="${KIND_VERSION:-$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
  KIND_URL="https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
  curl -Lo kind "$KIND_URL"
  curl -Lo kind.sha256 "${KIND_URL}.sha256sum" || true
  validate_checksum kind kind.sha256
  chmod +x kind
  sudo mv kind /usr/local/bin/kind
  print_status "Kind installed"
}

# Install yq
install_yq() {
  print_info "Installing yq..."
  YQ_VERSION="${YQ_VERSION:-$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')}"
  YQ_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${OS}_${ARCH}"
  curl -Lo yq "$YQ_URL"
  curl -Lo yq.sha256 "${YQ_URL}.sha256sum" || true
  validate_checksum yq yq.sha256
  chmod +x yq
  sudo mv yq /usr/local/bin/yq
  print_status "yq installed"
}

# Install Python venv and pip
install_python_venv() {
  print_info "Setting up Python venv..."
  if [ ! -d "venv" ]; then
    python3 -m venv venv
  fi
  source venv/bin/activate
  pip install --upgrade pip setuptools wheel
  print_status "Python venv ready"
}

# Install Node.js (LTS)
install_node() {
  print_info "Installing Node.js..."
  NODE_VERSION="${NODE_VERSION:-lts}"
  if command -v nvm >/dev/null 2>&1; then
    print_info "Using nvm to install Node.js $NODE_VERSION"
    nvm install $NODE_VERSION
    nvm use $NODE_VERSION
  else
    if [ "$PKG_MANAGER" = "apt" ]; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
      curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
      sudo $PKG_MANAGER install -y nodejs
    elif [ "$PKG_MANAGER" = "zypper" ]; then
      curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
      sudo zypper --non-interactive install --auto-agree-with-licenses nodejs
    fi
  fi
  print_status "Node.js installed"
}

# Install Go (latest stable)
install_go() {
  print_info "Installing Go..."
  GO_VERSION="${GO_VERSION:-$(curl -s https://go.dev/VERSION?m=text | head -n1 | cut -c 3-)}"
  GO_URL="https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
  curl -LO "$GO_URL"
  tar -C /usr/local -xzf go${GO_VERSION}.${OS}-${ARCH}.tar.gz
  rm -f go${GO_VERSION}.${OS}-${ARCH}.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
  print_status "Go installed"
}

# Install Java (OpenJDK 17+)
install_java() {
  print_info "Installing OpenJDK..."
  JAVA_VERSION="${JAVA_VERSION:-17}"
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get install -y openjdk-${JAVA_VERSION}-jdk
  elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    sudo $PKG_MANAGER install -y java-${JAVA_VERSION}-openjdk-devel
  elif [ "$PKG_MANAGER" = "zypper" ]; then
    sudo zypper --non-interactive install --auto-agree-with-licenses java-${JAVA_VERSION}-openjdk-devel
  fi
  print_status "OpenJDK installed"
}

# Install Rust (via rustup)
install_rust() {
  print_info "Installing Rust..."
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  if [ -n "${RUST_VERSION:-}" ]; then
    rustup install "$RUST_VERSION"
    rustup default "$RUST_VERSION"
  fi
  print_status "Rust installed"
}

# Main
install_system_tools
install_docker
install_kubectl
install_helm
install_kind
install_yq
install_python_venv
install_node
install_go
install_java
install_rust
print_status "All tools installed and ready!"