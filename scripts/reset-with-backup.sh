#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=${1:-"$HOME/ns-backup-$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$BACKUP_DIR"

sudo_cmd() { if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi }

main() {
  echo "Backing up to $BACKUP_DIR"

  echo "Saving Docker metadata..."
  docker images -a > "$BACKUP_DIR/docker-images.txt" 2>/dev/null || true
  docker ps -a > "$BACKUP_DIR/docker-containers.txt" 2>/dev/null || true
  docker network ls > "$BACKUP_DIR/docker-networks.txt" 2>/dev/null || true

  echo "Backing up kube config and ArgoCD Applications..."
  cp -f "$HOME/.kube/config" "$BACKUP_DIR/kubeconfig" 2>/dev/null || true
  kubectl get applications.argoproj.io -A -o yaml > "$BACKUP_DIR/argocd-apps.yaml" 2>/dev/null || true

  echo "Running reset-clean..."
  "$(dirname "$0")/reset-clean.sh"
}

main "$@"