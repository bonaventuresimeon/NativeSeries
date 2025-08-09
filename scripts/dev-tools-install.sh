#!/usr/bin/env bash
set -euo pipefail

# Developer tools installer for Amazon Linux and Ubuntu
# Installs: git, curl, jq, Docker, kubectl, Helm, Kind, ArgoCD CLI

need_cmd() { command -v "$1" >/dev/null 2>&1; }

is_amazon() { [[ -f /etc/os-release ]] && grep -qi "amazon linux" /etc/os-release; }
is_ubuntu() { [[ -f /etc/lsb-release ]] || ( [[ -f /etc/os-release ]] && grep -qi ubuntu /etc/os-release ); }

install_base_amazon() {
  sudo yum -y install git curl jq unzip shadow-utils iptables iptables-services acl || sudo dnf -y install git curl jq unzip shadow-utils iptables iptables-services acl
}
install_base_ubuntu() {
  sudo apt-get update -y
  sudo apt-get install -y git curl jq unzip ca-certificates lsb-release gnupg acl
}

install_docker_amazon() {
  sudo yum -y install docker || sudo dnf -y install docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
  sudo setfacl -m u:"$USER":rw /var/run/docker.sock || true
}
install_docker_ubuntu() {
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm -f get-docker.sh
  sudo usermod -aG docker "$USER" || true
  sudo systemctl enable --now docker || true
  sudo setfacl -m u:"$USER":rw /var/run/docker.sock || true
}

iptables_legacy() {
  if command -v alternatives >/dev/null 2>&1; then
    sudo alternatives --set iptables /usr/sbin/iptables-legacy || true
    sudo alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
    sudo alternatives --set arptables /usr/sbin/arptables-legacy || true
    sudo alternatives --set ebtables /usr/sbin/ebtables-legacy || true
  fi
}

sysctl_bridge() {
  sudo modprobe br_netfilter || true
  sudo sysctl -w net.ipv4.ip_forward=1 || true
  sudo sysctl -w net.bridge.bridge-nf-call-iptables=1 || true
  sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1 || true
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
  iptables_legacy
  sysctl_bridge
  install_kubectl
  install_helm
  install_kind
  install_argocd_cli
  echo "Done. You may need to log out/in for Docker group to take effect."
}

main "$@"