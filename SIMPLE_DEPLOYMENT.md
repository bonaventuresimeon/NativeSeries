# Simple Deployment Guide

This guide will help you deploy your application to `18.206.89.183:8011` using Kind, Helm, and ArgoCD.

## Prerequisites

Make sure you have the following tools installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Quick Deployment

Run the deployment script:

```bash
./deploy.sh
```

This script will:
1. Create a Kind cluster with port mapping to 8011
2. Build and load your Docker image
3. Install ArgoCD
4. Deploy your application using Helm
5. Set up ArgoCD for GitOps

## Manual Deployment Steps

If you prefer to run the steps manually:

### 1. Create Kind Cluster

```bash
kind create cluster --name simple-cluster --config infra/kind/cluster-config.yaml
```

### 2. Build and Load Docker Image

```bash
docker build -t simple-app:latest .
kind load docker-image simple-app:latest --name simple-cluster
```

### 3. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 4. Deploy Application

```bash
helm install simple-app infra/helm/ --namespace default --create-namespace
```

### 5. Apply ArgoCD Application

```bash
kubectl apply -f argocd/app.yaml
```

## Access Information

- **Application**: http://18.206.89.183:8011
- **ArgoCD UI**: https://localhost:8080 (after port forward)
- **ArgoCD Username**: admin
- **ArgoCD Password**: Get from `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## Useful Commands

```bash
# Check application status
kubectl get pods
kubectl get svc

# View application logs
kubectl logs -f deployment/simple-app

# Port forward to access application locally
kubectl port-forward svc/simple-app 8011:8011

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Cleanup

To clean up everything:

```bash
kind delete cluster --name simple-cluster
```

## Configuration Files

- **Kind Cluster**: `infra/kind/cluster-config.yaml`
- **Helm Chart**: `infra/helm/`
- **ArgoCD App**: `argocd/app.yaml`
- **Dockerfile**: `Dockerfile`

## Troubleshooting

1. **Port 8011 not accessible**: Make sure the Kind cluster is running and the port mapping is correct
2. **Image not found**: Ensure the Docker image is built and loaded into the Kind cluster
3. **ArgoCD not syncing**: Check the ArgoCD application status and logs
4. **Application not starting**: Check the pod logs for any startup issues