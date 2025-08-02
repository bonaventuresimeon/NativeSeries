#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

log()   { echo -e "${GREEN}→ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️ $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; exit 1; }

log "Using kubeconfig: ${KUBECONFIG:-$HOME/.kube/config}"

CLEAN_PORTS=(8011 30000 80 8000 8080)
echo

# Step 1: Docker cleanup
if command -v docker &>/dev/null; then
  log "Pruning unused Docker images/containers/networks/volumes..."
  docker system prune -a -f --volumes || true  # cleans everything including volumes [oai_citation_attribution:12‡Kubernetes](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/?utm_source=chatgpt.com)
else
  warn "docker not found; skipping."
fi
echo

# Step 2: delete all minikube profiles
if command -v minikube &>/dev/null; then
  log "Deleting all Minikube clusters and profiles..."
  minikube delete --all --purge || true  # removes ~/.minikube too [oai_citation_attribution:11‡minikube](https://minikube.sigs.k8s.io/docs/commands/delete/?utm_source=chatgpt.com)
else
  warn "minikube not found; skipping."
fi
echo

# Step 3: delete all kind clusters
if command -v kind &>/dev/null; then
  log "Deleting all kind clusters..."
  while IFS= read -r cluster; do
    [ -n "$cluster" ] && { log "Deleting kind cluster: $cluster"; kind delete cluster --name "$cluster"; }
  done < <(kind get clusters 2>/dev/null || echo)
  echo
else
  warn "kind not found; skipping."
fi

# Step 4 & 5: purge kubectl contexts, clusters, users, and all namespaced resources
if command -v kubectl &>/dev/null; then
  log "Cleaning Kubernetes resources from reachable clusters..."
  for ctx in $(kubectl config get-contexts --no-headers -o name); do
    log "Deleting resources in context: $ctx"
    kubectl --context="$ctx" delete all --all --all-namespaces   --grace-period=5 --timeout=60s || true
    kubectl --context="$ctx" delete namespace --all --grace-period=5 --timeout=60s || true
  done
  echo
  log "Removing all contexts, clusters & users from kubeconfig..."
  for ctx in $(kubectl config get-contexts --no-headers -o name); do
    kubectl config delete-context "$ctx" || true
  done
  for cls in $(kubectl config get-clusters -o name); do
    kubectl config delete-cluster "$cls" || true  # delete cluster entry [oai_citation_attribution:9‡Kubernetes](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_delete-cluster/?utm_source=chatgpt.com)[oai_citation_attribution:10‡Kubernetes](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands?utm_source=chatgpt.com)
  done
  for usr in $(kubectl config view -o jsonpath='{.users[*].name}'); do
    kubectl config unset users."$usr" || true     # remove user entry [oai_citation_attribution:7‡Kubernetes](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_unset/?utm_source=chatgpt.com)[oai_citation_attribution:8‡Kubernetes](https://kubernetes.io/docs/reference/kubectl/quick-reference/?utm_source=chatgpt.com)
  done
else
  warn "kubectl not found; skipping Kubernetes cleanup."
fi
echo

# Step 6: Free up designated ports
log "Cleaning up ports: ${CLEAN_PORTS[*]}"
if ! command -v lsof &>/dev/null; then
  warn "lsof not found, skipping port cleanup."
else
  for p in "${CLEAN_PORTS[@]}"; do
    pids=$(lsof -t -i tcp:"$p" 2>/dev/null || true)
    if [ -n "$pids" ]; then
      log "Port $p is being used by PID(s): $pids"
      kill $pids && log "Sent SIGTERM to $pids (port $p)"
      sleep 1
      still=$(lsof -t -i tcp:"$p")
      if [ -n "$still" ]; then
        warn "Port $p still in use after SIGTERM. Doing kill -9 now."
        kill -9 $still || warn "Failed to KILL -9 $still"
      fi
    else
      log "Port $p is free."
    fi
  done
fi
echo

log "Environment reset complete — you're now in a clean state."
