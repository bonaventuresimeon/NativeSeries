#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧹 Cleaning up GitOps stack...${NC}"

CLUSTER_NAME="gitops-cluster"

# Check if Kind cluster exists
if kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "${GREEN}🗑️  Deleting Kind cluster: $CLUSTER_NAME${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
else
    echo -e "${YELLOW}⚠️  Kind cluster '$CLUSTER_NAME' not found${NC}"
fi

# Clean up local files
echo -e "${GREEN}🧽 Cleaning up local files...${NC}"

# Remove generated files
rm -f .argocd-password
rm -rf k8s/base/
rm -rf k8s/argocd/

# Clean up Docker images (optional)
read -p "Do you want to remove the student-tracker Docker image? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🐳 Removing Docker image...${NC}"
    docker rmi student-tracker:latest 2>/dev/null || echo -e "${YELLOW}⚠️  Image not found${NC}"
fi

echo -e "${GREEN}✅ Cleanup complete!${NC}"