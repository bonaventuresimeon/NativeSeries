#!/bin/bash

# Production Deployment Script
set -e

echo "🚀 Deploying Student Tracker to 54.166.101.159"

# Apply manifests in order
echo "📁 Creating namespaces..."
kubectl apply -f production/01-namespace.yaml

echo "📱 Deploying application..."
kubectl apply -f production/02-application.yaml

echo "🎯 Installing ArgoCD..."
kubectl apply -f production/03-argocd-install.yaml
kubectl apply -f production/04-argocd-service.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🎯 Creating ArgoCD application..."
kubectl apply -f production/05-argocd-application.yaml

echo "📊 Installing monitoring stack..."
kubectl apply -f production/06-monitoring-stack.yaml

echo "✅ Deployment complete!"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Application: http://54.166.101.159:30011"
echo "  🎯 ArgoCD: http://54.166.101.159:30080"
echo "  📊 Grafana: http://54.166.101.159:30081"
echo "  📈 Prometheus: http://54.166.101.159:30082"
echo ""
echo "🔑 Default Credentials:"
echo "  ArgoCD: admin / $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo "  Grafana: admin / admin123"
