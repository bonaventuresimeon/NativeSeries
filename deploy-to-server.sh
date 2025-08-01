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
TARGET_IP="18.208.149.195"
TARGET_PORT="8011"
ARGOCD_PORT="30080"
APP_NAME="student-tracker"

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                Student Tracker Deployment                   ║"
echo "║              Target Server: ${TARGET_IP}:${TARGET_PORT}                    ║"
echo "║                    with ArgoCD GitOps                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker if not present
install_docker() {
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    rm get-docker.sh
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
}

# Function to install Docker Compose if not present
install_docker_compose() {
    echo -e "${BLUE}📦 Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed successfully${NC}"
}

# Function to install kubectl if not present
install_kubectl() {
    echo -e "${BLUE}🔧 Installing kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo -e "${GREEN}✅ kubectl installed successfully${NC}"
}

# Function to install Helm if not present
install_helm() {
    echo -e "${BLUE}🎯 Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo -e "${GREEN}✅ Helm installed successfully${NC}"
}

# Function to install Kind if not present
install_kind() {
    echo -e "${BLUE}🏗️  Installing Kind...${NC}"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
    rm kind
    echo -e "${GREEN}✅ Kind installed successfully${NC}"
}

# Check and install prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${YELLOW}⚠️  Docker not found. Installing...${NC}"
    install_docker
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

if ! command_exists docker-compose; then
    echo -e "${YELLOW}⚠️  Docker Compose not found. Installing...${NC}"
    install_docker_compose
else
    echo -e "${GREEN}✅ Docker Compose found${NC}"
fi

if ! command_exists kubectl; then
    echo -e "${YELLOW}⚠️  kubectl not found. Installing...${NC}"
    install_kubectl
else
    echo -e "${GREEN}✅ kubectl found${NC}"
fi

if ! command_exists helm; then
    echo -e "${YELLOW}⚠️  Helm not found. Installing...${NC}"
    install_helm
else
    echo -e "${GREEN}✅ Helm found${NC}"
fi

if ! command_exists kind; then
    echo -e "${YELLOW}⚠️  Kind not found. Installing...${NC}"
    install_kind
else
    echo -e "${GREEN}✅ Kind found${NC}"
fi

echo -e "${GREEN}✅ All prerequisites satisfied${NC}"

# Step 1: Setup Kind cluster
echo -e "${GREEN}🚀 Step 1: Setting up Kind cluster...${NC}"

# Create Kind configuration with port mapping
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: ${TARGET_PORT}
    hostPort: ${TARGET_PORT}
    protocol: TCP
  - containerPort: ${ARGOCD_PORT}
    hostPort: ${ARGOCD_PORT}
    protocol: TCP
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

kind create cluster --name gitops-cluster --config kind-config.yaml

# Step 2: Build and load application image
echo -e "${GREEN}🐳 Step 2: Building application Docker image...${NC}"

# Build the application image
docker build -t ${APP_NAME}:latest -f docker/Dockerfile .

# Load image into Kind cluster
kind load docker-image ${APP_NAME}:latest --name gitops-cluster

# Step 3: Setup ArgoCD
echo -e "${GREEN}🎯 Step 3: Setting up ArgoCD...${NC}"

# Create ArgoCD namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "${BLUE}⏳ Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd

# Patch ArgoCD server to disable TLS (for IP-based access)
kubectl patch deployment argocd-server -n argocd -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json

# Create NodePort service for ArgoCD
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
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
    nodePort: ${ARGOCD_PORT}
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Wait for the patched server to be ready
echo -e "${BLUE}⏳ Waiting for ArgoCD server to restart...${NC}"
sleep 10
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

# Step 4: Deploy application using Helm
echo -e "${GREEN}📋 Step 4: Deploying Student Tracker application...${NC}"

# Create namespace for the application
kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -

# Deploy with Helm
helm upgrade --install ${APP_NAME} infra/helm \
  --values infra/helm/values-prod.yaml \
  --namespace app-prod \
  --create-namespace \
  --wait

# Step 5: Create ArgoCD application for GitOps
echo -e "${GREEN}🔄 Step 5: Setting up ArgoCD application for GitOps...${NC}"

# Create ArgoCD application
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-org/student-tracker.git'  # Update with your actual repo
    targetRevision: main
    path: infra/helm
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: app-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Step 6: Verify deployment
echo -e "${GREEN}⏳ Step 6: Verifying deployment...${NC}"

echo -e "${BLUE}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/${APP_NAME} -n app-prod

echo -e "${BLUE}Checking pod status...${NC}"
kubectl get pods -n app-prod

echo -e "${BLUE}Checking service status...${NC}"
kubectl get svc -n app-prod

echo -e "${BLUE}Checking ArgoCD applications...${NC}"
kubectl get applications -n argocd

# Step 7: Display access information
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e ""
echo -e "${PURPLE}🎯 ArgoCD UI:${NC}"
echo -e "  🌐 URL: http://${TARGET_IP}:${ARGOCD_PORT}"
echo -e "     👤 Username: admin"
echo -e "     🔑 Password: ${ARGOCD_PASSWORD}"
echo -e ""
echo -e "${PURPLE}🚀 Student Tracker Application:${NC}"
echo -e "  🌐 URL: http://${TARGET_IP}:${TARGET_PORT}"
echo -e "  📖 API Documentation: http://${TARGET_IP}:${TARGET_PORT}/docs"
echo -e "  🩺 Health Check: http://${TARGET_IP}:${TARGET_PORT}/health"
echo -e ""
echo -e "${BLUE}🔄 Kubernetes Resources:${NC}"
echo -e "  📊 Pods: kubectl get pods -n app-prod"
echo -e "  🌐 Services: kubectl get svc -n app-prod"
echo -e "  🚪 Ingress: kubectl get ingress -n app-prod"
echo -e ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Update repository URL in ArgoCD application"
echo -e "  2. Configure DNS/load balancer if needed"
echo -e "  3. Set up monitoring and logging"
echo -e "  4. Configure SSL certificates"
echo -e ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo -e "  # View application logs"
echo -e "  kubectl logs -f deployment/${APP_NAME} -n app-prod"
echo -e ""
echo -e "  # Scale application"
echo -e "  kubectl scale deployment ${APP_NAME} --replicas=3 -n app-prod"
echo -e ""
echo -e "  # Update application using Helm"
echo -e "  helm upgrade ${APP_NAME} infra/helm --values infra/helm/values-prod.yaml -n app-prod"
echo -e ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${YELLOW}💡 Access your application at: http://${TARGET_IP}:${TARGET_PORT}${NC}"
echo -e "${YELLOW}💡 Access ArgoCD at: http://${TARGET_IP}:${ARGOCD_PORT}${NC}"

# Save ArgoCD password to file
echo "$ARGOCD_PASSWORD" > .argocd-password
echo -e "${GREEN}💾 ArgoCD password saved to .argocd-password${NC}"