# 🚀 Enhanced Deployment Guide

This guide implements the **Kubernetes + Helm + ArgoCD + Ingress** stack as recommended in the reference guide, with production-ready configurations and local development support.

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [🏗️ Architecture](#️-architecture)
- [🧪 Local Development](#-local-development)
- [🚀 Production Deployment](#-production-deployment)
- [🔧 Configuration](#-configuration)
- [📊 Monitoring](#-monitoring)
- [🔒 Security](#-security)
- [🛠️ Troubleshooting](#️-troubleshooting)

---

## 🎯 Overview

This enhanced setup provides:

✅ **Complete GitOps Stack**: Docker + Helm + ArgoCD + Ingress  
✅ **Multi-Environment Support**: Local, Staging, Production  
✅ **Security Best Practices**: Network policies, security contexts, vulnerability scanning  
✅ **Production Ready**: TLS, monitoring, auto-scaling, health checks  
✅ **Local Development**: kind cluster with full parity to production  

---

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   Docker Hub    │    │   Kubernetes    │
│                 │    │   / GHCR        │    │   Cluster       │
│  ┌───────────┐  │    │                 │    │                 │
│  │   Code    │──┼───▶│   Container    │───▶│  ┌───────────┐  │
│  │  Changes  │  │    │    Images      │    │  │   ArgoCD   │  │
│  └───────────┘  │    └─────────────────┘    │  │ Controller │  │
└─────────────────┘                            │  └───────────┘  │
                                               │        │        │
                                               │  ┌───────────┐  │
                                               │  │   Helm    │  │
                                               │  │  Charts   │  │
                                               │  └───────────┘  │
                                               │        │        │
                                               │  ┌───────────┐  │
                                               │  │ Ingress   │  │
                                               │  │Controller │  │
                                               │  └───────────┘  │
                                               │        │        │
                                               │  ┌───────────┐  │
                                               │  │ Student   │  │
                                               │  │ Tracker   │  │
                                               │  │   App     │  │
                                               │  └───────────┘  │
                                               └─────────────────┘
```

### 🔄 Deployment Flow

1. **Code Push** → GitHub Actions triggers
2. **Security Scan** → Trivy + Bandit vulnerability scanning
3. **Quality Check** → Code formatting, linting, testing
4. **Helm Validation** → Chart linting and templating
5. **Docker Build** → Multi-platform image build and push
6. **ArgoCD Sync** → GitOps deployment to cluster
7. **Health Check** → Post-deployment verification

---

## 🧪 Local Development

### Quick Start with kind

```bash
# Set up local development environment
./scripts/setup-local-dev.sh

# Access your application
# - Student Tracker: http://student-tracker.local:30011
# - ArgoCD UI: http://localhost:30080
```

### What the Local Setup Provides

✅ **kind Cluster**: Local Kubernetes with Docker  
✅ **NGINX Ingress**: Production-like ingress controller  
✅ **ArgoCD**: GitOps management locally  
✅ **Local DNS**: Automatic /etc/hosts configuration  
✅ **Image Loading**: Direct Docker image loading into cluster  

### Development Workflow

```bash
# 1. Make code changes
vim app/main.py

# 2. Rebuild Docker image
docker build -t student-tracker:latest .

# 3. Load into kind cluster
kind load docker-image student-tracker:latest --name student-tracker-dev

# 4. Restart deployment
kubectl rollout restart deployment/student-tracker -n student-tracker

# 5. Check status
kubectl get pods -n student-tracker
```

### Cleanup

```bash
# Clean up local environment
./scripts/setup-local-dev.sh cleanup
```

---

## 🚀 Production Deployment

### Prerequisites

- Kubernetes cluster (EKS, GKE, AKS, or self-hosted)
- kubectl configured
- Helm 3.x installed
- Domain name for your application

### Automated Deployment

```bash
# Run production deployment script
./scripts/deploy-production.sh
```

### Manual Deployment Steps

#### 1. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
helm repo add argo-cd https://argoproj.github.io/argo-helm
helm install argocd argo-cd/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer
```

#### 2. Install NGINX Ingress Controller

```bash
# Add repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Install ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

#### 3. Install cert-manager for TLS

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### 4. Deploy Application

```bash
# Create namespace
kubectl create namespace student-tracker

# Apply ArgoCD application
kubectl apply -f argocd/application.yaml

# Sync application
argocd app sync student-tracker --prune --force
```

### DNS Configuration

After deployment, configure your DNS:

```bash
# Get LoadBalancer IP
LB_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create DNS A record pointing to $LB_IP
```

---

## 🔧 Configuration

### Environment-Specific Values

#### Local Development (`values-local.yaml`)

```yaml
app:
  image:
    repository: student-tracker
    tag: latest
    pullPolicy: Never  # Use local images

ingress:
  enabled: true
  hosts:
    - host: student-tracker.local

hpa:
  enabled: false  # Disable auto-scaling locally

networkPolicy:
  enabled: false  # Disable network policies locally
```

#### Production (`values.yaml`)

```yaml
app:
  image:
    repository: ghcr.io/bonaventuresimeon/NativeSeries/student-tracker
    tag: latest
    pullPolicy: IfNotPresent

ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: student-tracker.yourdomain.com
  tls:
    - hosts:
        - student-tracker.yourdomain.com
      secretName: student-tracker-tls

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

networkPolicy:
  enabled: true
```

### Security Configuration

#### Network Policies

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8000
```

#### Security Contexts

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
      - ALL

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

---

## 📊 Monitoring

### Health Checks

The application includes comprehensive health checks:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Metrics and Monitoring

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  path: /metrics
  port: http
```

### Horizontal Pod Autoscaler

```yaml
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
```

---

## 🔒 Security

### Vulnerability Scanning

The CI/CD pipeline includes:

- **Trivy**: Container and filesystem vulnerability scanning
- **Bandit**: Python security linting
- **Code quality**: Black, Flake8, MyPy

### Security Best Practices

✅ **Non-root containers**: All containers run as non-root user  
✅ **Read-only filesystems**: Immutable container filesystems  
✅ **Network policies**: Restrictive network access  
✅ **Security contexts**: Pod and container security contexts  
✅ **TLS termination**: Automatic SSL certificate management  
✅ **Secret management**: Kubernetes secrets for sensitive data  

### Security Checklist

- [ ] All containers run as non-root
- [ ] Network policies are configured
- [ ] TLS certificates are properly configured
- [ ] Secrets are stored in Kubernetes secrets
- [ ] Vulnerability scanning is enabled
- [ ] Security contexts are configured
- [ ] Read-only filesystems are enabled

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. ArgoCD Application Not Syncing

```bash
# Check ArgoCD application status
argocd app get student-tracker

# Check application logs
argocd app logs student-tracker

# Force sync
argocd app sync student-tracker --prune --force
```

#### 2. Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress status
kubectl get ingress -n student-tracker

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

#### 3. TLS Certificate Issues

```bash
# Check cert-manager status
kubectl get pods -n cert-manager

# Check certificate status
kubectl get certificates -n student-tracker

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
```

#### 4. Pod Startup Issues

```bash
# Check pod status
kubectl get pods -n student-tracker

# Check pod logs
kubectl logs -n student-tracker deployment/student-tracker

# Check events
kubectl get events -n student-tracker --sort-by='.lastTimestamp'
```

### Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n student-tracker

# Describe specific resource
kubectl describe pod -n student-tracker <pod-name>

# Port forward for debugging
kubectl port-forward -n student-tracker svc/student-tracker 8080:8000

# Check ArgoCD server
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

### Logs and Monitoring

```bash
# Application logs
kubectl logs -n student-tracker -l app=student-tracker -f

# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

---

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---

## 🎯 Next Steps

1. **Customize Domain**: Update `student-tracker.yourdomain.com` with your actual domain
2. **Configure Monitoring**: Set up Prometheus and Grafana for metrics
3. **Add Backup**: Configure database backups and disaster recovery
4. **Security Audit**: Run security scans and penetration tests
5. **Performance Tuning**: Optimize resource limits and auto-scaling
6. **Documentation**: Add API documentation and user guides

---

**🎉 Congratulations!** You now have a production-ready Kubernetes deployment with GitOps automation, security best practices, and local development parity.