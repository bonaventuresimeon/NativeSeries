# Quick Start Guide

This guide will help you deploy your application using Helm and ArgoCD in under 10 minutes.

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Docker installed
- Git repository access

## Step 1: Clone and Setup

```bash
# Clone your repository
git clone https://github.com/your-username/my-app.git
cd my-app

# Make deployment script executable
chmod +x scripts/deploy.sh
```

## Step 2: Update Configuration

Edit `helm-chart/values.yaml`:

```yaml
app:
  image:
    repository: your-registry/my-app  # Update with your registry
    tag: latest

ingress:
  hosts:
    - host: your-domain.com  # Update with your domain
```

Edit `argocd/application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/your-username/my-app.git  # Update with your repo
```

## Step 3: Deploy

```bash
# Run the deployment script
./scripts/deploy.sh

# Choose option 1 for full deployment
# This will:
# - Install ArgoCD
# - Build Docker image
# - Deploy Helm chart
# - Setup ArgoCD application
```

## Step 4: Access Your Application

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD UI at http://localhost:8080
# Username: admin
# Password: (from command above)

# Check application status
kubectl get all -n my-app
```

## Step 5: Verify Deployment

```bash
# Check if all pods are running
kubectl get pods -n my-app

# Check application logs
kubectl logs -f deployment/my-app -n my-app

# Check ArgoCD application status
argocd app get my-app
```

## Troubleshooting

If you encounter issues:

1. **Check cluster connectivity:**
   ```bash
   kubectl cluster-info
   ```

2. **Check ArgoCD status:**
   ```bash
   kubectl get pods -n argocd
   ```

3. **Check application status:**
   ```bash
   kubectl get all -n my-app
   ```

4. **View detailed logs:**
   ```bash
   kubectl logs -f deployment/my-app -n my-app
   ```

## Next Steps

1. Update your domain in the ingress configuration
2. Set up SSL certificates with cert-manager
3. Configure monitoring with Prometheus
4. Set up CI/CD with GitHub Actions

For detailed configuration and advanced features, see [HELM_ARGOCD_DEPLOYMENT.md](HELM_ARGOCD_DEPLOYMENT.md).