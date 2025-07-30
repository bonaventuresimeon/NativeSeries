#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   GitOps Stack Deployment                   ║"
echo "║              Student Tracker with ArgoCD                    ║"
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
echo -e "${GREEN}🚀 Step 1: Setting up Kind cluster...${NC}"
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

# Step 4: Create Kubernetes manifests for direct deployment (optional)
echo -e "${GREEN}📋 Step 4: Creating Kubernetes base manifests...${NC}"
wait_for_user

mkdir -p k8s/base

# Create base deployment
cat <<EOF > k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: student-tracker
  labels:
    app: student-tracker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: student-tracker
  template:
    metadata:
      labels:
        app: student-tracker
    spec:
      containers:
      - name: student-tracker
        image: student-tracker:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          value: "postgresql://user:pass@db:5432/studentdb"
        - name: APP_ENV
          value: "development"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "250m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 5
EOF

# Create base service
cat <<EOF > k8s/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: student-tracker-service
  labels:
    app: student-tracker
spec:
  selector:
    app: student-tracker
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP
EOF

# Create base ingress
cat <<EOF > k8s/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: student-tracker-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: student-tracker.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: student-tracker-service
            port:
              number: 80
EOF

# Create kustomization.yaml
cat <<EOF > k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- ingress.yaml

namePrefix: base-
EOF

echo -e "${GREEN}✅ Base Kubernetes manifests created${NC}"

# Step 5: Deploy application directly (for testing)
echo -e "${GREEN}⚙️  Step 5: Deploying application directly to test...${NC}"
wait_for_user

kubectl apply -k k8s/base

echo -e "${GREEN}⏳ Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/base-student-tracker

# Step 6: Setup port forwarding for local access
echo -e "${GREEN}🌐 Step 6: Setting up port forwarding...${NC}"

# ArgoCD port forward in background
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80 &
ARGOCD_PID=$!

# Application port forward in background  
kubectl port-forward svc/base-student-tracker-service 8000:80 &
APP_PID=$!

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    kill $ARGOCD_PID 2>/dev/null || true
    kill $APP_PID 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

trap cleanup EXIT

# Display access information
echo -e "${GREEN}✅ GitOps stack deployment complete!${NC}"
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e "  🎯 ArgoCD UI: http://localhost:8080"
echo -e "     👤 Username: admin"
echo -e "     🔑 Password: $(cat .argocd-password 2>/dev/null || echo 'Check .argocd-password file')"
echo -e ""
echo -e "  🚀 Student Tracker API: http://localhost:8000"
echo -e "  📖 API Docs: http://localhost:8000/docs"
echo -e ""
echo -e "  🌐 Ingress (add to /etc/hosts): student-tracker.local -> 127.0.0.1"
echo -e ""
echo -e "${BLUE}🔄 ArgoCD Applications:${NC}"
echo -e "  • Access ArgoCD UI to see and manage applications"
echo -e "  • The app-of-apps pattern will deploy child applications"
echo -e "  • Update the repository URL in k8s/argocd/app-of-apps.yaml"
echo -e ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Update repository URLs in ArgoCD applications"
echo -e "  2. Push your code changes to trigger GitOps sync"
echo -e "  3. Monitor deployments in ArgoCD UI"
echo -e "  4. Configure webhooks for automatic sync"
echo -e ""
echo -e "${GREEN}🏃 Services are running. Press Ctrl+C to stop port forwarding and exit.${NC}"

# Keep the script running to maintain port forwards
wait