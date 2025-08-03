# ArgoCD Configuration

This directory contains ArgoCD application configurations for different environments of the Student Tracker application.

## Environment Configurations

### Production (`application-production.yaml`)
- **Application URL**: https://student-tracker.yourdomain.com
- **ArgoCD URL**: https://argocd-prod.yourdomain.com
- **Branch**: `main`
- **Namespace**: `student-tracker-prod`
- **Replicas**: 2-10 (auto-scaling)
- **Environment**: production

### Staging (`application-staging.yaml`)
- **Application URL**: https://staging-student-tracker.yourdomain.com
- **ArgoCD URL**: https://argocd-staging.yourdomain.com
- **Branch**: `develop`
- **Namespace**: `student-tracker-staging`
- **Replicas**: 2-5 (auto-scaling)
- **Environment**: staging

### Development (`application-development.yaml`)
- **Application URL**: https://dev-student-tracker.yourdomain.com
- **ArgoCD URL**: https://argocd-dev.yourdomain.com
- **Branch**: `develop`
- **Namespace**: `student-tracker-dev`
- **Replicas**: 1-3 (auto-scaling)
- **Environment**: development

## ArgoCD URLs

The ArgoCD instances are accessible at the following URLs:

- **Production ArgoCD**: https://argocd-prod.yourdomain.com
- **Staging ArgoCD**: https://argocd-staging.yourdomain.com
- **Development ArgoCD**: https://argocd-dev.yourdomain.com

## Deployment Process

### Automatic Deployments

The GitHub Actions workflows automatically deploy to different environments:

1. **Development**: Triggered on pushes to `develop` branch
2. **Staging**: Triggered on workflow dispatch with staging environment selected
3. **Production**: Triggered on pushes to `main` branch

### Manual Deployment

You can manually deploy using ArgoCD CLI:

```bash
# Deploy to development
kubectl apply -f argocd/application-development.yaml
argocd app sync student-tracker-development

# Deploy to staging
kubectl apply -f argocd/application-staging.yaml
argocd app sync student-tracker-staging

# Deploy to production
kubectl apply -f argocd/application-production.yaml
argocd app sync student-tracker-production
```

## Configuration Details

### Helm Parameters

Each environment uses different Helm parameters:

- **Image tag**: `latest` (prod), `staging` (staging), `develop` (dev)
- **Environment variables**: Set according to environment
- **Resource limits**: Production has higher limits
- **Ingress hosts**: Different domains for each environment

### Sync Policies

All environments use:
- **Automated sync**: Enabled with prune and self-heal
- **Retry policy**: Exponential backoff with environment-specific limits
- **Sync options**: CreateNamespace, PrunePropagationPolicy, PruneLast

## Security

- All ArgoCD instances use TLS/SSL encryption
- Certificate management via cert-manager with Let's Encrypt
- NGINX ingress controller for load balancing
- GRPC backend protocol for ArgoCD server communication

## Monitoring

Each ArgoCD application includes info annotations for:
- Application URL
- ArgoCD dashboard URL
- Environment identifier

## Troubleshooting

### Common Issues

1. **Application not syncing**: Check the source repository and branch
2. **Image pull errors**: Verify GitHub Container Registry permissions
3. **Ingress issues**: Check cert-manager and NGINX ingress controller

### Useful Commands

```bash
# Check application status
argocd app get student-tracker-production

# View application logs
argocd app logs student-tracker-production

# Force sync
argocd app sync student-tracker-production --force

# Rollback to previous version
argocd app rollback student-tracker-production
```

## Domain Configuration

**Important**: Replace `yourdomain.com` with your actual domain in all configuration files:

- `helm-chart/values.yaml`
- `argocd/application-*.yaml`
- DNS records pointing to your Kubernetes cluster