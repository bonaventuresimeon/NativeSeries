#!/bin/bash

# 🧪 Local Development Setup Script
# Based on Kubernetes + Helm + ArgoCD best practices for local development

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="student-tracker-dev"
NAMESPACE="student-tracker"
ARGOCD_NAMESPACE="argocd"

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

# Function to check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running!"
}

# Function to install kind if not present
install_kind() {
    print_status "Checking kind installation..."
    if ! command -v kind &> /dev/null; then
        print_warning "kind is not installed. Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        print_success "kind installed successfully!"
    else
        print_success "kind is already installed!"
    fi
}

# Function to create local Kubernetes cluster
create_cluster() {
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
}

# Function to install NGINX Ingress Controller
install_ingress_controller() {
    print_status "Installing NGINX Ingress Controller..."
    
    # Install NGINX Ingress Controller
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=5m
    
    print_success "NGINX Ingress Controller installed successfully!"
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n $ARGOCD_NAMESPACE --timeout=5m
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    print_success "ArgoCD installed successfully!"
    print_status "ArgoCD admin password: $ARGOCD_PASSWORD"
    print_status "You can access ArgoCD UI at: http://localhost:30080"
}

# Function to build and load Docker image
build_and_load_image() {
    print_status "Building and loading Docker image..."
    
    # Build the image
    docker build -t student-tracker:latest .
    
    # Load the image into kind cluster
    kind load docker-image student-tracker:latest --name $CLUSTER_NAME
    
    print_success "Docker image built and loaded successfully!"
}

# Function to deploy the application
deploy_application() {
    print_status "Deploying application..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Update values for local development
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
}

# Function to configure local DNS
configure_local_dns() {
    print_status "Configuring local DNS..."
    
    # Get the cluster IP
    CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    # Add entry to /etc/hosts
    if ! grep -q "student-tracker.local" /etc/hosts; then
        echo "$CLUSTER_IP student-tracker.local" | sudo tee -a /etc/hosts
        print_success "Added student-tracker.local to /etc/hosts"
    else
        print_warning "student-tracker.local already exists in /etc/hosts"
    fi
}

# Function to show status
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
    print_success "Local development environment is ready!"
    print_status "Access your application at:"
    print_status "  - Student Tracker: http://student-tracker.local:30011"
    print_status "  - ArgoCD UI: http://localhost:30080"
    print_status "  - ArgoCD admin password: $ARGOCD_PASSWORD"
}

# Function to clean up
cleanup() {
    print_status "Cleaning up local development environment..."
    
    # Delete the kind cluster
    kind delete cluster --name $CLUSTER_NAME
    
    # Remove from /etc/hosts
    sudo sed -i '/student-tracker.local/d' /etc/hosts
    
    # Clean up config file
    rm -f kind-config.yaml
    rm -f helm-chart/values-local.yaml
    
    print_success "Cleanup completed!"
}

# Main function
main() {
    echo "🧪 Setting up local development environment..."
    echo "============================================="
    
    check_docker
    install_kind
    create_cluster
    install_ingress_controller
    install_argocd
    build_and_load_image
    deploy_application
    configure_local_dns
    show_status
    
    echo ""
    print_success "🎉 Local development environment setup completed!"
    print_status "Next steps:"
    print_status "1. Access your application at http://student-tracker.local:30011"
    print_status "2. Access ArgoCD UI at http://localhost:30080"
    print_status "3. Make changes to your code and rebuild: docker build -t student-tracker:latest ."
    print_status "4. Reload the image: kind load docker-image student-tracker:latest --name $CLUSTER_NAME"
    print_status "5. Restart the deployment: kubectl rollout restart deployment/student-tracker -n $NAMESPACE"
    print_status ""
    print_status "To clean up: ./scripts/setup-local-dev.sh cleanup"
}

# Handle cleanup command
if [ "${1:-}" = "cleanup" ]; then
    cleanup
    exit 0
fi

# Run main function
main "$@"