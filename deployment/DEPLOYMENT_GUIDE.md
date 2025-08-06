# 🚀 Student Tracker Production Deployment Guide

## Target Environment
- **Server**: 54.166.101.159
- **Application Port**: 30011
- **ArgoCD Port**: 30080
- **Grafana Port**: 30081
- **Prometheus Port**: 30082

## Prerequisites
1. Kubernetes cluster accessible via kubectl
2. Helm 3.x installed
3. Docker registry access (GitHub Container Registry)
4. kubectl configured to access the target cluster

## Deployment Steps

### 1. Push Docker Images (Optional)
```bash
cd deployment
./push-images.sh
```

### 2. Deploy to Kubernetes
```bash
cd deployment
./deploy.sh
```

### 3. Check Deployment Status
```bash
cd deployment
./check-status.sh
```

## Access Information

### Application
- **URL**: http://54.166.101.159:30011
- **Health Check**: http://54.166.101.159:30011/health
- **API Docs**: http://54.166.101.159:30011/docs

### ArgoCD
- **URL**: http://54.166.101.159:30080
- **Username**: admin
- **Password**: Get with: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d`

### Grafana
- **URL**: http://54.166.101.159:30081
- **Username**: admin
- **Password**: admin123

### Prometheus
- **URL**: http://54.166.101.159:30082

## Manual Deployment Commands

If you prefer manual deployment:

```bash
# 1. Create namespaces
kubectl apply -f production/01-namespace.yaml

# 2. Deploy application
kubectl apply -f production/02-application.yaml

# 3. Install ArgoCD
kubectl apply -f production/03-argocd-install.yaml
kubectl apply -f production/04-argocd-service.yaml

# 4. Wait for ArgoCD
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 5. Create ArgoCD application
kubectl apply -f production/05-argocd-application.yaml

# 6. Install monitoring
kubectl apply -f production/06-monitoring-stack.yaml
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n nativeseries
kubectl get pods -n argocd
kubectl get pods -n monitoring
```

### Check Logs
```bash
kubectl logs -f deployment/nativeseries -n nativeseries
kubectl logs -f deployment/argocd-server -n argocd
```

### Port Forward for Local Access
```bash
kubectl port-forward svc/nativeseries -n nativeseries 8000:8000
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/grafana -n monitoring 3000:3000
```

## Security Notes
- Change default passwords in production
- Configure proper RBAC
- Enable TLS/SSL certificates
- Set up proper secrets management
- Configure network policies

## Monitoring
- Prometheus scrapes metrics from the application
- Grafana provides visualization dashboards
- ArgoCD provides GitOps deployment status
- Application health endpoint: /health

## Scaling
- HPA is configured for auto-scaling based on CPU/memory
- Adjust replica counts in helm-chart/values.yaml
- Monitor resource usage via Grafana dashboards

---
Generated on Wed Aug  6 03:19:27 AM UTC 2025 for deployment to 54.166.101.159
