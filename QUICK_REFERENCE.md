# 🚀 Quick Reference Card

## 🧪 Local Development

```bash
# Set up local environment
./scripts/setup-local-dev.sh

# Clean up local environment
./scripts/setup-local-dev.sh cleanup

# Rebuild and reload image
docker build -t student-tracker:latest .
kind load docker-image student-tracker:latest --name student-tracker-dev
kubectl rollout restart deployment/student-tracker -n student-tracker
```

## 🚀 Production Deployment

```bash
# Automated deployment
./scripts/deploy-production.sh

# Manual deployment steps
kubectl create namespace argocd
helm install argocd argo-cd/argo-cd --namespace argocd
kubectl apply -f argocd/application.yaml
argocd app sync student-tracker --prune --force
```

## 🔧 Common Commands

### ArgoCD
```bash
# Check application status
argocd app get student-tracker

# Sync application
argocd app sync student-tracker --prune --force

# Check logs
argocd app logs student-tracker
```

### Kubernetes
```bash
# Check pods
kubectl get pods -n student-tracker

# Check services
kubectl get services -n student-tracker

# Check ingress
kubectl get ingress -n student-tracker

# Port forward
kubectl port-forward -n student-tracker svc/student-tracker 8080:8000
```

### Helm
```bash
# Validate chart
helm lint ./helm-chart

# Template chart
helm template student-tracker ./helm-chart

# Install chart
helm install student-tracker ./helm-chart --namespace student-tracker
```

## 🌐 Access URLs

### Local Development
- **Student Tracker**: http://student-tracker.local:30011
- **ArgoCD UI**: http://localhost:30080
- **ArgoCD Admin Password**: Check script output

### Production
- **Student Tracker**: https://student-tracker.yourdomain.com
- **ArgoCD UI**: https://argocd.yourdomain.com
- **Health Check**: https://student-tracker.yourdomain.com/health

## 🔒 Security Commands

```bash
# Check security contexts
kubectl get pods -n student-tracker -o yaml | grep -A 10 securityContext

# Check network policies
kubectl get networkpolicy -n student-tracker

# Check TLS certificates
kubectl get certificates -n student-tracker
```

## 📊 Monitoring Commands

```bash
# Check HPA status
kubectl get hpa -n student-tracker

# Check metrics
kubectl get servicemonitor -n student-tracker

# Check resource usage
kubectl top pods -n student-tracker
```

## 🛠️ Troubleshooting

```bash
# Check pod logs
kubectl logs -n student-tracker deployment/student-tracker

# Check events
kubectl get events -n student-tracker --sort-by='.lastTimestamp'

# Describe resource
kubectl describe pod -n student-tracker <pod-name>
```

## 📝 Configuration Files

### Key Files
- `helm-chart/values.yaml` - Production configuration
- `helm-chart/values-local.yaml` - Local development configuration
- `argocd/application.yaml` - ArgoCD application definition
- `scripts/deploy-production.sh` - Production deployment script
- `scripts/setup-local-dev.sh` - Local development setup

### Environment Variables
```bash
# Local development
ENVIRONMENT=development
MONGO_URI=mongodb://localhost:27017

# Production
ENVIRONMENT=production
MONGO_URI=mongodb://your-production-mongo:27017
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
- **Security Scan**: Trivy + Bandit
- **Quality Check**: Black + Flake8 + MyPy
- **Helm Validation**: Chart linting
- **Docker Build**: Multi-platform images
- **ArgoCD Sync**: GitOps deployment

### Manual Triggers
```bash
# Trigger staging deployment
gh workflow run enhanced-deploy.yml -f environment=staging

# Trigger production deployment
gh workflow run enhanced-deploy.yml -f environment=production
```

## 📚 Useful Links

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Helm Docs](https://helm.sh/docs/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Docs](https://cert-manager.io/docs/)

---

**💡 Tip**: Use `kubectl get all -n student-tracker` to see all resources in the namespace at once.