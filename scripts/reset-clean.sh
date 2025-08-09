#!/usr/bin/env bash
set -euo pipefail

confirm() {
  read -rp "This will PRUNE Docker (images/containers/volumes), delete Kind clusters, and wipe kube config. Continue? (yes/NO): " ans
  [[ "$ans" == "yes" ]]
}

sudo_cmd() { if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi }

main() {
  confirm || { echo "Aborted."; exit 1; }

  echo "Stopping Docker..."
  sudo_cmd systemctl stop docker || true
# Unlock docker.sock for ec2-user
which setfacl >/dev/null 2>&1 && sudo_cmd setfacl -b /var/run/docker.sock || true

  echo "Pruning Docker (images, containers, volumes, networks)..."
  sudo_cmd docker system prune -a -f || true
  sudo_cmd docker volume prune -f || true
  sudo_cmd docker network prune -f || true

  echo "Removing Kind clusters and network..."
  kind get clusters 2>/dev/null | xargs -r -n1 kind delete cluster --name || true
  docker network rm kind || true

  echo "Wiping kube config..."
  rm -f "$HOME/.kube/config"
  rm -rf "$HOME/.kube/cache" "$HOME/.kube/http-cache" || true

  echo "Clearing package caches..."
  (which apt-get >/dev/null 2>&1 && sudo_cmd apt-get clean) || true
  (which dnf >/dev/null 2>&1 && sudo_cmd dnf clean all) || true
  (which yum >/dev/null 2>&1 && sudo_cmd yum clean all) || true

  echo "Reset complete. Reboot is recommended."
}

main "$@"