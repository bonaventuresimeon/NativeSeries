#!/usr/bin/env bash
set -euo pipefail

# Simple, end-to-end installer for: cluster (Kind), kubectl, helm, ArgoCD, Prometheus, Grafana, Loki, and the app
# Cluster name: gitops
# Namespaces: nativeseries, argocd, monitoring, logging

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
KIND_CLUSTER_NAME="gitops"
KIND_CONFIG_PATH_BASE="$REPO_ROOT/infra/kind/gitops-cluster-config.yaml"
KIND_CONFIG_PATH_TMP="/tmp/gitops-kind-config.yaml"

# Default ports. Will be adjusted if busy on host
GRAFANA_NODEPORT_DEFAULT=30081
PROMETHEUS_NODEPORT_DEFAULT=30082
LOKI_NODEPORT_DEFAULT=30083
ARGOCD_NODEPORT_DEFAULT=30080
APP_NODEPORT_DEFAULT=30011

# Resolved ports after probing
GRAFANA_NODEPORT=""
PROMETHEUS_NODEPORT=""
LOKI_NODEPORT=""
ARGOCD_NODEPORT=""
APP_NODEPORT=""

PUBLIC_HOST=${PUBLIC_HOST:-}
if [[ -z "${PUBLIC_HOST}" ]]; then
  PUBLIC_HOST=$(curl -fsSL https://checkip.amazonaws.com || true)
  if [[ -z "${PUBLIC_HOST}" ]]; then
    PUBLIC_HOST=$(hostname -I | awk '{print $1}')
  fi
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

wait_for_docker() {
  if ! need_cmd docker; then return; fi
  echo "Ensuring Docker daemon is running..."
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now docker || true
  fi
  # Wait up to 20s for docker
  for i in {1..20}; do
    if docker info >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  echo "Warning: Docker daemon not responding; Kind may fail."
}

install_kubectl() {
  if need_cmd kubectl; then return; fi
  echo "Installing kubectl..."
  curl -fsSLo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
}

install_helm() {
  if need_cmd helm; then return; fi
  echo "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_kind() {
  if need_cmd kind; then return; fi
  echo "Installing Kind..."
  curl -fsSLo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x kind
  sudo mv kind /usr/local/bin/kind
}

install_argocd_cli() {
  if need_cmd argocd; then return; fi
  echo "Installing ArgoCD CLI..."
  curl -fsSLo argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm -f argocd-linux-amd64
}

is_port_free() {
  local port="$1"
  ! ss -ltn "sport = :$port" 2>/dev/null | grep -q ":$port"
}

pick_port() {
  local preferred="$1"; shift
  local candidates=("$preferred" "$@")
  for p in "${candidates[@]}"; do
    if is_port_free "$p"; then echo "$p"; return 0; fi
  done
  # Last resort: auto-pick a free ephemeral port >= 30000
  for p in $(seq 30000 32767); do
    if is_port_free "$p"; then echo "$p"; return 0; fi
  done
  return 1
}

resolve_ports() {
  echo "Resolving NodePort conflicts if any..."
  ARGOCD_NODEPORT=$(pick_port "$ARGOCD_NODEPORT_DEFAULT" 30480 32080 31080)
  APP_NODEPORT=$(pick_port "$APP_NODEPORT_DEFAULT" 31011 32011 30012)
  GRAFANA_NODEPORT=$(pick_port "$GRAFANA_NODEPORT_DEFAULT" 31081 32081 30084)
  PROMETHEUS_NODEPORT=$(pick_port "$PROMETHEUS_NODEPORT_DEFAULT" 31082 32082 30085)
  LOKI_NODEPORT=$(pick_port "$LOKI_NODEPORT_DEFAULT" 31083 32083 30086)
  echo "Using ports -> App:$APP_NODEPORT ArgoCD:$ARGOCD_NODEPORT Grafana:$GRAFANA_NODEPORT Prometheus:$PROMETHEUS_NODEPORT Loki:$LOKI_NODEPORT"
}

generate_kind_config() {
  echo "Generating Kind config with resolved host ports..."
  sed -E \
    -e "s/hostPort: 30011/hostPort: ${APP_NODEPORT}/g" \
    -e "s/hostPort: 30080/hostPort: ${ARGOCD_NODEPORT}/g" \
    -e "s/hostPort: 30081/hostPort: ${GRAFANA_NODEPORT}/g" \
    -e "s/hostPort: 30082/hostPort: ${PROMETHEUS_NODEPORT}/g" \
    -e "s/hostPort: 30083/hostPort: ${LOKI_NODEPORT}/g" \
    "$KIND_CONFIG_PATH_BASE" > "$KIND_CONFIG_PATH_TMP"
}

generate_argocd_manifests() {
  echo "Preparing ArgoCD manifests with resolved NodePorts..."
  # ArgoCD server NodePort
  sed -E \
    -e "s/nodePort: [0-9]+/nodePort: ${ARGOCD_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/argocd-nodeport.yaml" > /tmp/argocd-nodeport.yaml

  # kube-prometheus-stack Application (Grafana/Prometheus NodePorts + Loki datasource URL)
  sed -E \
    -e "s/nodePort: 30081/nodePort: ${GRAFANA_NODEPORT}/" \
    -e "s/nodePort: 30082/nodePort: ${PROMETHEUS_NODEPORT}/" \
    -e "s#http://loki-stack\\.logging\\.svc\\.cluster\\.local:3100#http://loki-stack.logging.svc.cluster.local:3100#" \
    "$REPO_ROOT/infra/argocd/kube-prometheus-app.yaml" > /tmp/kube-prometheus-app.yaml

  # loki-stack Application (Loki NodePort)
  sed -E \
    -e "s/nodePort: 30083/nodePort: ${LOKI_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/loki-stack-app.yaml" > /tmp/loki-stack-app.yaml

  # App Application (Service NodePort)
  sed -E \
    -e "s/nodePort: 30011/nodePort: ${APP_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/application.yaml" > /tmp/nativeseries-app.yaml
}

create_cluster() {
  echo "Creating Kind cluster '$KIND_CLUSTER_NAME'..."
  kind delete cluster --name "$KIND_CLUSTER_NAME" >/dev/null 2>&1 || true
  kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG_PATH_TMP"
  kubectl config use-context "kind-${KIND_CLUSTER_NAME}" >/dev/null

  echo "Installing NGINX Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s || true
  kubectl patch svc ingress-nginx-controller -n ingress-nginx --type='merge' -p '{"spec":{"type":"LoadBalancer"}}' || true
}

create_namespaces() {
  echo "Creating namespaces..."
  for ns in nativeseries argocd monitoring logging; do
    kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
  done
}

install_argocd() {
  echo "Installing ArgoCD..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
  kubectl apply -f /tmp/argocd-nodeport.yaml
  # Apply Applications last so controller is up
  kubectl apply -f /tmp/kube-prometheus-app.yaml
  kubectl apply -f /tmp/loki-stack-app.yaml
  kubectl apply -f /tmp/nativeseries-app.yaml
}

install_monitoring() {
  echo "Monitoring will be deployed by ArgoCD (kube-prometheus-stack Application)"
}

install_logging() {
  echo "Logging will be deployed by ArgoCD (loki-stack Application)"
}

deploy_app() {
  echo "Application will be deployed by ArgoCD Application (infra/argocd/application.yaml)"
}

print_summary() {
  echo
  echo "Deployment complete. Access endpoints:" 
  echo "- App:       http://${PUBLIC_HOST}:${APP_NODEPORT}"
  echo "- ArgoCD:    http://${PUBLIC_HOST}:${ARGOCD_NODEPORT} (user: admin, pass below)"
  echo "- Grafana:   http://${PUBLIC_HOST}:${GRAFANA_NODEPORT} (admin/admin123)"
  echo "- Prometheus:http://${PUBLIC_HOST}:${PROMETHEUS_NODEPORT}"
  echo "- Loki:      http://${PUBLIC_HOST}:${LOKI_NODEPORT}"
  echo
  echo -n "ArgoCD admin password: "
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "<not ready yet>"
  echo
}

main() {
  install_kubectl
  install_helm
  install_kind
  install_argocd_cli
  wait_for_docker
  resolve_ports
  generate_kind_config
  generate_argocd_manifests
  create_cluster
  create_namespaces
  install_argocd
  install_monitoring
  install_logging
  deploy_app
  print_summary
}

main "$@"