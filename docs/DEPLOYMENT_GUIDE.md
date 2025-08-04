# GitOps Deployment Guide

This guide walks you through deploying the Student Tracker application using a complete GitOps workflow with Kind, Helm, ArgoCD, and GitHub Actions.

## 🎯 Overview

The deployment creates:
- **Kind cluster**: Local Kubernetes cluster for development
- **ArgoCD**: GitOps continuous delivery tool
- **Helm charts**: Parameterized Kubernetes applications
- **CI/CD pipeline**: Automated testing and deployment
- **Multi-environment setup**: Dev, staging, and production environments

## 🚀 Quick Deployment

### Prerequisites Check

```bash
# Verify all required tools are installed
docker --version
kind --version
kubectl version --client
helm version
```

### One-Command Setup

```bash
# Deploy the entire stack
./scripts/deploy-all.sh
```

This will set up everything automatically and provide access URLs.

## 📋 Manual Deployment Steps

### 1. Create Kind Cluster

```bash
# Create cluster with ingress support
./scripts/setup-kind.sh

# Verify cluster is ready
kubectl cluster-info
kubectl get nodes
```

### 2. Build Application Image

```bash
# Build Docker image
docker build -t student-tracker:latest -f docker/Dockerfile .

# Load image into Kind cluster
kind load docker-image student-tracker:latest --name gitops-cluster
```

### 3. Install ArgoCD

```bash
# Install and configure ArgoCD
./scripts/setup-argocd.sh

# Verify ArgoCD is running
kubectl get pods -n argocd
```

### 4. Deploy Application via Helm

```bash
# Deploy to development environment
helm upgrade --install student-tracker infra/helm \
  --values infra/helm/values-dev.yaml \
  --namespace app-dev \
  --create-namespace

# Verify deployment
kubectl get pods -n app-dev
kubectl get svc -n app-dev
kubectl get ingress -n app-dev
```

### 5. Configure ArgoCD Applications

```bash
# Apply ArgoCD application manifests
kubectl apply -f k8s/argocd/app-of-apps.yaml

# Check application status in ArgoCD
argocd app list
argocd app get app-of-apps
```

## 🌐 Access Services

### ArgoCD UI
```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80

# Access at: http://localhost:8080
# Username: admin
# Password: Check .argocd-password file
```

### Student Tracker API
```bash
# Port forward to access API
kubectl port-forward svc/student-tracker -n app-dev 8000:80

# Access at: http://localhost:8000
# API docs: http://localhost:8000/docs
```

### Ingress Access
Add to `/etc/hosts`:
```
127.0.0.1 student-tracker.local
127.0.0.1 student-tracker-dev.local
```

## 🔄 GitOps Workflow

### Repository Setup

1. **Fork/Clone Repository**
   ```bash
   git clone https://github.com/your-org/student-tracker.git
   cd student-tracker
   ```

2. **Update Repository URLs**
   Update these files with your repository URL:
   - `infra/argocd/parent/app-of-apps.yaml`
   - `infra/argocd/parent/helm-app.yaml`
   - `k8s/argocd/app-of-apps.yaml`

3. **Configure GitHub Secrets**
   Add these secrets to your GitHub repository:
   - `GITHUB_TOKEN` (automatically available)
   - Additional secrets for production deployments

### Development Workflow

1. **Feature Development**
   ```bash
   git checkout -b feature/new-feature
   # Make changes
   git commit -m "Add new feature"
   git push origin feature/new-feature
   ```

2. **Create Pull Request**
   - CI pipeline runs tests and builds image
   - Security scans are performed
   - Helm charts are validated

3. **Merge to Develop**
   ```bash
   git checkout develop
   git merge feature/new-feature
   git push origin develop
   ```
   - Triggers development deployment
   - Image is built and pushed
   - ArgoCD syncs new version

4. **Production Release**
   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```
   - Creates production deployment PR
   - Manual approval required for production

## 🏗️ Environment Configuration

### Development Environment
- **Namespace**: `app-dev`
- **Replicas**: 1
- **Resources**: Limited (250m CPU, 256Mi RAM)
- **Auto-sync**: Enabled
- **Domain**: `student-tracker-dev.local`

### Staging Environment
- **Namespace**: `app-staging`
- **Replicas**: 2
- **Resources**: Medium (500m CPU, 512Mi RAM)
- **Auto-sync**: Enabled
- **Domain**: `student-tracker-staging.local`

### Production Environment
- **Namespace**: `app-prod`
- **Replicas**: 3+
- **Resources**: High (1000m CPU, 1Gi RAM)
- **Auto-sync**: Manual
- **Domain**: `student-tracker.yourdomain.com`

## 🔧 Customization

### Helm Values

Modify environment-specific values:

```yaml
# infra/helm/values-dev.yaml
replicaCount: 1
image:
  tag: develop-latest
resources:
  limits:
    cpu: 250m
    memory: 256Mi
env:
  - name: APP_ENV
    value: "development"
```

### ArgoCD Applications

Create new applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-tracker-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/student-tracker.git
    path: infra/helm
    helm:
      valueFiles:
        - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: app-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🔍 Monitoring and Debugging

### Check Application Status

```bash
# Kubernetes resources
kubectl get all -n app-dev
kubectl describe deployment student-tracker -n app-dev
kubectl logs -f deployment/student-tracker -n app-dev

# ArgoCD applications
argocd app list
argocd app get student-tracker-dev
argocd app sync student-tracker-dev

# Helm releases
helm list -n app-dev
helm status student-tracker -n app-dev
```

### Common Issues

**Application not starting**
```bash
# Check pod status and logs
kubectl get pods -n app-dev
kubectl describe pod <pod-name> -n app-dev
kubectl logs <pod-name> -n app-dev
```

**ArgoCD sync issues**
```bash
# Check application health
argocd app get student-tracker-dev
argocd app sync student-tracker-dev --force
```

**Image pull errors**
```bash
# Reload image into Kind
kind load docker-image student-tracker:latest --name gitops-cluster
```

## 🧹 Cleanup

### Remove Everything
```bash
./scripts/cleanup.sh
```

### Selective Cleanup
```bash
# Remove application
helm uninstall student-tracker -n app-dev

# Remove ArgoCD
kubectl delete namespace argocd

# Remove Kind cluster
kind delete cluster --name gitops-cluster
```

## 🔐 Security Considerations

### Production Setup

1. **Use private container registry**
2. **Configure TLS certificates**
3. **Set up RBAC properly**
4. **Enable network policies**
5. **Use secrets management**
6. **Configure monitoring and alerting**

### ArgoCD Security

1. **Enable OIDC/SSO integration**
2. **Configure RBAC policies**
3. **Use project isolation**
4. **Enable audit logging**

## 📈 Scaling

### Horizontal Pod Autoscaler

```yaml
# Enable in values.yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

### Cluster Autoscaler

For production environments, consider:
- Cluster autoscaler for node scaling
- Vertical pod autoscaler for resource optimization
- Pod disruption budgets for availability

## 🎓 Next Steps

1. **Set up monitoring** with Prometheus and Grafana
2. **Configure logging** with ELK or similar stack
3. **Implement secrets management** with Vault or similar
4. **Add backup and disaster recovery** procedures
5. **Set up multi-cluster deployments** for production
6. **Implement progressive delivery** with Argo Rollouts

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitOps Best Practices](https://opengitops.dev/)