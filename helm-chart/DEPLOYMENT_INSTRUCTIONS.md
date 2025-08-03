# 🚀 Deployment Instructions

## Option 1: GitHub Actions (Recommended)

1. Push your changes to the main branch
2. GitHub Actions will automatically:
   - Validate code and Helm charts
   - Build and push Docker images
   - Deploy via ArgoCD (if cluster configured)

## Option 2: Local Development

```bash
# Set up local environment
./scripts/setup-local-dev.sh

# Access application
# - Student Tracker: http://student-tracker.local:30011
# - ArgoCD UI: http://localhost:30080
```

## Option 3: Manual Deployment

### Prerequisites
- Kubernetes cluster (EKS, GKE, AKS, or local)
- kubectl configured
- Helm 3.x installed

### Steps
```bash
# 1. Install ArgoCD
kubectl create namespace argocd
helm repo add argo-cd https://argoproj.github.io/argo-helm
helm install argocd argo-cd/argo-cd --namespace argocd

# 2. Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# 3. Deploy application
kubectl apply -f argocd/application.yaml
argocd app sync student-tracker --prune --force
```

## Option 4: Remote Cluster

1. Configure kubectl for your cluster
2. Run: ./scripts/deploy-production.sh
3. Follow the automated deployment process

## Generated Manifests

The script has generated deployment manifests:
- `manifests/production.yaml` - Production configuration
- `manifests/staging.yaml` - Staging configuration

You can apply these manually:
```bash
kubectl apply -f manifests/production.yaml
```
