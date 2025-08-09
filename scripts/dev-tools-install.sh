#!/usr/bin/env bash
set -euo pipefail

# Developer tools installer for Amazon Linux and Ubuntu (no iptables/bridge tweaks)
# Installs: git, curl, jq, yq, unzip, net-tools, Docker, kubectl, Helm, Kind, ArgoCD CLI, Python/venv/pip

need_cmd() { command -v "$1" >/dev/null 2>&1; }

is_amazon() { [[ -f /etc/os-release ]] && grep -qi "amazon linux" /etc/os-release; }
is_ubuntu() { [[ -f /etc/lsb-release ]] || ( [[ -f /etc/os-release ]] && grep -qi ubuntu /etc/os-release ); }

install_base_amazon() {
  sudo yum -y install git curl jq unzip net-tools python3 python3-pip || sudo dnf -y install git curl jq unzip net-tools python3 python3-pip
}
install_base_ubuntu() {
  sudo apt-get update -y
  sudo apt-get install -y git curl jq unzip net-tools python3 python3-venv python3-pip
}

install_yq() {
  if need_cmd yq; then return; fi
  curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq && sudo mv yq /usr/local/bin/yq
}

install_docker_amazon() {
  # Prefer system docker package on AL2023
  sudo yum -y install docker || sudo dnf -y install docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
  command -v setfacl >/dev/null 2>&1 && sudo setfacl -m u:"$USER":rw /var/run/docker.sock || true
}
install_docker_ubuntu() {
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh || true
  rm -f get-docker.sh
  sudo usermod -aG docker "$USER" || true
  sudo systemctl enable --now docker || true
  command -v setfacl >/dev/null 2>&1 && sudo setfacl -m u:"$USER":rw /var/run/docker.sock || true
}

install_kubectl() {
  if need_cmd kubectl; then return; fi
  curl -fsSLo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl
}
install_helm() {
  if need_cmd helm; then return; fi
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}
install_kind() {
  if need_cmd kind; then return; fi
  curl -fsSLo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x kind && sudo mv kind /usr/local/bin/kind
}
install_argocd_cli() {
  if need_cmd argocd; then return; fi
  curl -fsSLo argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm -f argocd-linux-amd64
}

main() {
  if is_amazon; then
    echo "Detected Amazon Linux"; install_base_amazon; install_docker_amazon
  elif is_ubuntu; then
    echo "Detected Ubuntu"; install_base_ubuntu; install_docker_ubuntu
  else
    echo "Unsupported distro; attempting generic installs"
  fi
  install_yq
  install_kubectl
  install_helm
  install_kind
  install_argocd_cli
  echo "Done. You may need to log out/in for Docker group to take effect."
}

main "$@"