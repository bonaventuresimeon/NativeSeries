#!/usr/bin/env bash
set -euo pipefail

# Simple, end-to-end installer for: cluster (Kind), kubectl, helm, ArgoCD, Prometheus, Grafana, Loki, and the app
# Cluster name: gitops
# Namespaces: nativeseries, argocd, monitoring, logging

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
KIND_CLUSTER_NAME="gitops"
KIND_CONFIG_PATH="$REPO_ROOT/infra/kind/gitops-cluster-config.yaml"

GRAFANA_NODEPORT=30081
PROMETHEUS_NODEPORT=30082
LOKI_NODEPORT=30083
ARGOCD_NODEPORT=30080
APP_NODEPORT=30011

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

create_cluster() {
  echo "Creating Kind cluster '$KIND_CLUSTER_NAME'..."
  kind delete cluster --name "$KIND_CLUSTER_NAME" >/dev/null 2>&1 || true
  kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG_PATH"
  kubectl config use-context "kind-${KIND_CLUSTER_NAME}" >/dev/null

  echo "Installing NGINX Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  # Expose as LoadBalancer in Kind so hostPorts are used
  kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s
  kubectl patch svc ingress-nginx-controller -n ingress-nginx --type='merge' -p '{"spec":{"type":"LoadBalancer"}}'
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
  kubectl apply -f "$REPO_ROOT/infra/argocd/argocd-nodeport.yaml"
  kubectl apply -f "$REPO_ROOT/infra/argocd/application.yaml"
}

install_monitoring() {
  echo "Applying ArgoCD Application for kube-prometheus-stack..."
  kubectl apply -f "$REPO_ROOT/infra/argocd/kube-prometheus-app.yaml"
}

install_logging() {
  echo "Applying ArgoCD Application for loki-stack..."
  kubectl apply -f "$REPO_ROOT/infra/argocd/loki-stack-app.yaml"
}

deploy_app() {
  echo "Application will be deployed by ArgoCD Application (infra/argocd/application.yaml)"
  # No direct Helm install to keep GitOps as the single source of truth
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
  create_cluster
  create_namespaces
  install_argocd
  install_monitoring
  install_logging
  deploy_app
  print_summary
}

main "$@"