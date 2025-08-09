#!/usr/bin/env bash
set -euo pipefail

# Cross-distro developer tools installer (Ubuntu/Debian and Amazon Linux)
# Installs: git, curl, jq, Docker, kubectl, Helm, Kind, ArgoCD CLI

detect_distro() {
  if command -v apt-get >/dev/null 2>&1; then echo "debian"; return; fi
  if [[ -f /etc/os-release ]] && grep -qi "amazon" /etc/os-release; then echo "amazon"; return; fi
  if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then echo "rhel"; return; fi
  echo "unknown"
}

install_base_debian() {
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https \
    git jq unzip
}

install_docker_debian() {
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm -f get-docker.sh
  sudo usermod -aG docker "$USER" || true
  sudo systemctl enable --now docker || true
}

install_kubectl_generic() {
  if command -v kubectl >/dev/null 2>&1; then return; fi
  curl -fsSLo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
}

install_helm_generic() {
  if command -v helm >/dev/null 2>&1; then return; fi
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_kind_generic() {
  if command -v kind >/dev/null 2>&1; then return; fi
  curl -fsSLo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x kind
  sudo mv kind /usr/local/bin/kind
}

install_argocd_cli_generic() {
  if command -v argocd >/dev/null 2>&1; then return; fi
  curl -fsSLo argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm -f argocd-linux-amd64
}

install_base_amazon() {
  sudo dnf -y install git curl jq unzip shadow-utils || sudo yum -y install git curl jq unzip shadow-utils
}

install_docker_amazon() {
  # Amazon Linux 2023/2
  sudo dnf -y install docker || sudo yum -y install docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
}

main() {
  distro=$(detect_distro)
  case "$distro" in
    debian)
      echo "Detected Debian/Ubuntu. Installing base packages..."
      install_base_debian
      echo "Installing Docker..."
      install_docker_debian
      ;;
    amazon|rhel)
      echo "Detected Amazon Linux/RHEL-family. Installing base packages..."
      install_base_amazon
      echo "Installing Docker..."
      install_docker_amazon
      ;;
    *)
      echo "Unsupported distro. Attempting generic installs..."
      ;;
  esac

  echo "Installing kubectl..."; install_kubectl_generic
  echo "Installing Helm..."; install_helm_generic
  echo "Installing Kind..."; install_kind_generic
  echo "Installing ArgoCD CLI..."; install_argocd_cli_generic

  echo "All tools installed. You may need to log out/in for Docker group changes to take effect."
}

main "$@"