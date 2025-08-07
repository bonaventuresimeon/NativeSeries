#!/bin/bash

# NativeSeries - Fix Helm Deployment Script
# Version: 1.0.0
# This script fixes Helm deployment issues by cleaning up conflicting resources

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_section() {
    echo -e "${PURPLE}📋 $1${NC}"
    echo "=================================="
}

# Configuration
NAMESPACE="nativeseries"
APP_NAME="nativeseries"
DOCKER_IMAGE="ghcr.io/bonaventuresimeon/nativeseries"
PRODUCTION_PORT="30080"

# Banner
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    NativeSeries                              ║"
echo "║              Helm Deployment Fix Script                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_section "Helm Deployment Fix"

print_info "This script will fix Helm deployment issues by cleaning up conflicting resources."
print_info "Target namespace: $NAMESPACE"
print_info "Application name: $APP_NAME"

echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
print_info "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_info "Please ensure your cluster is running and kubectl is configured"
    exit 1
fi
print_success "Cluster is accessible"

echo

# PHASE 1: Clean up existing resources
print_section "PHASE 1: Cleaning up existing resources"

print_info "Deleting existing resources in $NAMESPACE namespace..."

# Delete all resources that might conflict with Helm
kubectl delete networkpolicy -n $NAMESPACE --all --ignore-not-found=true
kubectl delete secret -n $NAMESPACE --field-selector type!=kubernetes.io/service-account-token --ignore-not-found=true
kubectl delete configmap -n $NAMESPACE --all --ignore-not-found=true
kubectl delete deployment -n $NAMESPACE --all --ignore-not-found=true
kubectl delete service -n $NAMESPACE --all --ignore-not-found=true
kubectl delete ingress -n $NAMESPACE --all --ignore-not-found=true
kubectl delete hpa -n $NAMESPACE --all --ignore-not-found=true
kubectl delete pdb -n $NAMESPACE --all --ignore-not-found=true
kubectl delete job -n $NAMESPACE --all --ignore-not-found=true
kubectl delete serviceaccount -n $NAMESPACE --all --ignore-not-found=true

print_success "Existing resources cleaned up"

echo

# PHASE 2: Clean up Helm release
print_section "PHASE 2: Cleaning up Helm release"

print_info "Uninstalling existing Helm release..."
helm uninstall $APP_NAME -n $NAMESPACE --ignore-not-found=true
print_success "Helm release uninstalled"

echo

# PHASE 3: Wait for cleanup
print_section "PHASE 3: Waiting for cleanup to complete"

print_info "Waiting for resources to be fully deleted..."
sleep 10

# Check if namespace is empty
print_info "Checking if namespace is clean..."
remaining_resources=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$remaining_resources" -eq 0 ]; then
    print_success "Namespace is clean"
else
    print_warning "Some resources still exist, forcing deletion..."
    kubectl delete all -n $NAMESPACE --all --ignore-not-found=true
    kubectl delete networkpolicy,secret,configmap,ingress,hpa,pdb,job,serviceaccount -n $NAMESPACE --all --ignore-not-found=true
fi

echo

# PHASE 4: Deploy with Helm
print_section "PHASE 4: Deploying with Helm"

print_info "Deploying application using Helm to $NAMESPACE namespace..."
helm upgrade --install $APP_NAME helm-chart \
    --namespace $NAMESPACE \
    --create-namespace \
    --set image.repository=$DOCKER_IMAGE \
    --set image.tag=latest \
    --set service.nodePort=$PRODUCTION_PORT \
    --wait \
    --timeout=10m

if [ $? -eq 0 ]; then
    print_success "Application deployed successfully to $NAMESPACE namespace"
else
    print_error "Helm deployment failed"
    exit 1
fi

echo

# PHASE 5: Verify deployment
print_section "PHASE 5: Verifying deployment"

print_info "Checking deployment status..."
kubectl get pods -n $NAMESPACE

print_info "Checking services..."
kubectl get services -n $NAMESPACE

print_info "Checking ingress..."
kubectl get ingress -n $NAMESPACE

print_info "Checking network policies..."
kubectl get networkpolicy -n $NAMESPACE

echo

# PHASE 6: Test endpoints
print_section "PHASE 6: Testing endpoints"

print_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nativeseries -n $NAMESPACE --timeout=300s

print_info "Testing application health..."
# Get the service URL
SERVICE_URL=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -z "$SERVICE_URL" ]; then
    SERVICE_URL=$(kubectl get service $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
fi

if [ -n "$SERVICE_URL" ]; then
    print_info "Service URL: $SERVICE_URL"
    # Test health endpoint
    if curl -s "http://$SERVICE_URL:8000/health" > /dev/null 2>&1; then
        print_success "Application health check passed"
    else
        print_warning "Health check failed, but deployment completed"
    fi
else
    print_warning "Could not determine service URL"
fi

echo

# Final status
print_section "Deployment Summary"

print_success "Helm deployment fix completed successfully!"
print_info "Namespace: $NAMESPACE"
print_info "Application: $APP_NAME"
print_info "Docker Image: $DOCKER_IMAGE"

echo

print_info "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get services -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=nativeseries"
echo "  helm status $APP_NAME -n $NAMESPACE"
echo "  helm list -n $NAMESPACE"

echo

print_success "✅ Helm deployment fix completed!"