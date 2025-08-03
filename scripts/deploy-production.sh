#!/bin/bash

# 🚀 Production Deployment Script for Student Tracker
# Based on Kubernetes + Helm + ArgoCD + Ingress best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="student-tracker"
ARGOCD_NAMESPACE="argocd"
HELM_CHART_PATH="./helm-chart"
ARGOCD_APP_PATH="./argocd/application.yaml"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm 3 first."
        exit 1
    fi
    
    # Check if argocd CLI is installed
    if ! command -v argocd &> /dev/null; then
        print_warning "ArgoCD CLI is not installed. Installing via curl..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied!"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Add ArgoCD Helm repository
    helm repo add argo-cd https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD
    helm install argocd argo-cd/argo-cd \
        --namespace $ARGOCD_NAMESPACE \
        --set server.service.type=LoadBalancer \
        --set server.ingress.enabled=false \
        --set controller.resources.requests.memory=256Mi \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.limits.memory=512Mi \
        --set controller.resources.limits.cpu=200m \
        --wait --timeout=10m
    
    print_success "ArgoCD installed successfully!"
}

# Function to install NGINX Ingress Controller
install_ingress_controller() {
    print_status "Installing NGINX Ingress Controller..."
    
    # Add NGINX Ingress Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX Ingress Controller
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.resources.requests.memory=256Mi \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.limits.memory=512Mi \
        --set controller.resources.limits.cpu=200m \
        --wait --timeout=10m
    
    print_success "NGINX Ingress Controller installed successfully!"
}

# Function to install cert-manager for TLS
install_cert_manager() {
    print_status "Installing cert-manager for TLS certificates..."
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=5m
    
    # Create ClusterIssuer for Let's Encrypt
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    print_success "cert-manager installed successfully!"
}

# Function to validate Helm chart
validate_helm_chart() {
    print_status "Validating Helm chart..."
    
    cd $HELM_CHART_PATH
    
    # Lint the chart
    helm lint .
    
    # Template the chart to check for errors
    helm template student-tracker . --debug
    
    print_success "Helm chart validation passed!"
}

# Function to deploy the application via ArgoCD
deploy_application() {
    print_status "Deploying application via ArgoCD..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply ArgoCD application
    kubectl apply -f $ARGOCD_APP_PATH
    
    # Wait for ArgoCD application to be created
    kubectl wait --for=condition=established crd/applications.argoproj.io --timeout=30s
    
    # Sync the application
    argocd app sync student-tracker --prune --force
    
    print_success "Application deployed successfully!"
}

# Function to configure DNS (example for AWS Route 53)
configure_dns() {
    print_status "Configuring DNS (example for AWS Route 53)..."
    
    # Get the LoadBalancer IP
    LB_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$LB_IP" ]; then
        print_status "LoadBalancer IP: $LB_IP"
        print_status "Please create a DNS A record pointing your domain to: $LB_IP"
        print_status "Example AWS CLI command:"
        echo "aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID --change-batch '{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"student-tracker.yourdomain.com\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$LB_IP\"}]}]}'"
    else
        print_warning "LoadBalancer IP not available yet. Please check later."
    fi
}

# Function to show deployment status
show_status() {
    print_status "Checking deployment status..."
    
    echo ""
    echo "📊 Application Status:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "🌐 Services:"
    kubectl get services -n $NAMESPACE
    
    echo ""
    echo "🔗 Ingress:"
    kubectl get ingress -n $NAMESPACE
    
    echo ""
    echo "📈 ArgoCD Application Status:"
    argocd app get student-tracker
    
    echo ""
    print_success "Deployment completed! Your application should be available at:"
    print_success "http://student-tracker.yourdomain.com (after DNS configuration)"
}

# Main deployment function
main() {
    echo "🚀 Starting production deployment..."
    echo "=================================="
    
    check_prerequisites
    install_argocd
    install_ingress_controller
    install_cert_manager
    validate_helm_chart
    deploy_application
    configure_dns
    show_status
    
    echo ""
    print_success "🎉 Production deployment completed successfully!"
    print_status "Next steps:"
    print_status "1. Configure your DNS to point to the LoadBalancer IP"
    print_status "2. Update the domain in helm-chart/values.yaml"
    print_status "3. Monitor the application via ArgoCD UI"
    print_status "4. Set up monitoring and alerting"
}

# Run main function
main "$@"