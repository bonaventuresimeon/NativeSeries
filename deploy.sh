#!/bin/bash
set -euo pipefail

# Configuration
CLUSTER_NAME="student-tracker-cluster"
APP_NAME="student-tracker"
MAX_RETRIES=5
RETRY_DELAY=15  # seconds

# Resolve absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
KIND_CONFIG="$SCRIPT_DIR/k8s/kind-config.yaml"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Helper: Retry command with delay
retry() {
  local retries=$1
  local delay=$2
  shift 2
  local attempt=1
  local success=false

  until [ $attempt -gt $retries ]; do
    echo "Attempt $attempt/$retries: $*"
    if "$@"; then
      success=true
      break
    else
      echo "Attempt $attempt failed. Retrying in $delay seconds..."
      sleep $delay
    fi
    ((attempt++))
  done

  if ! $success; then
    echo "Command failed after $retries attempts: $*"
    exit 1
  fi
}

echo "===> Step 1: Delete existing Kind clusters"
clusters=$(kind get clusters || true)
if [ -n "$clusters" ]; then
  for c in $clusters; do
    retry $MAX_RETRIES $RETRY_DELAY kind delete cluster --name "$c"
  done
else
  echo "No existing Kind clusters found."
fi

echo "===> Step 2: Clean Kubernetes namespaces (except kube-system, kube-public, default)"
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null 2>&1 || echo "No current context for $CLUSTER_NAME yet"

all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
if [ -n "$all_namespaces" ]; then
  for ns in $all_namespaces; do
    if [[ "$ns" != "kube-system" && "$ns" != "kube-public" && "$ns" != "default" ]]; then
      echo "Deleting namespace: $ns"
      retry $MAX_RETRIES $RETRY_DELAY kubectl delete namespace "$ns" --wait=true || echo "Failed deleting namespace $ns"
    fi
  done
else
  echo "No namespaces found or cluster not yet ready."
fi

echo "===> Step 3: Docker system prune"
echo "Warning: This will remove ALL Docker containers, images, volumes, and networks on this machine."
read -p "Proceed with Docker system prune? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  retry $MAX_RETRIES $RETRY_DELAY docker system prune -a -f --volumes
else
  echo "Skipping Docker system prune."
fi

echo "===> Step 4: Restart Docker service"
if systemctl is-active docker >/dev/null 2>&1; then
  retry $MAX_RETRIES $RETRY_DELAY sudo systemctl restart docker
else
  echo "Docker service is not active, attempting to start"
  retry $MAX_RETRIES $RETRY_DELAY sudo systemctl start docker
fi

echo "===> Step 5: Create Kind cluster using $KIND_CONFIG"
if [ ! -f "$KIND_CONFIG" ]; then
  echo "Kind config file not found at $KIND_CONFIG"
  exit 1
fi

retry $MAX_RETRIES $RETRY_DELAY kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"

echo "===> Step 6: Install kubectl (if missing)"
if ! command -v kubectl >/dev/null 2>&1; then
  retry $MAX_RETRIES $RETRY_DELAY bash -c "curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
else
  echo "kubectl already installed."
fi

echo "===> Step 7: Install Helm (if missing)"
if ! command -v helm >/dev/null 2>&1; then
  retry $MAX_RETRIES $RETRY_DELAY bash -c "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
else
  echo "Helm already installed."
fi

echo "===> Step 8: Install Argo CD"
retry $MAX_RETRIES $RETRY_DELAY kubectl create namespace argocd || echo "Namespace 'argocd' already exists."
retry $MAX_RETRIES $RETRY_DELAY kubectl apply -n argocd -f "$ARGOCD_MANIFEST"

echo "===> Step 9: Wait for Argo CD server to be ready"
retry $MAX_RETRIES $RETRY_DELAY kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "===> Step 10: Apply all YAML manifests recursively (excluding Helm and charts directories)"
find "$BASE_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/charts/*" ! -path "*/helm/*" ! -path "*/argocd/*" | while read -r yaml_file; do
  echo "Applying manifest: $yaml_file"
  retry $MAX_RETRIES $RETRY_DELAY kubectl apply -f "$yaml_file" || echo "Failed applying $yaml_file"
done

echo "===> Step 11: Create namespace for the app if not exists"
kubectl create namespace $APP_NAME || echo "Namespace $APP_NAME already exists."

echo "===> Step 12: Create Argo CD Application for Helm chart '$APP_NAME'"
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-org/student-tracker'  # Replace with your actual GitHub repo
    path: helm
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAME
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "===> ✅ Deployment complete!"
echo ""
echo "🔗 To access Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Open: https://localhost:8080"
echo "🔐 Login: admin"
echo -n "🔑 Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

