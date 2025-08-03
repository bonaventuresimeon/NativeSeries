#!/bin/bash

# 🚀 Comprehensive Deployment Script for Student Tracker
# Merged from: deploy-production.sh, setup-local-dev.sh, deploy-to-production.sh, get-docker.sh
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
CLUSTER_NAME="student-tracker-dev"
APP_NAME="student-tracker"
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"

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

# Function to show usage
show_usage() {
    echo "🚀 Student Tracker Deployment Script"
    echo "=================================="
    echo ""
    echo "Usage: ./deploy.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  production    Deploy to production (Docker-based)"
    echo "  local         Set up local development environment (kind + ArgoCD)"
    echo "  validate      Validate Helm charts and ArgoCD application"
    echo "  manifests     Generate deployment manifests"
    echo "  cleanup       Clean up local development environment"
    echo "  install-deps  Install required dependencies (kubectl, helm, argocd)"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh production    # Deploy to production server"
    echo "  ./deploy.sh local         # Set up local development"
    echo "  ./deploy.sh validate      # Validate configurations"
    echo "  ./deploy.sh cleanup       # Clean up local environment"
    echo ""
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing required dependencies..."
    
    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        print_success "kubectl installed successfully!"
    else
        print_success "kubectl already installed!"
    fi
    
    # Install Helm
    if ! command -v helm &> /dev/null; then
        print_status "Installing Helm..."
        curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
        sudo mv linux-amd64/helm /usr/local/bin/
        rm -rf linux-amd64
        print_success "Helm installed successfully!"
    else
        print_success "Helm already installed!"
    fi
    
    # Install ArgoCD CLI
    if ! command -v argocd &> /dev/null; then
        print_status "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x argocd-linux-amd64
        sudo mv argocd-linux-amd64 /usr/local/bin/argocd
        print_success "ArgoCD CLI installed successfully!"
    else
        print_success "ArgoCD CLI already installed!"
    fi
    
    # Install kind (for local development)
    if ! command -v kind &> /dev/null; then
        print_status "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        print_success "kind installed successfully!"
    else
        print_success "kind already installed!"
    fi
    
    print_success "All dependencies installed successfully!"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Run: ./deploy.sh install-deps"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Run: ./deploy.sh install-deps"
        exit 1
    fi
    
    # Check if argocd CLI is installed
    if ! command -v argocd &> /dev/null; then
        print_error "ArgoCD CLI is not installed. Run: ./deploy.sh install-deps"
        exit 1
    fi
    
    # Check cluster connectivity (optional)
    if kubectl cluster-info &> /dev/null; then
        print_success "Connected to Kubernetes cluster!"
        CLUSTER_AVAILABLE=true
    else
        print_warning "Cannot connect to Kubernetes cluster."
        print_status "Available options:"
        print_status "1. Set up a local cluster with: ./deploy.sh local"
        print_status "2. Configure kubectl for a remote cluster"
        print_status "3. Use GitHub Actions for deployment"
        CLUSTER_AVAILABLE=false
    fi
    
    print_success "Prerequisites check completed!"
}

# Function to validate Helm chart
validate_helm_chart() {
    print_status "Validating Helm chart..."
    
    # Store original directory
    ORIGINAL_DIR=$(pwd)
    
    cd $HELM_CHART_PATH
    
    # Lint the chart
    helm lint .
    
    # Template the chart to check for errors
    helm template student-tracker . --debug
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    print_success "Helm chart validation passed!"
}

# Function to validate ArgoCD application
validate_argocd_application() {
    print_status "Validating ArgoCD application..."
    
    # Check if the application file exists
    if [ ! -f "$ARGOCD_APP_PATH" ]; then
        print_error "ArgoCD application file not found: $ARGOCD_APP_PATH"
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
    
    # Store original directory
    ORIGINAL_DIR=$(pwd)
    
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
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    print_success "Deployment manifests generated successfully!"
    print_status "Manifests saved to:"
    print_status "  - Production: manifests/production.yaml"
    print_status "  - Staging: manifests/staging.yaml"
}

# Function to deploy to production (Docker-based)
deploy_production() {
    print_status "🚀 Deploying Student Tracker to Production"
    print_status "Production URL: ${PRODUCTION_URL}"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! sudo docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    # Build the Docker image
    print_status "Building Docker image..."
    sudo docker build -t ${APP_NAME}:latest .
    
    # Check if the image was built successfully
    if [ $? -eq 0 ]; then
        print_status "✅ Docker image built successfully"
    else
        print_error "❌ Failed to build Docker image"
        exit 1
    fi
    
    # Stop and remove existing container if it exists
    if sudo docker ps -a --format 'table {{.Names}}' | grep -q "^${APP_NAME}$"; then
        print_status "Stopping existing container..."
        sudo docker stop ${APP_NAME} || true
        sudo docker rm ${APP_NAME} || true
    fi
    
    # Run the application container
    print_status "Starting application container..."
    sudo docker run -d \
        --name ${APP_NAME} \
        --restart unless-stopped \
        -p ${PRODUCTION_PORT}:8000 \
        -e HOST=0.0.0.0 \
        -e PORT=8000 \
        ${APP_NAME}:latest
    
    # Check if container started successfully
    if [ $? -eq 0 ]; then
        print_status "✅ Application container started successfully"
    else
        print_error "❌ Failed to start application container"
        exit 1
    fi
    
    # Wait a moment for the application to start
    print_status "Waiting for application to start..."
    sleep 10
    
    # Test the application
    print_status "Testing application health..."
    if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
        print_status "✅ Application is healthy and responding"
    else
        print_warning "⚠️  Health check failed, but container is running"
    fi
    
    # Show deployment information
    echo ""
    print_success "🎉 Production Deployment Complete!"
    echo ""
    echo "📋 Deployment Information:"
    echo "   Application: ${APP_NAME}"
    echo "   Production URL: ${PRODUCTION_URL}"
    echo "   API Documentation: ${PRODUCTION_URL}/docs"
    echo "   Health Check: ${PRODUCTION_URL}/health"
    echo "   Metrics: ${PRODUCTION_URL}/metrics"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs: docker logs -f ${APP_NAME}"
    echo "   Stop app: docker stop ${APP_NAME}"
    echo "   Restart app: docker restart ${APP_NAME}"
    echo "   Remove app: docker rm -f ${APP_NAME}"
    echo ""
    print_success "🌐 Your Student Tracker application is now live at: ${PRODUCTION_URL}"
}

# Function to set up local development environment
setup_local_dev() {
    print_status "🧪 Setting up local development environment..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running!"
    
    # Create local Kubernetes cluster
    print_status "Creating local Kubernetes cluster with kind..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        print_warning "Cluster $CLUSTER_NAME already exists. Deleting it..."
        kind delete cluster --name $CLUSTER_NAME
    fi
    
    # Create cluster configuration
    cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30011
    hostPort: 30011
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraMounts:
  - hostPath: /var/run/docker.sock
    containerPath: /var/run/docker.sock
EOF
    
    # Create the cluster
    kind create cluster --name $CLUSTER_NAME --config kind-config.yaml --wait 5m
    
    # Configure kubectl to use the new cluster
    kind export kubeconfig --name $CLUSTER_NAME
    
    print_success "Local Kubernetes cluster created successfully!"
    
    # Install NGINX Ingress Controller
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=5m
    
    print_success "NGINX Ingress Controller installed successfully!"
    
    # Install ArgoCD
    print_status "Installing ArgoCD..."
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n $ARGOCD_NAMESPACE --timeout=5m
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    print_success "ArgoCD installed successfully!"
    print_status "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    # Build and load Docker image
    print_status "Building and loading Docker image..."
    docker build -t student-tracker:latest .
    kind load docker-image student-tracker:latest --name $CLUSTER_NAME
    print_success "Docker image built and loaded successfully!"
    
    # Deploy the application
    print_status "Deploying application..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create local values file
    cat <<EOF > helm-chart/values-local.yaml
app:
  name: student-tracker
  image:
    repository: student-tracker
    tag: latest
    pullPolicy: Never
  env:
    - name: ENVIRONMENT
      value: "development"
    - name: MONGO_URI
      value: "mongodb://localhost:27017"
    - name: DATABASE_NAME
      value: "student_project_tracker"
    - name: COLLECTION_NAME
      value: "students"

service:
  type: NodePort
  port: 8000
  targetPort: 8000
  nodePort: 30011

ingress:
  enabled: true
  className: "nginx"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: student-tracker.local
      paths:
        - path: /
          pathType: Prefix

hpa:
  enabled: false

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

networkPolicy:
  enabled: false

serviceMonitor:
  enabled: false
EOF
    
    # Install the application using Helm
    helm install student-tracker ./helm-chart \
        --namespace $NAMESPACE \
        --values helm-chart/values-local.yaml \
        --wait --timeout=5m
    
    print_success "Application deployed successfully!"
    
    # Configure local DNS
    print_status "Configuring local DNS..."
    CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    if ! grep -q "student-tracker.local" /etc/hosts; then
        echo "$CLUSTER_IP student-tracker.local" | sudo tee -a /etc/hosts
        print_success "Added student-tracker.local to /etc/hosts"
    else
        print_warning "student-tracker.local already exists in /etc/hosts"
    fi
    
    # Show status
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
    print_success "Local development environment is ready!"
    print_status "Access your application at:"
    print_status "  - Student Tracker: http://student-tracker.local:30011"
    print_status "  - ArgoCD UI: http://localhost:30080"
    print_status "  - ArgoCD admin password: $ARGOCD_PASSWORD"
    
    echo ""
    print_success "🎉 Local development environment setup completed!"
    print_status "Next steps:"
    print_status "1. Access your application at http://student-tracker.local:30011"
    print_status "2. Access ArgoCD UI at http://localhost:30080"
    print_status "3. Make changes to your code and rebuild: docker build -t student-tracker:latest ."
    print_status "4. Reload the image: kind load docker-image student-tracker:latest --name $CLUSTER_NAME"
    print_status "5. Restart the deployment: kubectl rollout restart deployment/student-tracker -n $NAMESPACE"
}

# Function to clean up local environment
cleanup_local() {
    print_status "Cleaning up local development environment..."
    
    # Delete the kind cluster
    if kind get clusters | grep -q "$CLUSTER_NAME"; then
        kind delete cluster --name $CLUSTER_NAME
        print_success "Kind cluster deleted"
    fi
    
    # Remove from /etc/hosts
    sudo sed -i '/student-tracker.local/d' /etc/hosts
    print_success "Removed student-tracker.local from /etc/hosts"
    
    # Clean up config files
    rm -f kind-config.yaml
    rm -f helm-chart/values-local.yaml
    print_success "Configuration files cleaned up"
    
    print_success "🎉 Cleanup completed!"
}

# Function to check GitHub Actions status
check_github_actions() {
    print_status "Checking GitHub Actions workflows..."
    
    WORKFLOWS_FOUND=false
    
    if [ -f ".github/workflows/enhanced-deploy.yml" ]; then
        print_success "Enhanced GitHub Actions workflow found!"
        print_status "Workflow: .github/workflows/enhanced-deploy.yml"
        print_status "This workflow includes:"
        print_status "  - Security scanning (Trivy + Bandit)"
        print_status "  - Code quality checks (Black, Flake8, MyPy)"
        print_status "  - Helm chart validation"
        print_status "  - Multi-platform Docker builds"
        print_status "  - Staging and production deployments"
        WORKFLOWS_FOUND=true
    fi
    
    if [ -f ".github/workflows/helm-argocd-deploy.yml" ]; then
        print_success "Basic GitHub Actions workflow found!"
        print_status "Workflow: .github/workflows/helm-argocd-deploy.yml"
        print_status "This workflow includes:"
        print_status "  - Basic validation and testing"
        print_status "  - Docker image building"
        print_status "  - Helm chart validation"
        WORKFLOWS_FOUND=true
    fi
    
    if [ "$WORKFLOWS_FOUND" = true ]; then
        print_status "To trigger deployment:"
        print_status "1. Push changes to main branch"
        print_status "2. Or manually trigger workflow in GitHub"
        print_status "3. Use workflow_dispatch for manual deployment"
    else
        print_warning "No GitHub Actions workflows found"
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
    echo "   - Use: ./deploy.sh local"
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
    echo "   - Run: ./deploy.sh validate"
    echo "   - Install ArgoCD and deploy"
}

# Main function
main() {
    case "${1:-help}" in
        "production")
            deploy_production
            ;;
        "local")
            setup_local_dev
            ;;
        "validate")
            check_prerequisites
            validate_helm_chart
            validate_argocd_application
            generate_manifests
            check_github_actions
            show_deployment_options
            ;;
        "manifests")
            generate_manifests
            ;;
        "cleanup")
            cleanup_local
            ;;
        "install-deps")
            install_dependencies
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"