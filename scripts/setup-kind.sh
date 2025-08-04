#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Setting up Kind cluster for GitOps...${NC}"

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}❌ Kind is not installed. Please install it first.${NC}"
    echo -e "${YELLOW}Installation: https://kind.sigs.k8s.io/docs/user/quick-start/#installation${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed. Please install it first.${NC}"
    echo -e "${YELLOW}Installation: https://kubernetes.io/docs/tasks/tools/install-kubectl/${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed. Please install it first.${NC}"
    echo -e "${YELLOW}Installation: https://helm.sh/docs/intro/install/${NC}"
    exit 1
fi

CLUSTER_NAME="gitops-cluster"

# Delete existing cluster if it exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}⚠️  Existing cluster found. Deleting...${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
fi

# Create Kind cluster
echo -e "${GREEN}📦 Creating Kind cluster...${NC}"
kind create cluster --config infra/kind/cluster-config.yaml

# Wait for cluster to be ready
echo -e "${GREEN}⏳ Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ingress-nginx
echo -e "${GREEN}🌐 Installing ingress-nginx...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress-nginx to be ready
echo -e "${GREEN}⏳ Waiting for ingress-nginx to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Create namespaces
echo -e "${GREEN}📁 Creating namespaces...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Kind cluster setup complete!${NC}"
echo -e "${GREEN}📋 Cluster Info:${NC}"
kubectl cluster-info
echo -e "${GREEN}📊 Nodes:${NC}"
kubectl get nodes