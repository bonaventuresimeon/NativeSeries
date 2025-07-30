#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TARGET_IP="30.80.98.218"
TARGET_PORT="8011"
ARGOCD_PORT="30080"

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   GitOps Stack Deployment                   ║"
echo "║              Student Tracker with ArgoCD                    ║"
echo "║                  Target: ${TARGET_IP}:${TARGET_PORT}                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
    read -r
}

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

MISSING_DEPS=()

if ! command_exists kind; then
    MISSING_DEPS+=("kind")
fi

if ! command_exists kubectl; then
    MISSING_DEPS+=("kubectl")
fi

if ! command_exists helm; then
    MISSING_DEPS+=("helm")
fi

if ! command_exists docker; then
    MISSING_DEPS+=("docker")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}Please install the missing dependencies and run this script again.${NC}"
    echo -e "${YELLOW}Installation guides:${NC}"
    echo -e "  • Kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    echo -e "  • kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    echo -e "  • Helm: https://helm.sh/docs/intro/install/"
    echo -e "  • Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites satisfied${NC}"

# Step 1: Setup Kind cluster
echo -e "${GREEN}🚀 Step 1: Setting up Kind cluster with port ${TARGET_PORT} mapping...${NC}"
wait_for_user
./scripts/setup-kind.sh

# Step 2: Build and load application image (for local development)
echo -e "${GREEN}🐳 Step 2: Building application Docker image...${NC}"
wait_for_user

echo -e "${BLUE}Building student-tracker image...${NC}"
docker build -t student-tracker:latest -f docker/Dockerfile .

echo -e "${BLUE}Loading image into Kind cluster...${NC}"
kind load docker-image student-tracker:latest --name gitops-cluster

# Step 3: Setup ArgoCD
echo -e "${GREEN}🎯 Step 3: Setting up ArgoCD...${NC}"
wait_for_user
./scripts/setup-argocd.sh

# Step 4: Deploy application using Helm
echo -e "${GREEN}📋 Step 4: Deploying Student Tracker application...${NC}"
wait_for_user

echo -e "${BLUE}Deploying with Helm...${NC}"
helm upgrade --install student-tracker infra/helm \
  --values infra/helm/values-dev.yaml \
  --namespace app-dev \
  --create-namespace \
  --wait

# Step 5: Verify deployment
echo -e "${GREEN}⏳ Step 5: Verifying deployment...${NC}"
wait_for_user

echo -e "${BLUE}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/student-tracker -n app-dev

echo -e "${BLUE}Checking pod status...${NC}"
kubectl get pods -n app-dev

echo -e "${BLUE}Checking service status...${NC}"
kubectl get svc -n app-dev

# Step 6: Display access information
echo -e "${GREEN}✅ GitOps stack deployment complete!${NC}"
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e ""
echo -e "${PURPLE}🎯 ArgoCD UI:${NC}"
echo -e "  🌐 External URL: http://${TARGET_IP}:${ARGOCD_PORT}"
echo -e "  🌐 Local URL: http://localhost:${ARGOCD_PORT}"
echo -e "     👤 Username: admin"
echo -e "     🔑 Password: $(cat .argocd-password 2>/dev/null || echo 'Check .argocd-password file')"
echo -e ""
echo -e "${PURPLE}🚀 Student Tracker Application:${NC}"
echo -e "  🌐 External URL: http://${TARGET_IP}:${TARGET_PORT}"
echo -e "  🌐 Local URL: http://localhost:${TARGET_PORT}"
echo -e "  📖 API Documentation: http://${TARGET_IP}:${TARGET_PORT}/docs"
echo -e "  🩺 Health Check: http://${TARGET_IP}:${TARGET_PORT}/health"
echo -e ""
echo -e "${BLUE}🔄 Kubernetes Resources:${NC}"
echo -e "  📊 Pods: kubectl get pods -n app-dev"
echo -e "  🌐 Services: kubectl get svc -n app-dev"
echo -e "  🚪 Ingress: kubectl get ingress -n app-dev"
echo -e ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Configure your load balancer to route ${TARGET_IP}:${TARGET_PORT} to the cluster"
echo -e "  2. Update repository URLs in ArgoCD applications (k8s/argocd/app-of-apps.yaml)"
echo -e "  3. Push code changes to trigger GitOps deployments"
echo -e "  4. Monitor applications in ArgoCD UI"
echo -e "  5. Set up monitoring and logging (optional)"
echo -e ""
echo -e "${BLUE}🛠️  Development Commands:${NC}"
echo -e "  # View application logs"
echo -e "  kubectl logs -f deployment/student-tracker -n app-dev"
echo -e ""
echo -e "  # Scale application"
echo -e "  kubectl scale deployment student-tracker --replicas=3 -n app-dev"
echo -e ""
echo -e "  # Port forward for direct access"
echo -e "  kubectl port-forward svc/student-tracker -n app-dev 8000:80"
echo -e ""
echo -e "  # Update application using Helm"
echo -e "  helm upgrade student-tracker infra/helm --values infra/helm/values-dev.yaml -n app-dev"
echo -e ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${YELLOW}💡 Access your application at: http://${TARGET_IP}:${TARGET_PORT}${NC}"
echo -e "${YELLOW}💡 Access ArgoCD at: http://${TARGET_IP}:${ARGOCD_PORT}${NC}"