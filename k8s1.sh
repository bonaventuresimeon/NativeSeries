#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Setting up Kind cluster for GitOps...${NC}"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
  exit 1
fi

# Install kubectl if missing
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl not found. Installing...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Install kind if missing
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}⚠️  kind not found. Installing...${NC}"
    KIND_VERSION="0.27.0"
    curl -Lo kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${ARCH}"
    chmod +x kind
    sudo mv kind /usr/local/bin/
fi

# Install helm if missing
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}⚠️  helm not found. Installing...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# DNS and Port setup
DNS="http://18.208.149.195"
APP_PORT=8011

# Clear port 8011 if used
PID=$(lsof -ti tcp:$APP_PORT || true)
if [[ -n "$PID" ]]; then
  echo -e "${YELLOW}⚠️  Port $APP_PORT is in use by PID $PID. Killing...${NC}"
  sudo kill -9 $PID || true
else
  echo -e "${GREEN}✅ Port $APP_PORT is free.${NC}"
fi

# Clear all existing Kind clusters
echo -e "${YELLOW}🧼 Checking for existing Kind clusters...${NC}"
EXISTING_CLUSTERS=$(kind get clusters)
if [[ -n "$EXISTING_CLUSTERS" ]]; then
  echo -e "${YELLOW}⚠️  Found Kind clusters: $EXISTING_CLUSTERS. Deleting all...${NC}"
  for cluster in $EXISTING_CLUSTERS; do
    kind delete cluster --name "$cluster"
  done
else
  echo -e "${GREEN}✅ No existing Kind clusters found.${NC}"
fi

# Define cluster name and config file
CLUSTER_NAME="gitops-cluster"
CONFIG_FILE="infra/kind/cluster-config.yaml"

# Create Kind config if missing
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${YELLOW}⚠️  Kind config not found at $CONFIG_FILE. Creating default config...${NC}"
  mkdir -p infra/kind
  cat <<EOF > $CONFIG_FILE
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: ${APP_PORT}
        protocol: TCP
  - role: worker
  - role: worker
EOF
fi

# Create Kind cluster
echo -e "${GREEN}📦 Creating Kind cluster...${NC}"
kind create cluster --config "$CONFIG_FILE"

# Wait for cluster to be ready
echo -e "${GREEN}⏳ Waiting for nodes to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install ingress-nginx
echo -e "${GREEN}🌐 Installing ingress-nginx...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
echo -e "${GREEN}⏳ Waiting for ingress controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Create namespaces
echo -e "${GREEN}📁 Creating namespaces...${NC}"
for ns in argocd app-dev app-staging app-prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Show cluster info
echo -e "${GREEN}✅ Kind cluster setup complete!${NC}"
kubectl cluster-info
kubectl get nodes

# Output public access URL
echo -e "${GREEN}🌐 Your app will be available at: ${DNS}:${APP_PORT}${NC}"
