# 🚀 NativeSeries - Complete Deployment Guide

## 📋 Overview

This guide will help you deploy all NativeSeries resources to your Kubernetes cluster. The deployment includes:

- **NativeSeries Application** (with Helm chart)
- **ArgoCD GitOps Dashboard**
- **Prometheus Monitoring**
- **Grafana Dashboards**
- **Loki Logging**
- **Promtail Log Collection**

## 🎯 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Run the complete deployment script
./scripts/deploy-to-cluster.sh
```

### Option 2: Manual Deployment

If you prefer to deploy manually, follow these steps:

## 📦 Prerequisites

1. **Kubernetes Cluster**: Ensure you have access to a Kubernetes cluster
2. **kubectl**: Install and configure kubectl
3. **Helm**: Install Helm 3.x
4. **Docker Image**: Ensure the Docker image is available

## 🔧 Manual Deployment Steps

### Step 1: Verify Cluster Access

```bash
# Check cluster access
kubectl cluster-info

# Verify current context
kubectl config current-context
```

### Step 2: Create Namespaces

```bash
# Apply namespace manifests
kubectl apply -f deployment/production/01-namespace.yaml

# Verify namespaces
kubectl get namespaces | grep -E "(nativeseries|argocd|monitoring|logging)"
```

### Step 3: Deploy NativeSeries Application

```bash
# Deploy using Helm
helm upgrade --install nativeseries helm-chart \
    --namespace nativeseries \
    --create-namespace \
    --set image.repository=ghcr.io/bonaventuresimeon/nativeseries \
    --set image.tag=latest \
    --set service.nodePort=30011 \
    --wait \
    --timeout=10m

# Verify deployment
kubectl get pods,services,ingress -n nativeseries
```

### Step 4: Deploy ArgoCD

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply ArgoCD service
kubectl apply -f deployment/production/04-argocd-service.yaml

# Verify ArgoCD
kubectl get pods,services -n argocd
```

### Step 5: Deploy Monitoring and Logging Stack

```bash
# Deploy monitoring and logging
kubectl apply -f deployment/production/06-monitoring-stack.yaml

# Wait for components
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring || true
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring || true
kubectl wait --for=condition=available --timeout=300s deployment/loki -n logging || true

# Verify monitoring
kubectl get pods,services -n monitoring

# Verify logging
kubectl get pods,services -n logging
```

### Step 6: Create ArgoCD Application

```bash
# Create ArgoCD application
kubectl apply -f deployment/production/05-argocd-application.yaml
```

## 🌐 Access URLs

After successful deployment, access your services at:

### 📱 NativeSeries Application
- **Main App**: http://54.166.101.159:30011
- **Health Check**: http://54.166.101.159:30011/health
- **API Docs**: http://54.166.101.159:30011/docs

### 🎯 ArgoCD GitOps Dashboard
- **URL**: http://54.166.101.159:30080
- **Username**: admin
- **Password**: 
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### 📊 Monitoring Stack
- **Grafana**: http://54.166.101.159:30081 (admin/admin123)
- **Prometheus**: http://54.166.101.159:30082

### 📝 Logging Stack
- **Loki**: http://54.166.101.159:30083
- **Grafana Logs**: Access through Grafana UI (Loki data source pre-configured)

## 🔍 Verification Commands

### Check All Pods Status

```bash
# Application pods
kubectl get pods -n nativeseries

# ArgoCD pods
kubectl get pods -n argocd

# Monitoring pods
kubectl get pods -n monitoring

# Logging pods
kubectl get pods -n logging
```

### Check All Services

```bash
# All NodePort services
kubectl get services --all-namespaces -o wide | grep NodePort

# Application services
kubectl get services -n nativeseries

# ArgoCD services
kubectl get services -n argocd

# Monitoring services
kubectl get services -n monitoring

# Logging services
kubectl get services -n logging
```

### Check Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods --all-namespaces
```

## 🛠️ Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   # Check pod events
   kubectl describe pod <pod-name> -n <namespace>
   
   # Check pod logs
   kubectl logs <pod-name> -n <namespace>
   ```

2. **Services not accessible**:
   ```bash
   # Check service endpoints
   kubectl get endpoints -n <namespace>
   
   # Check service configuration
   kubectl describe service <service-name> -n <namespace>
   ```

3. **ArgoCD password issues**:
   ```bash
   # Get ArgoCD admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

### Health Checks

```bash
# Application health
curl http://54.166.101.159:30011/health

# ArgoCD health
curl http://54.166.101.159:30080

# Prometheus health
curl http://54.166.101.159:30082/-/ready

# Grafana health
curl http://54.166.101.159:30081/api/health

# Loki health
curl http://54.166.101.159:30083/ready
```

## 📊 Monitoring Setup

### Grafana Dashboards

1. Access Grafana at http://54.166.101.159:30081
2. Login with admin/admin123
3. Navigate to Dashboards
4. Import dashboards for:
   - Kubernetes Cluster Monitoring
   - Application Metrics
   - Log Analysis

### Prometheus Targets

1. Access Prometheus at http://54.166.101.159:30082
2. Go to Status > Targets
3. Verify all targets are UP

### Loki Log Queries

1. Access Grafana at http://54.166.101.159:30081
2. Go to Explore
3. Select Loki data source
4. Query examples:
   ```
   {job="containerlogs"}
   {namespace="nativeseries"}
   {app="nativeseries"}
   ```

## 🔄 GitOps with ArgoCD

### Application Management

1. Access ArgoCD at http://54.166.101.159:30080
2. Login with admin credentials
3. Navigate to Applications
4. Monitor application sync status

### Continuous Deployment

The ArgoCD application is configured to:
- Monitor the Git repository
- Auto-sync on changes
- Apply Helm chart updates
- Maintain desired state

## 🎯 Next Steps

1. **Configure CI/CD**: Set up GitHub Actions or other CI/CD tools
2. **Custom Dashboards**: Create custom Grafana dashboards
3. **Alerting**: Configure Prometheus alerting rules
4. **Backup**: Set up backup strategies for persistent data
5. **Security**: Implement RBAC and network policies

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review pod logs and events
3. Verify all prerequisites are met
4. Ensure cluster has sufficient resources

---

**🎉 Congratulations! Your NativeSeries stack is now deployed and ready to use!**