#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v2.9.3"

echo -e "${GREEN}🚀 Setting up ArgoCD for GitOps...${NC}"

# Check if kubectl is available and cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ kubectl is not configured or cluster is not accessible${NC}"
    echo -e "${YELLOW}💡 Make sure you have a running Kubernetes cluster and kubectl is configured${NC}"
    exit 1
fi

# Create ArgoCD namespace
echo -e "${GREEN}📁 Creating ArgoCD namespace...${NC}"
kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "${GREEN}📦 Installing ArgoCD ${ARGOCD_VERSION}...${NC}"
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${GREEN}⏳ Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n $ARGOCD_NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n $ARGOCD_NAMESPACE

# Patch ArgoCD server to disable TLS (for local development)
echo -e "${GREEN}🔧 Configuring ArgoCD server...${NC}"
kubectl patch deployment argocd-server -n $ARGOCD_NAMESPACE -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json

# Create NodePort service for ArgoCD (for Kind cluster access)
echo -e "${GREEN}🌐 Creating NodePort service for ArgoCD...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - name: server
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Wait for the patched server to be ready
echo -e "${GREEN}⏳ Waiting for ArgoCD server to restart...${NC}"
sleep 10
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE

# Get initial admin password
echo -e "${GREEN}🔑 Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $ARGOCD_NAMESPACE -o jsonpath="{.data.password}" | base64 -d)

# Create ArgoCD applications directory if it doesn't exist
mkdir -p k8s/argocd

# Create the parent application (App of Apps pattern)
echo -e "${GREEN}📋 Creating ArgoCD parent application...${NC}"
cat <<EOF > k8s/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: $ARGOCD_NAMESPACE
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/student-tracker.git  # Update this with your actual repo
    targetRevision: HEAD
    path: infra/argocd/parent
  destination:
    server: https://kubernetes.default.svc
    namespace: $ARGOCD_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Apply the parent application
kubectl apply -f k8s/argocd/app-of-apps.yaml

# Install ArgoCD CLI (if not already installed)
if ! command -v argocd &> /dev/null; then
    echo -e "${YELLOW}📥 ArgoCD CLI not found. Installing...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-darwin-amd64
        sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
        rm argocd-darwin-amd64
    else
        echo -e "${YELLOW}⚠️  Please install ArgoCD CLI manually: https://argo-cd.readthedocs.io/en/stable/cli_installation/${NC}"
    fi
fi

echo -e "${GREEN}✅ ArgoCD setup complete!${NC}"
echo -e "${BLUE}📋 ArgoCD Information:${NC}"
echo -e "  🌐 UI URL: http://localhost:30080 (for Kind cluster)"
echo -e "  👤 Username: admin"
echo -e "  🔑 Password: ${ARGOCD_PASSWORD}"
echo -e ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo -e "  1. Access ArgoCD UI at http://localhost:30080"
echo -e "  2. Login with admin/${ARGOCD_PASSWORD}"
echo -e "  3. Update the repository URL in k8s/argocd/app-of-apps.yaml"
echo -e "  4. Sync the applications in ArgoCD"
echo -e ""
echo -e "${YELLOW}💡 To access ArgoCD from outside the cluster:${NC}"
echo -e "  kubectl port-forward svc/argocd-server -n argocd 8080:443"

# Save password to file for later use
echo "$ARGOCD_PASSWORD" > .argocd-password
echo -e "${GREEN}💾 ArgoCD password saved to .argocd-password${NC}"