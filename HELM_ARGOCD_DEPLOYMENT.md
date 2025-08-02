# Helm and ArgoCD Deployment Guide

This document provides a comprehensive guide for deploying your application using Helm charts and ArgoCD for GitOps automation.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Security](#security)

## Overview

This deployment setup uses:
- **Helm**: For packaging and templating Kubernetes manifests
- **ArgoCD**: For GitOps continuous deployment
- **GitHub Actions**: For CI/CD pipeline automation
- **PostgreSQL**: As the primary database
- **Redis**: For caching and session storage
- **Prometheus**: For monitoring and metrics collection

## Prerequisites

### Required Tools
- `kubectl` (v1.24+)
- `helm` (v3.12+)
- `argocd` CLI
- `docker`
- `git`

### Kubernetes Cluster
- A running Kubernetes cluster (v1.24+)
- Ingress controller (nginx-ingress recommended)
- Cert-manager (for SSL certificates)
- Prometheus Operator (for monitoring)

### Infrastructure Requirements
- Minimum 4 CPU cores
- Minimum 8GB RAM
- Minimum 50GB storage
- Network access to container registries

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   GitHub Actions│    │   Container     │
│                 │    │                 │    │   Registry      │
│  ┌───────────┐  │    │  ┌───────────┐  │    │                 │
│  │   Code    │──┼───▶│   Build    │──┼───▶│   Image         │
│  │   Push    │  │    │   & Test   │  │    │                 │
│  └───────────┘  │    └───────────┘  │    └─────────────────┘
└─────────────────┘    └─────────────────┘              │
                                                        │
┌─────────────────┐    ┌─────────────────┐              │
│   ArgoCD        │    │   Kubernetes    │              │
│   Server        │    │   Cluster       │              │
│                 │    │                 │              │
│  ┌───────────┐  │    │  ┌───────────┐  │              │
│  │   GitOps  │◀─┼────┼─▶│   Helm    │◀─┼──────────────┘
│  │   Sync    │  │    │  │   Chart   │  │
│  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘
```

## Installation

### 1. Install Prerequisites

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### 2. Setup Kubernetes Cluster

```bash
# Verify cluster connectivity
kubectl cluster-info

# Install nginx-ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

### 3. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Configuration

### 1. Update Helm Values

Edit `helm-chart/values.yaml` to configure your application:

```yaml
app:
  name: my-app
  image:
    repository: your-registry/my-app
    tag: latest
  replicas: 2
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

ingress:
  enabled: true
  hosts:
    - host: your-domain.com
      paths:
        - path: /
          pathType: Prefix

postgresql:
  enabled: true
  auth:
    postgresPassword: "your-secure-password"
    database: myapp

redis:
  enabled: true
  auth:
    password: "your-redis-password"
```

### 2. Update ArgoCD Application

Edit `argocd/application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/your-username/my-app.git
    targetRevision: HEAD
    path: helm-chart
    helm:
      parameters:
        - name: app.image.repository
          value: your-registry/my-app
        - name: app.image.tag
          value: latest
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

### 3. Environment Variables

Create a Kubernetes secret for sensitive data:

```bash
kubectl create secret generic app-secrets \
  --from-literal=SECRET_KEY=your-secret-key \
  --from-literal=API_KEY=your-api-key \
  -n my-app
```

## Deployment

### 1. Automated Deployment (Recommended)

The deployment is automated through GitHub Actions. Simply push to the main branch:

```bash
git add .
git commit -m "Update application"
git push origin main
```

### 2. Manual Deployment

Use the provided deployment script:

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh
```

### 3. Helm Deployment

Deploy manually with Helm:

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Update dependencies
cd helm-chart
helm dependency update
cd ..

# Install chart
helm upgrade --install my-app helm-chart \
  --namespace my-app \
  --create-namespace \
  --wait \
  --timeout 10m
```

### 4. ArgoCD Deployment

```bash
# Apply ArgoCD application
kubectl apply -f argocd/application.yaml

# Sync application
argocd app sync my-app --prune
```

## Monitoring

### 1. Application Metrics

The application exposes metrics at `/metrics` endpoint. Prometheus automatically scrapes these metrics.

### 2. ArgoCD Monitoring

Access ArgoCD UI at `http://localhost:8080`:
- Username: `admin`
- Password: Get from secret `argocd-initial-admin-secret`

### 3. Kubernetes Monitoring

```bash
# Check application status
kubectl get all -n my-app

# Check ArgoCD application status
argocd app get my-app

# Check logs
kubectl logs -f deployment/my-app -n my-app

# Check ingress
kubectl get ingress -n my-app
```

### 4. Prometheus Monitoring

Access Prometheus at `http://localhost:9090` and Grafana at `http://localhost:3000`.

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check image pull secrets
   kubectl get secrets -n my-app
   
   # Create image pull secret if needed
   kubectl create secret docker-registry regcred \
     --docker-server=your-registry.com \
     --docker-username=your-username \
     --docker-password=your-password \
     -n my-app
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL status
   kubectl get pods -n my-app -l app=postgresql
   
   # Check database logs
   kubectl logs -f deployment/postgresql -n my-app
   ```

3. **ArgoCD Sync Issues**
   ```bash
   # Check ArgoCD application status
   argocd app get my-app
   
   # Force sync
   argocd app sync my-app --prune --force
   
   # Check ArgoCD logs
   kubectl logs -f deployment/argocd-server -n argocd
   ```

4. **Ingress Issues**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check ingress status
   kubectl describe ingress my-app -n my-app
   ```

### Debug Commands

```bash
# Get detailed application info
kubectl describe deployment my-app -n my-app

# Check events
kubectl get events -n my-app --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n my-app

# Check network policies
kubectl get networkpolicies -n my-app
```

## Security

### 1. Network Security

```yaml
# Network policy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app-network-policy
  namespace: my-app
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: postgresql
    ports:
    - protocol: TCP
      port: 5432
```

### 2. RBAC Configuration

```yaml
# Service account with minimal permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app-role
  namespace: my-app
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-rolebinding
  namespace: my-app
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: my-app
roleRef:
  kind: Role
  name: my-app-role
  apiGroup: rbac.authorization.k8s.io
```

### 3. Security Best Practices

- Use non-root containers
- Implement resource limits
- Use secrets for sensitive data
- Enable network policies
- Regular security updates
- Monitor for vulnerabilities

## Maintenance

### 1. Updates

```bash
# Update Helm chart
helm upgrade my-app helm-chart --namespace my-app

# Update ArgoCD application
kubectl apply -f argocd/application.yaml
argocd app sync my-app
```

### 2. Backup

```bash
# Backup PostgreSQL
kubectl exec -it deployment/postgresql -n my-app -- pg_dump -U postgres myapp > backup.sql

# Backup Kubernetes resources
kubectl get all -n my-app -o yaml > backup.yaml
```

### 3. Scaling

```bash
# Scale application
kubectl scale deployment my-app --replicas=5 -n my-app

# Or update values.yaml and redeploy
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review ArgoCD and Helm documentation
3. Check GitHub Issues
4. Contact the development team

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)