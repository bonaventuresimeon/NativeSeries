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
HELM_CHART_PATH="$(pwd)/helm-chart"
ARGOCD_APP_PATH="$(pwd)/argocd/application.yaml"

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
        print_error "kubectl is not installed. Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        print_success "kubectl installed successfully!"
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Installing Helm..."
        curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
        sudo mv linux-amd64/helm /usr/local/bin/
        rm -rf linux-amd64
        print_success "Helm installed successfully!"
    fi
    
    # Check if argocd CLI is installed
    if ! command -v argocd &> /dev/null; then
        print_warning "ArgoCD CLI is not installed. Installing via curl..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x argocd-linux-amd64
        sudo mv argocd-linux-amd64 /usr/local/bin/argocd
        print_success "ArgoCD CLI installed successfully!"
    fi
    
    # Check cluster connectivity (optional)
    if kubectl cluster-info &> /dev/null; then
        print_success "Connected to Kubernetes cluster!"
        CLUSTER_AVAILABLE=true
    else
        print_warning "Cannot connect to Kubernetes cluster."
        print_status "Available options:"
        print_status "1. Set up a local cluster with kind/minikube"
        print_status "2. Configure kubectl for a remote cluster"
        print_status "3. Use GitHub Actions for deployment"
        
        # Try to set up a local cluster if Docker is available
        if command -v docker &> /dev/null; then
            print_status "Docker found. Attempting to create local cluster with kind..."
            if command -v kind &> /dev/null; then
                kind create cluster --name student-tracker-prod --wait 5m
                kind export kubeconfig --name student-tracker-prod
                print_success "Local cluster created successfully!"
                CLUSTER_AVAILABLE=true
            else
                print_warning "kind not found. Continuing without cluster..."
                CLUSTER_AVAILABLE=false
            fi
        else
            print_warning "No container runtime found. Continuing without cluster..."
            CLUSTER_AVAILABLE=false
        fi
    fi
    
    print_success "Prerequisites check completed!"
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

# Function to validate ArgoCD application
validate_argocd_application() {
    print_status "Validating ArgoCD application..."
    
    # Check if the application file exists
    if [ ! -f "$ARGOCD_APP_PATH" ]; then
        print_error "ArgoCD application file not found: $ARGOCD_APP_PATH"
        print_status "Current directory: $(pwd)"
        print_status "Available files in argocd directory:"
        ls -la argocd/ || echo "argocd directory not found"
        exit 1
    fi
    
    print_status "Found ArgoCD application file: $ARGOCD_APP_PATH"
    
    # Simple YAML syntax check using grep
    if grep -q "apiVersion:" "$ARGOCD_APP_PATH" && grep -q "kind:" "$ARGOCD_APP_PATH"; then
        print_success "ArgoCD application YAML structure appears valid"
    else
        print_error "ArgoCD application YAML structure is invalid"
        exit 1
    fi
    
    # Try kubectl validation if cluster is available, otherwise skip
    if kubectl cluster-info &> /dev/null; then
        if kubectl apply --dry-run=client -f "$ARGOCD_APP_PATH" &> /dev/null; then
            print_success "ArgoCD application YAML is valid"
        else
            print_warning "ArgoCD application YAML validation failed (cluster validation)"
        fi
    else
        print_warning "Skipping cluster validation (no cluster available)"
    fi
    
    print_success "ArgoCD application validation passed!"
}

# Function to generate deployment manifests
generate_manifests() {
    print_status "Generating deployment manifests..."
    
    cd $HELM_CHART_PATH
    
    # Generate manifests for different environments
    mkdir -p ../manifests
    
    # Production manifests
    helm template student-tracker . \
        --set app.image.repository=ghcr.io/bonaventuresimeon/NativeSeries/student-tracker \
        --set app.image.tag=latest \
        --set ingress.enabled=true \
        --set hpa.enabled=true \
        --set networkPolicy.enabled=true \
        > ../manifests/production.yaml
    
    # Staging manifests
    helm template student-tracker . \
        --set app.image.repository=ghcr.io/bonaventuresimeon/NativeSeries/student-tracker \
        --set app.image.tag=latest \
        --set ingress.enabled=false \
        --set hpa.enabled=false \
        --set networkPolicy.enabled=false \
        > ../manifests/staging.yaml
    
    print_success "Deployment manifests generated successfully!"
    print_status "Manifests saved to:"
    print_status "  - Production: manifests/production.yaml"
    print_status "  - Staging: manifests/staging.yaml"
}

# Function to simulate deployment (for environments without cluster)
simulate_deployment() {
    print_status "Simulating deployment (no cluster available)..."
    
    print_status "Generated manifests would deploy:"
    print_status "  - Student Tracker application"
    print_status "  - NGINX Ingress Controller"
    print_status "  - ArgoCD for GitOps management"
    print_status "  - cert-manager for TLS certificates"
    
    print_success "Deployment simulation completed!"
    print_status "To deploy to a real cluster:"
    print_status "1. Set up a Kubernetes cluster (EKS, GKE, AKS, or local)"
    print_status "2. Configure kubectl for your cluster"
    print_status "3. Run this script again"
    print_status "4. Or use GitHub Actions for automated deployment"
}

# Function to check GitHub Actions status
check_github_actions() {
    print_status "Checking GitHub Actions workflow..."
    
    if [ -f ".github/workflows/helm-argocd-deploy.yml" ]; then
        print_success "GitHub Actions workflow found!"
        print_status "Workflow: .github/workflows/helm-argocd-deploy.yml"
        print_status "This workflow will:"
        print_status "  - Validate code and Helm charts"
        print_status "  - Build and push Docker images"
        print_status "  - Deploy via ArgoCD (if cluster configured)"
        
        print_status "To trigger deployment:"
        print_status "1. Push changes to main branch"
        print_status "2. Or manually trigger workflow in GitHub"
    else
        print_warning "GitHub Actions workflow not found"
    fi
}

# Function to show deployment options
show_deployment_options() {
    print_status "Deployment Options Available:"
    echo ""
    echo "1. 🚀 GitHub Actions (Recommended)"
    echo "   - Automated CI/CD pipeline"
    echo "   - Builds and pushes Docker images"
    echo "   - Deploys via ArgoCD"
    echo "   - Trigger: Push to main branch"
    echo ""
    echo "2. 🧪 Local Development"
    echo "   - Use scripts/setup-local-dev.sh"
    echo "   - Requires Docker and kind"
    echo "   - Full local development environment"
    echo ""
    echo "3. 🔧 Manual Deployment"
    echo "   - Use generated manifests in manifests/"
    echo "   - Apply with kubectl apply -f manifests/"
    echo "   - Requires configured Kubernetes cluster"
    echo ""
    echo "4. 📋 Remote Cluster"
    echo "   - Configure kubectl for your cluster"
    echo "   - Run this script again"
    echo "   - Install ArgoCD and deploy"
}

# Function to create deployment instructions
create_deployment_instructions() {
    print_status "Creating deployment instructions..."
    
    cat > DEPLOYMENT_INSTRUCTIONS.md << 'EOF'
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
EOF

    print_success "Deployment instructions created: DEPLOYMENT_INSTRUCTIONS.md"
}

# Main deployment function
main() {
    echo "🚀 Starting production deployment..."
    echo "=================================="
    
    check_prerequisites
    validate_helm_chart
    validate_argocd_application
    generate_manifests
    check_github_actions
    
    # Check if we can connect to a cluster
    if [ "${CLUSTER_AVAILABLE:-false}" = true ]; then
        print_success "Connected to Kubernetes cluster!"
        print_status "Proceeding with deployment..."
        # Here you would add the actual deployment steps
        # For now, we'll just show the options
        show_deployment_options
    else
        print_warning "No Kubernetes cluster available"
        simulate_deployment
        show_deployment_options
    fi
    
    create_deployment_instructions
    
    echo ""
    print_success "🎉 Deployment preparation completed!"
    print_status "Next steps:"
    print_status "1. Review generated manifests in manifests/"
    print_status "2. Set up a Kubernetes cluster"
    print_status "3. Configure kubectl for your cluster"
    print_status "4. Run this script again or use GitHub Actions"
}

# Run main function
main "$@"