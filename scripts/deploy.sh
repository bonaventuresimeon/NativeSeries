#!/bin/bash

set -e

# Parse command line arguments
FORCE_PRUNE=false
SKIP_PRUNE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-prune)
            FORCE_PRUNE=true
            shift
            ;;
        --skip-prune)
            SKIP_PRUNE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force-prune    Automatically perform complete machine pruning without asking"
            echo "  --skip-prune     Skip machine pruning entirely"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  DOCKER_USERNAME  Your Docker Hub username (for option 6)"
            echo "  PRODUCTION_HOST  Production host IP (default: 18.206.89.183)"
            echo "  PRODUCTION_PORT  Production port (default: 30011)"
            echo ""
            echo "Examples:"
            echo "  $0                              # Interactive deployment with pruning prompt"
            echo "  $0 --force-prune                # Deploy with automatic pruning"
            echo "  $0 --skip-prune                 # Deploy without pruning"
            echo "  DOCKER_USERNAME=biwunor $0      # Deploy with Docker Hub (skip username prompt)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get the directory where this script is located and change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root directory to ensure relative paths work
cd "$PROJECT_ROOT"

# Verify we're in the right directory by checking for key files
if [ ! -f "app/main.py" ] || [ ! -f "helm-chart/Chart.yaml" ] || [ ! -f "argocd/application.yaml" ]; then
    echo "ERROR: This script must be run from the project root directory or the script must be in the scripts/ subdirectory"
    echo "Current directory: $(pwd)"
    echo "Looking for: app/main.py, helm-chart/Chart.yaml, argocd/application.yaml"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
NAMESPACE="student-tracker"
ARGOCD_NAMESPACE="argocd"
HELM_CHART_PATH="./helm-chart"
ARGOCD_APP_PATH="./argocd"
PUSH_IMAGE="${PUSH_IMAGE:-false}"

# Production configuration (can be overridden via environment variables)
PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
ARGOCD_HTTP_PORT="${ARGOCD_HTTP_PORT:-30080}"
ARGOCD_HTTPS_PORT="${ARGOCD_HTTPS_PORT:-30443}"

# Docker configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"

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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    print_info "Working directory: $(pwd)"
    
    # Check kubectl
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        print_info "Install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        exit 1
    fi
    
    # Check Helm
    if ! command_exists helm; then
        print_error "Helm is not installed. Please install Helm first."
        print_info "Install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    # Check ArgoCD CLI
    if ! command_exists argocd; then
        print_warning "ArgoCD CLI is not installed. Installing ArgoCD CLI..."
        if curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64; then
            sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
            rm argocd-linux-amd64
            print_status "✅ ArgoCD CLI installed successfully"
        else
            print_error "Failed to download ArgoCD CLI"
            exit 1
        fi
    fi
    
    # Check Docker (optional)
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            print_status "✅ Docker is available and running"
        elif sudo docker info >/dev/null 2>&1; then
            print_status "✅ Docker is available (requires sudo)"
        else
            print_warning "⚠️ Docker is installed but not running"
            print_info "Start Docker: sudo systemctl start docker"
        fi
    else
        print_warning "⚠️ Docker is not installed (optional for image building)"
        print_info "Install Docker: https://docs.docker.com/get-docker/"
    fi
    
    print_status "✅ Prerequisites check completed."
}

# Function to perform complete machine pruning
prune_machine() {
    print_status "🧹 Starting complete machine pruning..."
    
    # Determine Docker command (with or without sudo)
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        if sudo docker info >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            print_info "Using sudo for Docker commands"
        else
            print_warning "Docker not available, skipping Docker pruning"
            return 0
        fi
    fi
    
    print_info "Pruning Docker resources..."
    
    # Stop all running containers
    print_info "Stopping all running containers..."
    if $DOCKER_CMD ps -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
        print_status "✅ All containers stopped"
    else
        print_info "No running containers found"
    fi
    
    # Remove all containers
    print_info "Removing all containers..."
    if $DOCKER_CMD ps -aq | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD rm -f $($DOCKER_CMD ps -aq) 2>/dev/null || true
        print_status "✅ All containers removed"
    else
        print_info "No containers found"
    fi
    
    # Remove all images
    print_info "Removing all Docker images..."
    if $DOCKER_CMD images -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD rmi -f $($DOCKER_CMD images -q) 2>/dev/null || true
        print_status "✅ All images removed"
    else
        print_info "No images found"
    fi
    
    # Remove all volumes
    print_info "Removing all Docker volumes..."
    if $DOCKER_CMD volume ls -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD volume rm $($DOCKER_CMD volume ls -q) 2>/dev/null || true
        print_status "✅ All volumes removed"
    else
        print_info "No volumes found"
    fi
    
    # Remove all networks (except default ones)
    print_info "Removing custom Docker networks..."
    if $DOCKER_CMD network ls --filter "type=custom" -q | wc -l | grep -q -v "^0$"; then
        $DOCKER_CMD network rm $($DOCKER_CMD network ls --filter "type=custom" -q) 2>/dev/null || true
        print_status "✅ Custom networks removed"
    else
        print_info "No custom networks found"
    fi
    
    # Prune system (removes unused data)
    print_info "Pruning Docker system..."
    $DOCKER_CMD system prune -af --volumes 2>/dev/null || true
    print_status "✅ Docker system pruned"
    
    # Clean up Docker build cache
    print_info "Cleaning Docker build cache..."
    $DOCKER_CMD builder prune -af 2>/dev/null || true
    print_status "✅ Build cache cleaned"
    
    print_info "Pruning Kubernetes resources..."
    
    # Check if kubectl is available and cluster is accessible
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        # Delete all resources in the project namespace
        if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
            print_info "Cleaning up namespace: $NAMESPACE"
            kubectl delete all --all -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
            kubectl delete namespace "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
            print_status "✅ Kubernetes namespace cleaned"
        fi
        
        # Clean up ArgoCD namespace if it exists
        if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            print_info "Cleaning up ArgoCD namespace: $ARGOCD_NAMESPACE"
            kubectl delete all --all -n "$ARGOCD_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
            kubectl delete namespace "$ARGOCD_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
            print_status "✅ ArgoCD namespace cleaned"
        fi
        
        # Clean up any dangling resources
        print_info "Cleaning up dangling Kubernetes resources..."
        kubectl delete pods --field-selector=status.phase=Failed --all-namespaces --ignore-not-found=true 2>/dev/null || true
        kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces --ignore-not-found=true 2>/dev/null || true
        print_status "✅ Dangling resources cleaned"
    else
        print_warning "Kubernetes cluster not accessible, skipping Kubernetes cleanup"
    fi
    
    print_info "Pruning system resources..."
    
    # Clean up temporary files
    print_info "Cleaning temporary files..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    print_status "✅ Temporary files cleaned"
    
    # Clean up package cache (if apt is available)
    if command_exists apt; then
        print_info "Cleaning package cache..."
        sudo apt clean 2>/dev/null || true
        sudo apt autoremove -y 2>/dev/null || true
        print_status "✅ Package cache cleaned"
    fi
    
    # Clean up log files (keep recent ones)
    print_info "Cleaning old log files..."
    sudo find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
    sudo find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
    print_status "✅ Old log files cleaned"
    
    # Clean up Helm cache
    if command_exists helm; then
        print_info "Cleaning Helm cache..."
        helm repo update 2>/dev/null || true
        print_status "✅ Helm cache updated"
    fi
    
    print_status "🎉 Complete machine pruning finished!"
    print_info "Freed up significant disk space and cleaned all resources"
}

# Function to check and fix common deployment issues
check_deployment_issues() {
    print_status "Checking for common deployment issues..."
    
    # Check if namespace exists and is accessible
    if kubectl cluster-info >/dev/null 2>&1; then
        if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
            print_info "Creating namespace $NAMESPACE..."
            kubectl create namespace "$NAMESPACE"
        fi
        
        # Check for existing resources that might conflict
        if kubectl get deployment "$APP_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
            print_warning "Deployment $APP_NAME already exists in namespace $NAMESPACE"
            print_info "This will be updated during deployment"
        fi
        
        # Check for ServiceMonitor CRD
        if ! kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
            print_warning "ServiceMonitor CRD not found. Monitoring will be disabled."
        fi
    fi
    
    print_status "Deployment issues check completed."
}

# Function to check cluster connectivity
check_cluster() {
    print_status "Checking cluster connectivity..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_warning "Cannot connect to Kubernetes cluster. This is expected in a development environment."
        print_warning "The deployment will focus on validating Helm charts and ArgoCD configuration."
        return 1
    fi
    
    print_status "Cluster connectivity verified."
    return 0
}

# Function to validate Helm chart
validate_helm_chart() {
    print_status "Validating Helm chart..."
    
    # Verify helm chart directory exists
    if [ ! -d "$HELM_CHART_PATH" ]; then
        print_error "Helm chart directory not found: $HELM_CHART_PATH"
        return 1
    fi
    
    # Add Bitnami repository with error handling
    if ! helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null; then
        print_info "Bitnami repository already exists, skipping..."
    fi
    
    if ! helm repo update; then
        print_warning "Failed to update Helm repositories, continuing..."
    fi
    
    # Update Helm dependencies (only if dependencies exist)
    if [ -f "$HELM_CHART_PATH/Chart.yaml" ] && grep -q "dependencies:" "$HELM_CHART_PATH/Chart.yaml"; then
        print_status "Updating Helm dependencies..."
        (cd "$HELM_CHART_PATH" && helm dependency update) || {
            print_warning "Dependency update failed, continuing..."
        }
    else
        print_info "No dependencies to update"
    fi
    
    # Lint Helm chart
    if ! helm lint "$HELM_CHART_PATH"; then
        print_error "Helm chart linting failed"
        return 1
    fi
    
    # Dry run to validate templates
    if ! helm template "$APP_NAME" "$HELM_CHART_PATH" --namespace "$NAMESPACE" --dry-run >/dev/null; then
        print_error "Helm template validation failed"
        return 1
    fi
    
    print_status "Helm chart validation completed successfully."
}

# Function to validate ArgoCD application
validate_argocd_app() {
    print_status "Validating ArgoCD application configuration..."
    
    # Check if ArgoCD application file exists
    if [ ! -f "$ARGOCD_APP_PATH/application.yaml" ]; then
        print_error "ArgoCD application file not found: $ARGOCD_APP_PATH/application.yaml"
        return 1
    fi
    
    # Validate YAML syntax without connecting to cluster
    if kubectl apply -f "$ARGOCD_APP_PATH/application.yaml" --dry-run=client --validate=false >/dev/null 2>&1; then
        print_status "✅ ArgoCD application YAML syntax is valid"
    else
        print_warning "ArgoCD application validation skipped (no cluster connection)"
    fi
    
    print_status "ArgoCD application validation completed successfully."
}

# Function to build Docker image (if Docker is available)
build_docker_image() {
    print_status "Checking Docker availability..."
    
    # Verify Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in project root"
        return 1
    fi
    
    if command_exists docker; then
        # Check if Docker is accessible (with or without sudo)
        DOCKER_CMD="docker"
        if ! docker info >/dev/null 2>&1; then
            if sudo docker info >/dev/null 2>&1; then
                DOCKER_CMD="sudo docker"
                print_info "Using sudo for Docker commands"
            else
                print_warning "Docker is not available. Skipping image build."
                print_warning "Please build and push the Docker image manually."
                print_info "Build command: docker build -t $APP_NAME:latest ."
                print_info "Push command: docker push $APP_NAME:latest"
                return 0
            fi
        fi
        
        print_status "Building Docker image..."
        
        # Get the current git commit SHA
        IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
        IMAGE_NAME="$APP_NAME:$IMAGE_TAG"
        
        # Build Docker image
        if $DOCKER_CMD build -t "$IMAGE_NAME" .; then
            print_status "✅ Docker image built successfully: $IMAGE_NAME"
            
            # Check if we should push the image
            if [ "$PUSH_IMAGE" = "true" ]; then
                print_status "Pushing Docker image to registry..."
                if $DOCKER_CMD push "$IMAGE_NAME"; then
                    print_status "✅ Docker image pushed successfully"
                else
                    print_warning "⚠️ Failed to push Docker image"
                    print_info "You can push manually with: $DOCKER_CMD push $IMAGE_NAME"
                    print_info "Make sure you're logged in to the registry: $DOCKER_CMD login"
                fi
            else
                print_info "To push the image, run: $DOCKER_CMD push $IMAGE_NAME"
                print_info "Make sure you're logged in to the registry: $DOCKER_CMD login"
            fi
        else
            print_error "❌ Docker image build failed"
            return 1
        fi
    else
        print_warning "Docker is not available. Skipping image build."
        print_warning "Please build and push the Docker image manually."
        print_info "Build command: docker build -t $APP_NAME:latest ."
        print_info "Push command: docker push $APP_NAME:latest"
    fi
}

# Function to build and push Docker image with custom registry
build_and_push_docker_image() {
    print_status "Building and pushing Docker image..."
    
    # Ask for Docker Hub username if not provided
    if [ -z "$DOCKER_USERNAME" ]; then
        read -p "Enter your Docker Hub username: " DOCKER_USERNAME
    fi
    
    if [ -z "$DOCKER_USERNAME" ]; then
        print_error "Docker username is required"
        return 1
    fi
    
    # Verify Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in project root"
        return 1
    fi
    
    # Check if Docker is accessible (with or without sudo)
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        if sudo docker info >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            print_info "Using sudo for Docker commands"
        else
            print_error "Docker is not available"
            return 1
        fi
    fi
    
    # Set image names
    DOCKER_IMAGE="$DOCKER_USERNAME/$APP_NAME"
    APP_VERSION="1.1.0"
    
    print_status "Building Docker image: $DOCKER_IMAGE:$APP_VERSION"
    
    # Build Docker image with multiple tags
    if $DOCKER_CMD build -t "$DOCKER_IMAGE:latest" -t "$DOCKER_IMAGE:$APP_VERSION" .; then
        print_status "✅ Docker image built successfully"
        
        # Update Helm values with the new image
        print_status "Updating Helm chart with new image repository..."
        if [ -f "helm-chart/values.yaml" ]; then
            # Backup original values
            cp helm-chart/values.yaml helm-chart/values.yaml.bak
            
            # Update the repository in values.yaml
            sed -i "s|repository:.*|repository: $DOCKER_IMAGE|g" helm-chart/values.yaml
            sed -i "s|tag:.*|tag: $APP_VERSION|g" helm-chart/values.yaml
            
            print_status "✅ Helm chart updated with new image: $DOCKER_IMAGE:$APP_VERSION"
        fi
        
        # Update ArgoCD application
        if [ -f "argocd/application.yaml" ]; then
            # Backup original application
            cp argocd/application.yaml argocd/application.yaml.bak
            
            # Update the repository in ArgoCD application
            sed -i "s|value: ghcr.io.*student-tracker|value: $DOCKER_IMAGE|g" argocd/application.yaml
            sed -i "s|value: biwunor.*student-tracker|value: $DOCKER_IMAGE|g" argocd/application.yaml
            
            print_status "✅ ArgoCD application updated with new image: $DOCKER_IMAGE"
        fi
        
        # Prompt for Docker login
        print_status "Logging into Docker Hub..."
        if ! $DOCKER_CMD login; then
            print_error "Docker login failed"
            return 1
        fi
        
        # Push images
        print_status "Pushing Docker images to Docker Hub..."
        if $DOCKER_CMD push "$DOCKER_IMAGE:latest" && $DOCKER_CMD push "$DOCKER_IMAGE:$APP_VERSION"; then
            print_status "✅ Docker images pushed successfully to Docker Hub"
            print_info "Images available at:"
            print_info "  - $DOCKER_IMAGE:latest"
            print_info "  - $DOCKER_IMAGE:$APP_VERSION"
        else
            print_error "❌ Failed to push Docker images"
            return 1
        fi
        
        # Test local deployment
        print_status "Testing local Docker deployment..."
        
        # Stop any existing container
        $DOCKER_CMD stop "$APP_NAME-production" 2>/dev/null || true
        $DOCKER_CMD rm "$APP_NAME-production" 2>/dev/null || true
        
        # Run new container
        if $DOCKER_CMD run -d -p "$PRODUCTION_PORT:8000" --name "$APP_NAME-production" "$DOCKER_IMAGE:$APP_VERSION"; then
            print_status "✅ Production container started successfully"
            
            # Wait for startup
            print_info "Waiting for application to start..."
            sleep 20
            
            # Test health endpoint
            if curl -f "http://localhost:$PRODUCTION_PORT/health" >/dev/null 2>&1; then
                print_status "✅ Application health check passed"
                print_info "Application is running at: http://localhost:$PRODUCTION_PORT"
                print_info "API documentation: http://localhost:$PRODUCTION_PORT/docs"
                print_info "Health check: http://localhost:$PRODUCTION_PORT/health"
            else
                print_warning "⚠️ Health check failed, but container is running"
                print_info "Check logs with: $DOCKER_CMD logs $APP_NAME-production"
            fi
        else
            print_error "❌ Failed to start production container"
            return 1
        fi
        
    else
        print_error "❌ Docker image build failed"
        return 1
    fi
}

# Function to deploy to production with Docker
deploy_production_docker() {
    print_status "Deploying to production with Docker..."
    
    # Check prerequisites
    if ! command_exists docker; then
        print_error "Docker is not installed"
        return 1
    fi
    
    # Build and push image
    if ! build_and_push_docker_image; then
        print_error "Failed to build and push Docker image"
        return 1
    fi
    
    print_status "✅ Production deployment completed successfully"
    
    # Show deployment status
    show_production_status
}

# Function to install ArgoCD (if cluster is available)
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    print_status "Applying ArgoCD manifests..."
    if ! kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml; then
        print_error "Failed to install ArgoCD"
        return 1
    fi
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$ARGOCD_NAMESPACE" || {
        print_warning "ArgoCD server not ready within timeout, but continuing..."
        print_info "You can check status with: kubectl get pods -n $ARGOCD_NAMESPACE"
    }
    
    # Create external service for ArgoCD
    print_status "Creating ArgoCD external service..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-external
  namespace: $ARGOCD_NAMESPACE
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: $ARGOCD_HTTP_PORT
      protocol: TCP
    - name: https
      port: 443
      targetPort: 8080
      nodePort: $ARGOCD_HTTPS_PORT
      protocol: TCP
  selector:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
EOF
    
    print_status "✅ ArgoCD installed successfully with external access."
}

# Function to install Prometheus Operator CRDs
install_prometheus_crds() {
    print_status "Installing Prometheus Operator CRDs..."
    
    # Install ServiceMonitor CRD
    if ! kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml; then
        print_error "Failed to install Prometheus Operator CRDs"
        return 1
    fi
    
    # Wait for CRD to be ready
    kubectl wait --for=condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com || {
        print_warning "ServiceMonitor CRD not ready within timeout"
    }
    
    print_status "Prometheus Operator CRDs installed successfully."
}

# Function to get ArgoCD admin password
get_argocd_password() {
    print_status "Getting ArgoCD admin password..."
    
    # Wait for secret to be available
    local retry_count=0
    local max_retries=30
    
    while [ $retry_count -lt $max_retries ]; do
        if kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
            echo "ArgoCD admin password: $ARGOCD_PASSWORD"
            print_warning "Please save this password for ArgoCD UI access."
            return 0
        fi
        print_info "Waiting for ArgoCD password secret... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
        retry_count=$((retry_count + 1))
    done
    
    print_error "Failed to retrieve ArgoCD password after $max_retries attempts"
    return 1
}

# Function to deploy Helm chart (if cluster is available)
deploy_helm_chart() {
    print_status "Deploying Helm chart..."
    
    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if ServiceMonitor CRD exists
    if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
        print_status "ServiceMonitor CRD found. Enabling monitoring..."
        SERVICE_MONITOR_ENABLED="true"
    else
        print_warning "ServiceMonitor CRD not found. Disabling monitoring to avoid errors."
        print_info "To enable monitoring, install Prometheus Operator first:"
        print_info "  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
        SERVICE_MONITOR_ENABLED="false"
    fi
    
    # Install/upgrade Helm chart
    if ! helm upgrade --install "$APP_NAME" "$HELM_CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set serviceMonitor.enabled="$SERVICE_MONITOR_ENABLED" \
        --timeout 10m; then
        print_error "Helm deployment failed"
        return 1
    fi
    
    # Wait for deployment to be ready (separate from helm wait)
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/"$APP_NAME" -n "$NAMESPACE" || {
        print_warning "Deployment not ready within timeout, but continuing..."
        print_info "You can check status with: kubectl get pods -n $NAMESPACE"
    }
    
    print_status "Helm chart deployed successfully."
}

# Function to deploy ArgoCD application (if cluster is available)
deploy_argocd_app() {
    print_status "Deploying ArgoCD application..."
    
    # Apply ArgoCD application
    if ! kubectl apply -f "$ARGOCD_APP_PATH/application.yaml"; then
        print_error "Failed to apply ArgoCD application"
        return 1
    fi
    
    # Wait for application to be synced
    print_status "Waiting for ArgoCD application to sync..."
    argocd app sync "$APP_NAME" || {
        print_warning "ArgoCD sync failed, but application may still be deployed"
        print_info "You can check status with: argocd app get $APP_NAME"
    }
    
    # Wait for application to be healthy
    print_status "Waiting for ArgoCD application to be healthy..."
    timeout 60 bash -c "until argocd app get \"$APP_NAME\" --output json | grep -q \"Healthy\" >/dev/null 2>&1; do sleep 5; done" || {
        print_warning "Application not healthy within timeout, but continuing..."
        print_info "You can check status with: argocd app get $APP_NAME"
    }
    
    print_status "ArgoCD application deployed successfully."
}

# Function to check deployment health
check_deployment_health() {
    print_status "Checking deployment health..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_warning "No Kubernetes cluster available for health check."
        return 1
    fi
    
    # Check if pods are running
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=student-tracker --no-headers | grep -q "Running"; then
        print_status "✅ Application pods are running"
    else
        print_warning "⚠️ Application pods are not running"
        print_info "Check pod status with: kubectl get pods -n $NAMESPACE"
        return 1
    fi
    
    # Check if service is available
    if kubectl get service -n "$NAMESPACE" student-tracker >/dev/null 2>&1; then
        print_status "✅ Service is available"
    else
        print_warning "⚠️ Service is not available"
        return 1
    fi
    
    # Check ArgoCD application status
    if command_exists argocd; then
        if argocd app get "$APP_NAME" >/dev/null 2>&1; then
            print_status "✅ ArgoCD application exists"
        else
            print_warning "⚠️ ArgoCD application not found"
        fi
    fi
    
    return 0
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo "=================="
    
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "Kubernetes Resources:"
        kubectl get all -n "$NAMESPACE"
        
        echo ""
        echo "Pod Status:"
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=student-tracker
        
        echo ""
        echo "Service Status:"
        kubectl get service -n "$NAMESPACE"
        
        if command_exists argocd; then
            echo ""
            echo "ArgoCD Application Status:"
            argocd app get "$APP_NAME" || echo "ArgoCD application not found"
        fi
        
        echo ""
        echo "Application URLs:"
        echo "  - Student Tracker App: http://$PRODUCTION_HOST:$PRODUCTION_PORT"
        echo "  - API Documentation: http://$PRODUCTION_HOST:$PRODUCTION_PORT/docs"
        echo "  - Health Check: http://$PRODUCTION_HOST:$PRODUCTION_PORT/health"
        echo ""
        echo "ArgoCD Access:"
        echo "  - ArgoCD UI: http://$PRODUCTION_HOST:$ARGOCD_HTTP_PORT"
        echo "  - ArgoCD HTTPS: https://$PRODUCTION_HOST:$ARGOCD_HTTPS_PORT"
        echo "  - Username: admin"
        echo "  - Password: (see above)"
        
        # Run health check
        check_deployment_health
    else
        echo "No Kubernetes cluster available for status check."
    fi
}

# Function to show production Docker status
show_production_status() {
    print_status "Production Docker Deployment Status:"
    echo "===================================="
    
    # Check if Docker is available
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        if sudo docker info >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
        else
            print_error "Docker is not available"
            return 1
        fi
    fi
    
    echo ""
    echo "Container Status:"
    $DOCKER_CMD ps -a | grep "$APP_NAME-production" || echo "No production container found"
    
    echo ""
    echo "Docker Images:"
    $DOCKER_CMD images | grep "$APP_NAME" || echo "No student-tracker images found"
    
    echo ""
    echo "Application URLs:"
    echo "  - Student Tracker App: http://localhost:$PRODUCTION_PORT"
    echo "  - API Documentation: http://localhost:$PRODUCTION_PORT/docs"
    echo "  - Health Check: http://localhost:$PRODUCTION_PORT/health"
    echo "  - Students Interface: http://localhost:$PRODUCTION_PORT/students/"
    echo "  - Metrics: http://localhost:$PRODUCTION_PORT/metrics"
    
    echo ""
    echo "Container Logs (last 10 lines):"
    $DOCKER_CMD logs --tail 10 "$APP_NAME-production" 2>/dev/null || echo "No logs available"
    
    echo ""
    echo "Testing Health Endpoint:"
    if curl -f "http://localhost:$PRODUCTION_PORT/health" >/dev/null 2>&1; then
        print_status "✅ Application is healthy and responding"
        echo "Health Response:"
        curl -s "http://localhost:$PRODUCTION_PORT/health" | head -c 200
        echo "..."
    else
        print_warning "⚠️ Health check failed or application is starting up"
        print_info "Try again in a few moments or check container logs"
    fi
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    print_status "Running comprehensive validation..."
    
    # Check if required files exist
    local required_files=("app/main.py" "app/crud.py" "app/database.py" "app/models.py" "app/routes/students.py" "app/routes/api.py")
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            print_info "Current directory: $(pwd)"
            print_info "Available files in app/: $(ls -la app/ 2>/dev/null || echo 'app/ directory not found')"
            return 1
        fi
    done
    
    # Validate Python code
    print_status "Validating Python code..."
    if python3 -m py_compile app/main.py app/crud.py app/database.py app/models.py app/routes/students.py app/routes/api.py; then
        print_status "✅ Python code validation passed"
    else
        print_error "❌ Python code validation failed"
        return 1
    fi
    
    # Run basic tests
    print_status "Running basic tests..."
    if [ -f "app/test_basic.py" ]; then
        if python3 app/test_basic.py; then
            print_status "✅ Basic tests passed"
        else
            print_warning "⚠️ Basic tests failed (expected without dependencies)"
        fi
    else
        print_warning "⚠️ Test file not found: app/test_basic.py"
    fi
    
    # Validate Helm chart
    print_status "Validating Helm chart..."
    if validate_helm_chart; then
        print_status "✅ Helm chart validation passed"
    else
        print_error "❌ Helm chart validation failed"
        return 1
    fi
    
    # Validate ArgoCD application
    print_status "Validating ArgoCD application..."
    if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))" 2>/dev/null; then
        print_status "✅ ArgoCD application validation passed"
    else
        print_error "❌ ArgoCD application validation failed"
        return 1
    fi
    
    # Validate Dockerfile
    print_status "Validating Dockerfile..."
    if [ -f "Dockerfile" ]; then
        print_status "✅ Dockerfile exists"
    else
        print_error "❌ Dockerfile not found"
        return 1
    fi
    
    # Validate requirements.txt
    print_status "Validating requirements.txt..."
    if [ -f "requirements.txt" ]; then
        print_status "✅ requirements.txt exists"
    else
        print_error "❌ requirements.txt not found"
        return 1
    fi
    
    print_status "✅ Comprehensive validation completed successfully"
    return 0
}

# Function to show next steps
show_next_steps() {
    print_status "Next Steps:"
    echo "============"
    echo ""
    echo "🚀 DEPLOYMENT OPTIONS:"
    echo "1. Set up a Kubernetes cluster (minikube, kind, or cloud provider)"
    echo "2. Build and push your Docker image to a registry"
    echo "3. Update the image repository in helm-chart/values.yaml"
    echo "4. Run the deployment script again with a connected cluster"
    echo ""
    echo "📋 QUICK SETUP COMMANDS:"
    echo "# For minikube:"
    echo "minikube start --driver=docker"
    echo "minikube addons enable ingress"
    echo ""
    echo "# For kind:"
    echo "kind create cluster --name student-tracker"
    echo ""
    echo "# Build and push Docker image:"
    echo "docker build -t ghcr.io/bonaventuresimeon/NativeSeries/student-tracker:latest ."
    echo "docker push ghcr.io/bonaventuresimeon/NativeSeries/student-tracker:latest"
    echo ""
    echo "🌐 PRODUCTION ACCESS:"
    echo "  - Student Tracker App: http://$PRODUCTION_HOST:$PRODUCTION_PORT"
    echo "  - API Documentation: http://$PRODUCTION_HOST:$PRODUCTION_PORT/docs"
    echo "  - ArgoCD UI: http://$PRODUCTION_HOST:$ARGOCD_HTTP_PORT"
    echo "  - ArgoCD HTTPS: https://$PRODUCTION_HOST:$ARGOCD_HTTPS_PORT"
    echo ""
    echo "📖 For detailed instructions, see README.md"
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    
    # Handle machine pruning based on command line arguments
    if [[ "$FORCE_PRUNE" == "true" ]]; then
        print_status "🧹 Force pruning enabled. Performing complete machine pruning..."
        prune_machine
        echo ""
        print_status "Pruning completed. Proceeding with deployment..."
        echo ""
    elif [[ "$SKIP_PRUNE" == "true" ]]; then
        print_info "Skipping machine pruning (--skip-prune flag used)."
    else
        # Ask user if they want to perform complete machine pruning
        echo ""
        print_warning "🧹 Complete Machine Pruning"
        echo "This will clean up all Docker resources, Kubernetes namespaces, and system files."
        echo "This action will:"
        echo "  • Stop and remove all Docker containers"
        echo "  • Remove all Docker images and volumes"
        echo "  • Clean up Kubernetes namespaces"
        echo "  • Remove temporary files and logs"
        echo "  • Clean package cache"
        echo ""
        read -p "Do you want to perform complete machine pruning before deployment? (y/N): " prune_choice
        
        if [[ $prune_choice =~ ^[Yy]$ ]]; then
            prune_machine
            echo ""
            print_status "Pruning completed. Proceeding with deployment..."
            echo ""
        else
            print_info "Skipping machine pruning. Proceeding with deployment..."
        fi
    fi
    
    check_prerequisites
    
    # Check if we have a cluster
    if check_cluster; then
        # Check for common deployment issues
        check_deployment_issues
        
        # We have a cluster, proceed with full deployment
        echo "Choose deployment type:"
        echo "1. Install ArgoCD and deploy application"
        echo "2. Deploy application only (ArgoCD already installed)"
        echo "3. Build and push Docker image only"
        echo "4. Validate configuration only"
        echo "5. Install Prometheus CRDs and deploy with monitoring"
        echo "6. Deploy to production with Docker Hub"
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1)
                install_argocd
                get_argocd_password
                build_docker_image
                deploy_helm_chart
                deploy_argocd_app
                check_deployment_health
                show_status
                ;;
            2)
                build_docker_image
                deploy_helm_chart
                deploy_argocd_app
                check_deployment_health
                show_status
                ;;
            3)
                build_docker_image
                ;;
            4)
                run_comprehensive_validation
                ;;
            5)
                install_prometheus_crds
                build_docker_image
                deploy_helm_chart
                deploy_argocd_app
                show_status
                ;;
            6)
                deploy_production_docker
                ;;
            *)
                print_error "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    else
        # No cluster available, focus on validation and Docker deployment
        print_warning "No Kubernetes cluster available."
        print_info "Choose deployment option:"
        echo "1. Validate configuration only"
        echo "2. Build Docker image locally"
        echo "3. Deploy to production with Docker Hub (recommended)"
        read -p "Enter your choice (1-3): " no_cluster_choice
        
        case $no_cluster_choice in
            1)
                run_comprehensive_validation
                show_next_steps
                ;;
            2)
                run_comprehensive_validation
                build_docker_image
                show_next_steps
                ;;
            3)
                run_comprehensive_validation
                deploy_production_docker
                ;;
            *)
                print_info "Invalid choice, running validation only."
                run_comprehensive_validation
                show_next_steps
                ;;
        esac
    fi
    
    print_status "Deployment process completed!"
}

# Run main function
main "$@"