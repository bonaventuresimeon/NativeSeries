#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
KIND_CONFIG="$REPO_ROOT/infra/kind/cluster.yaml"
CLUSTER_NAME="gitops"
PUBLIC_HOST=${PUBLIC_HOST:-$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || curl -fsSL https://checkip.amazonaws.com || hostname -I | awk '{print $1}')}

sudo systemctl restart docker || true
sleep 2

# Python venv + requirements
if command -v python3 >/dev/null 2>&1; then
  cd "$REPO_ROOT"
  python3 -m venv .venv || true
  source .venv/bin/activate || true
  pip install --upgrade pip setuptools wheel || true
  [[ -f requirements.txt ]] && pip install -r requirements.txt || true
fi

# Create cluster
kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

# Namespaces
for ns in argocd nativeseries monitoring logging; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done

# ArgoCD + NodePort svc
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true
kubectl apply -f "$REPO_ROOT/infra/argocd/argocd-nodeport.yaml"

# GitOps Applications
kubectl apply -f "$REPO_ROOT/infra/argocd/application.yaml"
kubectl apply -f "$REPO_ROOT/infra/argocd/kube-prometheus-app.yaml"
kubectl apply -f "$REPO_ROOT/infra/argocd/loki-stack-app.yaml"

# URLs
echo "PUBLIC_HOST=${PUBLIC_HOST}" > "$REPO_ROOT/scripts/gitops-ports.env"
cat >> "$REPO_ROOT/scripts/gitops-ports.env" <<EOF
APP_PORT=30011
ARGOCD_PORT=30080
GRAFANA_PORT=30081
PROM_PORT=30082
LOKI_PORT=30083
EOF

echo "- App:       http://${PUBLIC_HOST}:30011"
echo "- ArgoCD:    http://${PUBLIC_HOST}:30080"
echo "- Grafana:   http://${PUBLIC_HOST}:30081"
echo "- Prometheus:http://${PUBLIC_HOST}:30082"
echo "- Loki:      http://${PUBLIC_HOST}:30083"