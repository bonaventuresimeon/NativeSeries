# 🚀 Student Tracker - Complete Installation Guide

## 📋 Overview

This guide provides step-by-step instructions to install, configure, and deploy the Student Tracker application using Docker, Kubernetes, Helm, and ArgoCD.

## 🎯 What You'll Build

- **FastAPI Application** running in Docker containers
- **Kubernetes Cluster** (Kind for local development)
- **Helm Charts** for application deployment
- **ArgoCD** for GitOps continuous deployment
- **CI/CD Pipeline** with GitHub Actions
- **Production-Ready Setup** with monitoring and health checks

## 📦 Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu/Debian preferred) or macOS
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk**: 20GB free space
- **Network**: Internet connection for downloading tools

### Required Accounts
- **GitHub Account** (for repository and CI/CD)
- **Docker Hub Account** (optional, for custom images)

## 🛠️ Tool Installation

### Method 1: Automated Installation (Recommended)

Use our automated installation script:

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Make script executable
chmod +x scripts/install-all.sh

# Run full installation
./scripts/install-all.sh

# Or with custom Docker username
DOCKER_USERNAME=yourusername ./scripts/install-all.sh
```

### Method 2: Manual Installation

#### Step 1: Install Python 3.11

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y python3.11 python3.11-pip python3.11-venv python3.11-dev
sudo apt install -y build-essential curl wget git
```

**CentOS/RHEL:**
```bash
sudo yum update -y
sudo yum install -y python3.11 python3.11-pip python3.11-devel gcc
sudo yum install -y curl wget git
```

**macOS:**
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python@3.11
```

#### Step 2: Install Docker

**Linux:**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Log out and back in for group changes to take effect
```

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker
# Or download from https://docker.com/products/docker-desktop
```

#### Step 3: Install kubectl

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

#### Step 4: Install Helm

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

#### Step 5: Install Kind

```bash
# Download Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

#### Step 6: Install ArgoCD CLI

```bash
# Download ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Verify installation
argocd version --client
```

#### Step 7: Install Additional Tools

```bash
# Ubuntu/Debian
sudo apt install -y jq tree htop net-tools

# CentOS/RHEL
sudo yum install -y jq tree htop net-tools

# macOS
brew install jq tree htop
```

## 🐍 Python Environment Setup

### Create Virtual Environment

```bash
# Create virtual environment
python3.11 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt
```

### Verify Python Setup

```bash
# Check Python version
python --version

# Check installed packages
pip list

# Run basic tests
pytest app/test_*.py -v
```

## 🐳 Docker Setup

### Build Application Image

```bash
# Build Docker image
docker build -t student-tracker:latest .

# Verify image
docker images | grep student-tracker

# Test run container
docker run -d --name test-app -p 8000:8000 student-tracker:latest

# Test application
curl http://localhost:8000/health

# Stop and remove test container
docker stop test-app && docker rm test-app
```

### Docker Configuration

```bash
# Check Docker status
docker info

# Test Docker permissions
docker run hello-world

# View Docker logs
sudo journalctl -u docker.service
```

## ☸️ Kubernetes Cluster Setup

### Create Kind Cluster

```bash
# Create cluster configuration
mkdir -p infra/kind
cat <<EOF > infra/kind/cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: gitops-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30011
    hostPort: 30011
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF

# Create Kind cluster
kind create cluster --config infra/kind/cluster-config.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### Install Ingress Controller

```bash
# Install ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Create Namespaces

```bash
# Create required namespaces
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace student-tracker --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app-prod --dry-run=client -o yaml | kubectl apply -f -

# Verify namespaces
kubectl get namespaces
```

### Verify Cluster

```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A
```

## 🎯 ArgoCD Installation

### Install ArgoCD

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd
```

### Configure ArgoCD

```bash
# Configure ArgoCD for insecure access (for IP-based access)
kubectl patch deployment argocd-server -n argocd -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json

# Create NodePort service for external access
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
    nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Wait for server to restart
sleep 10
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Get ArgoCD Credentials

```bash
# Get admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
echo "$ARGOCD_PASSWORD" > .argocd-password

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo "ArgoCD UI: http://18.206.89.183:30080"
echo "Username: admin"
```

## ⎈ Helm Chart Deployment

### Load Docker Image to Kind

```bash
# Load image into Kind cluster
kind load docker-image student-tracker:latest --name gitops-cluster

# Verify image is loaded
docker exec -it gitops-cluster-control-plane crictl images | grep student-tracker
```

### Deploy with Helm

```bash
# Deploy application using Helm
helm upgrade --install student-tracker helm-chart \
  --namespace student-tracker \
  --create-namespace \
  --wait \
  --timeout=300s \
  --set image.repository="student-tracker" \
  --set image.tag="latest"

# Check deployment status
kubectl get pods -n student-tracker
kubectl get svc -n student-tracker
kubectl get ingress -n student-tracker
```

### Verify Helm Deployment

```bash
# Check Helm releases
helm list -A

# Check application logs
kubectl logs -f deployment/student-tracker -n student-tracker

# Test application health
kubectl port-forward svc/student-tracker -n student-tracker 8080:80 &
curl http://localhost:8080/health
pkill -f "kubectl port-forward"
```

## 🔄 ArgoCD Application Setup

### Apply ArgoCD Application

```bash
# Apply existing ArgoCD application configuration
kubectl apply -f argocd/application.yaml

# Check ArgoCD application status
kubectl get applications -n argocd

# Check application sync status
argocd app list --server localhost:30080 --username admin --password "$ARGOCD_PASSWORD" --insecure
```

### Sync Application

```bash
# Manual sync if needed
argocd app sync student-tracker --server localhost:30080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# Enable auto-sync
argocd app set student-tracker --sync-policy automated --server localhost:30080 --username admin --password "$ARGOCD_PASSWORD" --insecure
```

## 🔍 Verification Commands

### Check All Components

```bash
echo "=== Cluster Info ==="
kubectl cluster-info

echo "=== Nodes ==="
kubectl get nodes -o wide

echo "=== Namespaces ==="
kubectl get namespaces

echo "=== All Pods ==="
kubectl get pods -A

echo "=== Services ==="
kubectl get svc -A

echo "=== Ingress ==="
kubectl get ingress -A

echo "=== ArgoCD Applications ==="
kubectl get applications -n argocd

echo "=== Helm Releases ==="
helm list -A
```

### Application-Specific Checks

```bash
echo "=== Student Tracker Pods ==="
kubectl get pods -n student-tracker -o wide

echo "=== Student Tracker Services ==="
kubectl get svc -n student-tracker

echo "=== Student Tracker Logs ==="
kubectl logs deployment/student-tracker -n student-tracker --tail=50

echo "=== Application Health ==="
curl -f http://18.206.89.183:30011/health

echo "=== API Documentation ==="
curl -f http://18.206.89.183:30011/docs
```

### ArgoCD Checks

```bash
echo "=== ArgoCD Pods ==="
kubectl get pods -n argocd

echo "=== ArgoCD Services ==="
kubectl get svc -n argocd

echo "=== ArgoCD Applications ==="
kubectl get applications -n argocd -o wide

echo "=== ArgoCD UI Access ==="
echo "URL: http://18.206.89.183:30080"
echo "Username: admin"
echo "Password: $(cat .argocd-password)"
```

## 🌐 Access Information

### Application URLs

- **Main Application**: http://18.206.89.183:30011
- **API Documentation**: http://18.206.89.183:30011/docs
- **Health Check**: http://18.206.89.183:30011/health
- **Metrics**: http://18.206.89.183:30011/metrics

### ArgoCD URLs

- **ArgoCD UI**: http://18.206.89.183:30080
- **Username**: admin
- **Password**: Check `.argocd-password` file

### Local Access (Port Forwarding)

```bash
# Application
kubectl port-forward svc/student-tracker -n student-tracker 8000:80

# ArgoCD
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

## 🚀 CI/CD Pipeline Setup

### GitHub Actions Configuration

The repository includes a complete CI/CD pipeline at `.github/workflows/pipeline.yml` that:

1. **Tests** code quality and runs unit tests
2. **Builds** and pushes Docker images
3. **Deploys** to production automatically
4. **Provides** PR feedback and deployment summaries

### Pipeline Features

- ✅ **Automated Testing**: Linting, formatting, unit tests
- ✅ **Security Scanning**: Vulnerability scanning with Trivy
- ✅ **Docker Build**: Multi-stage builds with caching
- ✅ **Automatic Deployment**: On push to main branch
- ✅ **Manual Deployment**: Via GitHub Actions UI
- ✅ **PR Validation**: Automatic PR checks and feedback

### Environment Variables

Set these in your GitHub repository settings:

```bash
# Repository Variables
PRODUCTION_HOST=18.206.89.183
PRODUCTION_PORT=30011

# Repository Secrets (if needed)
DOCKER_USERNAME=your-docker-username
```

## 🛠️ Useful Commands

### Development Commands

```bash
# Start local development
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Run tests
pytest app/test_*.py -v

# Code formatting
black app/
flake8 app/

# Build and test Docker image locally
docker build -t student-tracker:latest .
docker run -p 8000:8000 student-tracker:latest
```

### Kubernetes Management

```bash
# Scale application
kubectl scale deployment student-tracker --replicas=3 -n student-tracker

# Update application
helm upgrade student-tracker helm-chart -n student-tracker

# View logs
kubectl logs -f deployment/student-tracker -n student-tracker

# Execute into pod
kubectl exec -it deployment/student-tracker -n student-tracker -- /bin/bash

# Port forward for debugging
kubectl port-forward svc/student-tracker -n student-tracker 8000:80
```

### ArgoCD Management

```bash
# Login to ArgoCD CLI
argocd login localhost:30080 --username admin --password "$(cat .argocd-password)" --insecure

# List applications
argocd app list

# Get application details
argocd app get student-tracker

# Sync application
argocd app sync student-tracker

# View application logs
argocd app logs student-tracker
```

### Cleanup Commands

```bash
# Remove application
helm uninstall student-tracker -n student-tracker

# Delete ArgoCD application
kubectl delete application student-tracker -n argocd

# Delete Kind cluster
kind delete cluster --name gitops-cluster

# Clean Docker images
docker system prune -af
```

## 🔧 Troubleshooting

### Common Issues

1. **Docker Permission Denied**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Kubernetes Pods Not Starting**
   ```bash
   kubectl describe pod <pod-name> -n student-tracker
   kubectl logs <pod-name> -n student-tracker
   ```

3. **ArgoCD Application Not Syncing**
   ```bash
   kubectl get applications -n argocd
   argocd app get student-tracker
   argocd app sync student-tracker --force
   ```

4. **Port Already in Use**
   ```bash
   sudo lsof -i :30011
   sudo kill -9 <PID>
   ```

### Health Checks

```bash
# Check all components are healthy
./scripts/smoke-tests.sh http://18.206.89.183:30011

# Check individual components
curl -f http://18.206.89.183:30011/health
curl -f http://18.206.89.183:30080 # ArgoCD UI
```

## 📚 Next Steps

1. **Customize Configuration**: Update `helm-chart/values.yaml` for your needs
2. **Set up Monitoring**: Add Prometheus and Grafana for monitoring
3. **Configure Alerts**: Set up alerting for production issues
4. **Database Setup**: Configure persistent database if needed
5. **SSL/TLS**: Add HTTPS certificates for production
6. **Backup Strategy**: Implement backup and disaster recovery

## 🎉 Congratulations!

You now have a complete GitOps setup with:
- ✅ FastAPI application running in Kubernetes
- ✅ ArgoCD managing deployments
- ✅ Helm charts for configuration management
- ✅ CI/CD pipeline with GitHub Actions
- ✅ Production-ready monitoring and health checks

Your Student Tracker application is ready for development and production use!