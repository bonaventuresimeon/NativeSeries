#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="my-app"
NAMESPACE="my-app"
ARGOCD_NAMESPACE="argocd"
HELM_CHART_PATH="./helm-chart"
ARGOCD_APP_PATH="./argocd"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    if ! command_exists argocd; then
        print_warning "ArgoCD CLI is not installed. Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    fi
    
    print_status "Prerequisites check completed."
}

# Function to check cluster connectivity
check_cluster() {
    print_status "Checking cluster connectivity..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_status "Cluster connectivity verified."
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
    
    print_status "ArgoCD installed successfully."
}

# Function to get ArgoCD admin password
get_argocd_password() {
    print_status "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "ArgoCD admin password: $ARGOCD_PASSWORD"
    print_warning "Please save this password for ArgoCD UI access."
}

# Function to port-forward ArgoCD
port_forward_argocd() {
    print_status "Starting ArgoCD port-forward..."
    print_status "ArgoCD UI will be available at: http://localhost:8080"
    print_status "Username: admin"
    print_status "Password: $ARGOCD_PASSWORD"
    
    kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 &
    ARGOCD_PID=$!
    
    # Wait a moment for port-forward to start
    sleep 3
    
    print_status "ArgoCD port-forward started (PID: $ARGOCD_PID)"
    print_warning "Press Ctrl+C to stop the port-forward when done."
}

# Function to build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Get the current git commit SHA
    IMAGE_TAG=$(git rev-parse --short HEAD)
    IMAGE_NAME="your-registry/$APP_NAME:$IMAGE_TAG"
    
    # Build Docker image
    docker build -t $IMAGE_NAME .
    
    # Push Docker image (uncomment if you have registry access)
    # docker push $IMAGE_NAME
    
    print_status "Docker image built: $IMAGE_NAME"
    print_warning "Please push the image to your registry and update the image tag in values.yaml"
}

# Function to deploy Helm chart
deploy_helm_chart() {
    print_status "Deploying Helm chart..."
    
    # Add Bitnami repository
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Update Helm dependencies
    cd $HELM_CHART_PATH
    helm dependency update
    cd ..
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install/upgrade Helm chart
    helm upgrade --install $APP_NAME $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --create-namespace \
        --wait \
        --timeout 10m
    
    print_status "Helm chart deployed successfully."
}

# Function to deploy ArgoCD application
deploy_argocd_app() {
    print_status "Deploying ArgoCD application..."
    
    # Apply ArgoCD application
    kubectl apply -f $ARGOCD_APP_PATH/application.yaml
    
    # Wait for application to be synced
    print_status "Waiting for ArgoCD application to sync..."
    argocd app sync $APP_NAME --prune
    
    print_status "ArgoCD application deployed successfully."
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo "=================="
    
    echo "Kubernetes Resources:"
    kubectl get all -n $NAMESPACE
    
    echo ""
    echo "ArgoCD Application Status:"
    argocd app get $APP_NAME
    
    echo ""
    echo "Application URLs:"
    kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}'
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    
    check_prerequisites
    check_cluster
    
    # Ask user for deployment type
    echo "Choose deployment type:"
    echo "1. Install ArgoCD and deploy application"
    echo "2. Deploy application only (ArgoCD already installed)"
    echo "3. Build and push Docker image only"
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            install_argocd
            get_argocd_password
            build_and_push_image
            deploy_helm_chart
            deploy_argocd_app
            show_status
            ;;
        2)
            build_and_push_image
            deploy_helm_chart
            deploy_argocd_app
            show_status
            ;;
        3)
            build_and_push_image
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    print_status "Deployment completed successfully!"
}

# Run main function
main "$@"