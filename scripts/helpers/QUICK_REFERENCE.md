# Quick Reference Guide

## 🚀 Getting Started

### 1. Install All Tools
```bash
./scripts/deploy.sh --install-tools
```

### 2. Set Up Local Development
```bash
./scripts/helpers/dev-workflow.sh setup
```

### 3. Build and Deploy
```bash
./scripts/helpers/dev-workflow.sh build
```

## 📋 Useful Commands

### Kubernetes Shortcuts (after sourcing ~/.bashrc)
```bash
k get pods              # kubectl get pods
kgp                     # kubectl get pods
kgs                     # kubectl get services
kgd                     # kubectl get deployments
kl <pod-name>          # kubectl logs
kex <pod-name>         # kubectl exec -it
kctx                   # kubectx (switch contexts)
kns                    # kubens (switch namespaces)
```

### Docker Shortcuts
```bash
d ps                   # docker ps
dps                    # docker ps
dpa                    # docker ps -a
di                     # docker images
dlogs <container>      # docker logs
dexec <container>      # docker exec -it
```

### Helm Shortcuts
```bash
h list                 # helm list
hls                    # helm list
his <name> <chart>     # helm install
hup <name> <chart>     # helm upgrade
```

## 🛠️ Development Workflow

### Local Development
```bash
# Setup local cluster
./scripts/helpers/setup-local-cluster.sh

# Development workflow
./scripts/helpers/dev-workflow.sh setup
./scripts/helpers/dev-workflow.sh build
./scripts/helpers/dev-workflow.sh port-forward

# View logs
./scripts/helpers/dev-workflow.sh logs

# Check status
./scripts/helpers/dev-workflow.sh status

# Cleanup
./scripts/helpers/dev-workflow.sh clean
```

### Production Deployment
```bash
# Full deployment with pruning
./scripts/deploy.sh --force-prune

# Deploy without pruning
./scripts/deploy.sh --skip-prune

# Deploy to production with Docker Hub
./scripts/deploy.sh  # Choose option 6
```

## 🔧 Cluster Management

### Kind Cluster
```bash
# Create cluster
kind create cluster --name student-tracker

# Load image
kind load docker-image student-tracker:latest --name student-tracker

# Delete cluster
kind delete cluster --name student-tracker
```

### Minikube Cluster
```bash
# Start cluster
minikube start --driver=docker

# Enable addons
minikube addons enable ingress

# Stop cluster
minikube stop

# Delete cluster
minikube delete
```

## 📊 Monitoring and Debugging

### Useful Tools
- **k9s**: Terminal-based Kubernetes dashboard (`k9s`)
- **kubectx**: Switch between clusters (`kubectx`)
- **kubens**: Switch between namespaces (`kubens`)

### Common Debug Commands
```bash
# Check pod logs
kubectl logs -f <pod-name> -n <namespace>

# Describe resources
kubectl describe pod <pod-name> -n <namespace>
kubectl describe service <service-name> -n <namespace>

# Port forward for testing
kubectl port-forward service/<service-name> 8080:80 -n <namespace>

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

## 🚨 Troubleshooting

### Common Issues
1. **Docker daemon not running**: `sudo systemctl start docker`
2. **Permission denied for Docker**: `sudo usermod -aG docker $USER` (then logout/login)
3. **Kubectl context issues**: `kubectl config get-contexts` and `kubectl config use-context <context>`
4. **Helm deployment fails**: Check `helm list` and `kubectl get pods -n <namespace>`

### Reset Everything
```bash
# Complete system reset
./scripts/deploy.sh --force-prune

# Clean local clusters
./scripts/helpers/cleanup-local-cluster.sh
```
