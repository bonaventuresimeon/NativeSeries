# nativeseries - Complete Installation Guide

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## 🎯 Overview

This guide provides comprehensive instructions for installing and deploying the nativeseries application. The application is designed to be deployed using modern cloud-native practices with Docker, Kubernetes, and GitOps.

### What You'll Get

- ✅ **FastAPI Application**: Modern Python web framework
- ✅ **Docker Containerization**: Portable and scalable deployment
- ✅ **Kubernetes Orchestration**: Production-ready container orchestration
- ✅ **ArgoCD GitOps**: Automated deployment and management
- ✅ **GitHub Actions CI/CD**: Automated testing and deployment
- ✅ **Monitoring & Health Checks**: Built-in observability

## 🔧 Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, Amazon Linux 2)
- **Memory**: Minimum 4GB RAM (8GB recommended)
- **Storage**: Minimum 20GB free space
- **Network**: Internet connection for downloading dependencies

### Required Tools

- **Python**: 3.11 or higher
- **Docker**: 20.10 or higher
- **kubectl**: 1.28 or higher
- **Helm**: 3.13 or higher
- **Kind**: 0.20.0 or higher (for local Kubernetes)
- **ArgoCD CLI**: 2.9.3 or higher

## 🚀 Quick Installation

### Option 1: Automated Installation Script

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/nativeseries.git
cd nativeseries

# Run the automated installation script
chmod +x scripts/install-all.sh
./scripts/install-all.sh
```

### Option 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/nativeseries.git
cd nativeseries

# Install Python dependencies
pip install -r requirements.txt

# Build Docker image
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .

# Run locally
docker run -p 8000:8000 ghcr.io/bonaventuresimeon/nativeseries:latest
```

## 📖 Detailed Installation

### Step 1: Environment Setup

#### Install Python 3.11

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install python3.11 python3.11-pip python3.11-venv
```

**CentOS/RHEL/Amazon Linux:**
```bash
sudo yum update -y
sudo yum install python3.11 python3.11-pip
```

**macOS:**
```bash
brew install python@3.11
```

#### Install Docker

```bash
# Download and run Docker installation script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
```

#### Install Kubernetes Tools

**Install kubectl:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**Install Helm:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**Install Kind (for local Kubernetes):**
```bash
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
kind version
```

**Install ArgoCD CLI:**
```bash
curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v2.9.3/argocd-linux-amd64"
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client
```

### Step 2: Application Setup

#### Clone Repository

```bash
git clone https://github.com/bonaventuresimeon/nativeseries.git
cd nativeseries
```

#### Create Virtual Environment

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
```

#### Install Dependencies

```bash
pip install -r requirements.txt
```

#### Verify Installation

```bash
# Test Python imports
python -c "import fastapi, uvicorn, motor; print('✅ Dependencies installed successfully')"

# Test application startup
python -c "from app.main import app; print('✅ Application imports successfully')"
```

### Step 3: Docker Setup

#### Build Docker Image

```bash
# Build the application image
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .

# Verify the image was created
docker images | grep nativeseries
```

#### Test Docker Container

```bash
# Run the container
docker run -d --name native-series-test -p 8000:8000 ghcr.io/bonaventuresimeon/nativeseries:latest

# Wait for startup
sleep 10

# Test health endpoint
curl -f http://localhost:8000/health

# Stop and remove test container
docker stop native-series-test
docker rm native-series-test
```

### Step 4: Kubernetes Setup

#### Create Local Cluster (Kind)

```bash
# Create Kind cluster configuration
cat <<EOF > kind-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: native-series-cluster
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
- role: worker
- role: worker
EOF

# Create the cluster
kind create cluster --config kind-cluster-config.yaml

# Verify cluster is ready
kubectl cluster-info
kubectl get nodes
```

#### Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Configure ArgoCD for insecure access
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

# Get admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
echo "$ARGOCD_PASSWORD" > .argocd-password

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo "ArgoCD UI: http://localhost:30080"
echo "Username: admin"
```

### Step 5: Application Deployment

#### Deploy with Helm

```bash
# Create namespace
kubectl create namespace nativeseries

# Deploy application
helm upgrade --install nativeseries helm-chart \
--namespace nativeseries \
  --create-namespace \
  --wait \
  --timeout=300s \
  --set image.repository="ghcr.io/bonaventuresimeon/nativeseries" \
  --set image.tag="latest"
```

#### Deploy with ArgoCD

```bash
# Apply ArgoCD application
kubectl apply -f argocd/application.yaml

# Check application status
kubectl get applications -n argocd

# Sync application
argocd app sync nativeseries --server localhost:30080 --username admin --password "$(cat .argocd-password)" --insecure
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Application Configuration
ENVIRONMENT=production
DEBUG=false
HOST=0.0.0.0
PORT=8000

# Database Configuration
MONGO_URI=mongodb://localhost:27017
DATABASE_NAME=student_project_tracker
COLLECTION_NAME=students

# Vault Configuration (optional)
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=your-role-id
VAULT_SECRET_ID=your-secret-id

# Redis Configuration (optional)
REDIS_URL=redis://localhost:6379

# Production Configuration
PRODUCTION_HOST=54.166.101.159
PRODUCTION_PORT=30011
```

### Helm Chart Configuration

Edit `helm-chart/values.yaml`:

```yaml
# Application configuration
app:
  name: nativeseries
  image:
    repository: ghcr.io/bonaventuresimeon/nativeseries
    tag: latest
    pullPolicy: IfNotPresent

# Service configuration
service:
  type: NodePort
  port: 8000
  targetPort: 8000
  nodePort: 30011

# Resource limits
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## 🚀 Deployment

### Local Development Deployment

```bash
# Start the application locally
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Docker Deployment

```bash
# Build and run with Docker
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .
docker run -d --name native-series -p 30011:8000 ghcr.io/bonaventuresimeon/nativeseries:latest
```

### Kubernetes Deployment

```bash
# Deploy to Kubernetes
kubectl apply -f helm-chart/

# Check deployment status
kubectl get pods -n nativeseries
kubectl get svc -n nativeseries
```

### Production Deployment

```bash
# Use the deployment script
chmod +x scripts/deploy.sh
./scripts/deploy.sh --deploy-prod
```

## ✅ Verification

### Health Checks

```bash
# Check application health
curl -f http://localhost:8000/health

# Check Kubernetes pods
kubectl get pods -n nativeseries

# Check ArgoCD status
kubectl get applications -n argocd
```

### Smoke Tests

```bash
# Run smoke tests
chmod +x scripts/smoke-tests.sh
./scripts/smoke-tests.sh http://localhost:8000
```

### Access URLs

- **Application**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health
- **ArgoCD UI**: http://localhost:30080

## 🔍 Troubleshooting

### Common Issues

#### Docker Issues

**Permission Denied:**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Docker Daemon Not Running:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### Kubernetes Issues

**Cluster Not Ready:**
```bash
kubectl cluster-info
kubectl get nodes
```

**Pods Not Starting:**
```bash
kubectl describe pod <pod-name> -n nativeseries
kubectl logs <pod-name> -n nativeseries
```

#### ArgoCD Issues

**Application Not Syncing:**
```bash
kubectl get applications -n argocd
argocd app get nativeseries
argocd app sync nativeseries --force
```

**Cannot Access ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

### Logs and Debugging

```bash
# Application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd

# Docker logs
docker logs -f native-series
```

### Reset Installation

```bash
# Stop all processes
chmod +x scripts/stop-installation.sh
./scripts/stop-installation.sh

# Clean up Kubernetes
kubectl delete namespace nativeseries
kubectl delete namespace argocd

# Clean up Docker
docker system prune -af

# Remove Kind cluster
kind delete cluster --name native-series-cluster
```

## 🎯 Next Steps

### Immediate Actions

1. **Test the Application**
   - Visit http://localhost:8000
   - Explore API documentation at http://localhost:8000/docs
   - Run health checks

2. **Configure Monitoring**
   - Set up Prometheus and Grafana
   - Configure alerting rules
   - Monitor application metrics

3. **Set up CI/CD**
   - Configure GitHub Actions
   - Set up automated testing
   - Enable automatic deployments

### Production Considerations

1. **Security**
   - Configure SSL/TLS certificates
   - Set up proper authentication
   - Implement network policies

2. **Scalability**
   - Configure horizontal pod autoscaling
   - Set up load balancing
   - Optimize resource limits

3. **Backup and Recovery**
   - Set up database backups
   - Configure disaster recovery
   - Test backup restoration

### Advanced Features

1. **Database Setup**
   - Configure MongoDB cluster
   - Set up database replication
   - Implement data backup strategies

2. **Monitoring and Observability**
   - Set up centralized logging
   - Configure distributed tracing
   - Implement custom metrics

3. **Security Hardening**
   - Implement RBAC policies
   - Configure network security
   - Set up secrets management

## 📞 Support

### Getting Help

- **Documentation**: Check this guide and the main README
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions
- **Email**: contact@bonaventure.org.ng

### Useful Commands

```bash
# Check application status
kubectl get all -n nativeseries

# View application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# Port forward for local access
kubectl port-forward svc/nativeseries -n nativeseries 8000:80

# Access ArgoCD locally
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

### Scripts Directory

All installation and deployment scripts are located in the `scripts/` directory:

- **`scripts/install-all.sh`**: Complete automated installation
- **`scripts/deploy.sh`**: Production deployment script
- **`scripts/deploy-simple.sh`**: Simplified deployment for CI/CD
- **`scripts/stop-installation.sh`**: Stop all installation processes
- **`scripts/smoke-tests.sh`**: Health check and smoke tests
- **`scripts/get-docker.sh`**: Docker installation script
- **`scripts/setup-argocd.sh`**: ArgoCD setup script
- **`scripts/cleanup.sh`**: Cleanup and reset script
- **`scripts/backup-before-cleanup.sh`**: Backup before cleanup

### Quick Reference

```bash
# Quick start
./scripts/install-all.sh

# Deploy to production
./scripts/deploy.sh

# Stop installation
./scripts/stop-installation.sh

# Run tests
./scripts/smoke-tests.sh http://localhost:8000

# Cleanup everything
./scripts/cleanup.sh
```

---

**🎉 Congratulations! Your nativeseries application is now installed and ready to use!**

For more information, visit: https://github.com/bonaventuresimeon/nativeseries