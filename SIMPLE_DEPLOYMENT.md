# Simple Deployment Guide

This guide will help you deploy your application to `18.206.89.183:8011` using a comprehensive deployment script that handles everything automatically.

## Prerequisites

The deployment script will automatically install all required tools, but you need:

- Ubuntu/Debian-based Linux system
- Internet connection
- Sudo privileges

## Quick Deployment

Run the comprehensive deployment script:

```bash
./deploy.sh
```

This script will automatically:

1. **Install all required tools:**
   - Docker and Docker Compose
   - kubectl
   - Kind (Kubernetes in Docker)
   - Helm
   - ArgoCD CLI
   - Additional utilities (curl, jq, tree)

2. **Clean up existing resources:**
   - Stop existing Docker containers
   - Delete existing Kind clusters
   - Remove old Docker images

3. **Set up Docker Compose environment:**
   - Build and start all services
   - Configure PostgreSQL database
   - Set up Redis cache
   - Configure Nginx reverse proxy
   - Start monitoring stack (Prometheus + Grafana)

4. **Create Kubernetes environment:**
   - Create Kind cluster with port mapping to 8011
   - Build and load Docker image
   - Install ArgoCD

5. **Deploy application:**
   - Deploy using Helm
   - Configure ArgoCD for GitOps
   - Set up port forwarding

## What Gets Deployed

### Docker Compose Services
- **Student Tracker App** (port 8011)
- **PostgreSQL Database** (port 5432)
- **Redis Cache** (port 6379)
- **Nginx Reverse Proxy** (port 80)
- **Prometheus Monitoring** (port 9090)
- **Grafana Dashboard** (port 3000)
- **Adminer Database UI** (port 8080)

### Kubernetes Services
- **Kind Cluster** with port mapping to 8011
- **ArgoCD** for GitOps management
- **Helm-deployed application**

## Access Information

After deployment, you can access:

- **Main Application**: http://18.206.89.183:8011
- **Docker Compose (via Nginx)**: http://18.206.89.183:80
- **ArgoCD UI**: https://localhost:8080 (after port forward)
- **Grafana Dashboard**: http://18.206.89.183:3000 (admin/admin123)
- **Prometheus**: http://18.206.89.183:9090
- **Adminer (Database)**: http://18.206.89.183:8080

## Manual Steps (if needed)

If you prefer to run steps manually or troubleshoot:

### 1. Install Tools Manually

```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/

# Helm
curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm /usr/local/bin/
```

### 2. Start Docker Compose

```bash
docker-compose up -d --build
```

### 3. Create Kind Cluster

```bash
kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml
```

### 4. Deploy to Kubernetes

```bash
# Build and load image
docker build -t simple-app:latest .
kind load docker-image simple-app:latest --name simple-cluster

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy application
helm install simple-app infra/helm/ --namespace default --create-namespace
```

## Useful Commands

```bash
# Check Docker Compose services
docker-compose ps
docker-compose logs -f

# Check Kubernetes resources
kubectl get pods
kubectl get svc
kubectl logs -f deployment/simple-app

# Access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Cleanup

To clean up everything:

```bash
./cleanup.sh
```

This will:
- Stop all Docker Compose services
- Delete the Kind cluster
- Remove Docker images and volumes
- Clean up temporary files

## Configuration Files

- **Docker Compose**: `docker-compose.yml`
- **Nginx Config**: `nginx.conf`
- **Prometheus Config**: `prometheus.yml`
- **Kind Cluster**: `infra/kind/cluster-config.yaml`
- **Helm Chart**: `infra/helm/`
- **ArgoCD App**: `argocd/app.yaml`
- **Dockerfile**: `Dockerfile`

## Troubleshooting

1. **Port 8011 not accessible**: Check if Kind cluster is running and port mapping is correct
2. **Docker Compose issues**: Run `docker-compose logs` to see service logs
3. **Kubernetes issues**: Check pod status with `kubectl get pods`
4. **ArgoCD not syncing**: Check application status in ArgoCD UI
5. **Permission issues**: Make sure you have sudo privileges

## Next Steps

1. Update the ArgoCD application URL in `argocd/app.yaml` to point to your actual Git repository
2. Run `./deploy.sh` to deploy everything
3. Access your application at http://18.206.89.183:8011

The setup is now comprehensive and handles everything automatically! 🚀