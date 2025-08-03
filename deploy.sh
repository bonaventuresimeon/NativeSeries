#!/bin/bash

# 🚀 Comprehensive Deployment Script for Student Tracker
# Merged from: deploy-ec2-user.sh, fix-helm-deployment.sh, quick-deploy-docker.sh, scripts/deploy.sh
# Updated with DNS IP: 18.206.89.183

set -e

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

# Production configuration with DNS IP
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
ARGOCD_HTTP_PORT="30080"
ARGOCD_HTTPS_PORT="30443"
ARGOCD_PROD_URL="https://argocd-prod.${PRODUCTION_HOST}.nip.io"
ARGOCD_DEV_URL="https://argocd-dev.${PRODUCTION_HOST}.nip.io"
ARGOCD_STAGING_URL="https://argocd-staging.${PRODUCTION_HOST}.nip.io"

# EC2 configuration
EC2_USER="ec2-user"

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show usage
show_usage() {
    echo "🚀 Student Tracker Comprehensive Deployment Script"
    echo "================================================="
    echo ""
    echo "Usage: ./deploy.sh [OPTION]"
    echo ""
    echo "OPTIONS:"
    echo "  docker           Quick Docker deployment (recommended for EC2)"
    echo "  ec2              Full EC2 deployment with system setup"
    echo "  kubernetes       Full Kubernetes deployment with ArgoCD"
    echo "  helm-fix         Fix Helm deployment issues"
    echo "  validate         Validate configuration only"
    echo "  ec2-validate     Comprehensive EC2 deployment validation"
    echo "  build            Build Docker image only"
    echo "  argocd           Install ArgoCD only"
    echo "  monitoring       Deploy with Prometheus monitoring"
    echo "  health-check     Check deployment health"
    echo "  status           Show deployment status"
    echo "  clean            Clean up deployments"
    echo "  help             Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  ./deploy.sh docker        # Quick Docker deployment"
    echo "  ./deploy.sh ec2           # Full EC2 setup and deployment"
    echo "  ./deploy.sh kubernetes    # Full K8s deployment"
    echo "  ./deploy.sh validate      # Validate configuration"
    echo "  ./deploy.sh ec2-validate  # Validate EC2 deployment"
    echo ""
    echo "PRODUCTION URLS:"
    echo "  Application: ${PRODUCTION_URL}"
    echo "  API Docs: ${PRODUCTION_URL}/docs"
    echo "  Health: ${PRODUCTION_URL}/health"
    echo "  ArgoCD Prod: ${ARGOCD_PROD_URL}"
    echo "  ArgoCD Dev: ${ARGOCD_DEV_URL}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on EC2
    if [ "$1" = "ec2" ]; then
        print_status "🔍 Checking EC2-specific prerequisites..."
        
        # Check if we can access EC2 metadata
        if curl -s http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
            print_success "✅ EC2 metadata service accessible"
        else
            print_warning "⚠️  EC2 metadata service not accessible (may not be on EC2)"
        fi
        
        # Check security group configuration
        print_status "🔍 Checking security group configuration..."
        if command_exists netstat; then
            OPEN_PORTS=$(sudo netstat -tlnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -u)
            print_info "Currently listening ports: ${OPEN_PORTS}"
        fi
        
        # Check if required ports are available
        for port in 30011 30080 30443; do
            if sudo netstat -tlnp | grep ":$port " >/dev/null 2>&1; then
                print_warning "⚠️  Port $port is already in use"
            else
                print_success "✅ Port $port is available"
            fi
        done
    fi
    
    # Basic tools
    local missing_tools=()
    
    if ! command_exists curl; then
        missing_tools+=("curl")
    fi
    
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_warning "Installing missing tools: ${missing_tools[*]}"
        if command_exists yum; then
            sudo yum update -y
            sudo yum install -y "${missing_tools[@]}"
        elif command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y "${missing_tools[@]}"
        else
            print_error "Package manager not found. Please install: ${missing_tools[*]}"
            exit 1
        fi
    fi
    
    print_success "Prerequisites check completed"
}

# Function to setup EC2 environment
setup_ec2_environment() {
    print_status "🚀 Setting up EC2 environment for ${EC2_USER}"
    print_status "Production URL: ${PRODUCTION_URL}"
    
    # Check if running as ec2-user
    if [ "$(whoami)" != "${EC2_USER}" ]; then
        print_warning "⚠️  This script is designed to run as ${EC2_USER}"
        print_info "Current user: $(whoami)"
        print_info "You may need to run: sudo su - ${EC2_USER}"
        print_info "Or continue with current user (some features may not work)"
    fi
    
    # Check if we're on an EC2 instance
    if curl -s http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
        print_success "✅ Running on EC2 instance"
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        print_info "Instance ID: ${INSTANCE_ID}"
    else
        print_warning "⚠️  Not running on EC2 instance (or metadata service unavailable)"
    fi
    
    # Update system packages
    print_status "📦 Updating system packages..."
    if command_exists yum; then
        sudo yum update -y
    elif command_exists apt-get; then
        sudo apt-get update && sudo apt-get upgrade -y
    else
        print_error "❌ Unsupported package manager"
        exit 1
    fi
    
    # Install required packages
    print_status "📦 Installing required packages..."
    if command_exists yum; then
        sudo yum install -y \
            docker \
            git \
            curl \
            wget \
            unzip \
            python3 \
            python3-pip \
            htop \
            jq
    elif command_exists apt-get; then
        sudo apt-get install -y \
            docker.io \
            git \
            curl \
            wget \
            unzip \
            python3 \
            python3-pip \
            htop \
            jq
    fi
    
    # Start and enable Docker
    print_status "🐳 Setting up Docker..."
    if command_exists systemctl; then
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        print_warning "⚠️  systemctl not available, starting Docker manually"
        sudo service docker start
    fi
    
    # Add user to docker group
    sudo usermod -aG docker ${EC2_USER}
    print_info "Added ${EC2_USER} to docker group"
    print_info "You may need to logout and login again for changes to take effect"
    
    # Install Docker Compose
    print_status "📦 Installing Docker Compose..."
    if ! command_exists docker-compose; then
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_success "✅ Docker Compose ${DOCKER_COMPOSE_VERSION} installed"
    else
        print_info "✅ Docker Compose already installed"
    fi
    
    # Verify Docker installation
    print_status "🔍 Verifying Docker installation..."
    if ! sudo docker info &> /dev/null; then
        print_error "❌ Docker is not running. Please start Docker manually."
        print_info "Run: sudo systemctl start docker"
        print_info "Or: sudo service docker start"
        exit 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(sudo docker --version)
    print_success "✅ Docker installed: ${DOCKER_VERSION}"
    
    # Check available disk space
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    print_info "Available disk space: ${DISK_SPACE}"
    
    # Check available memory
    MEMORY=$(free -h | awk 'NR==2 {print $7}')
    print_info "Available memory: ${MEMORY}"
    
    print_success "✅ EC2 environment setup completed"
}

# Function to install Kubernetes tools
install_kubernetes_tools() {
    print_status "📦 Installing Kubernetes tools..."
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
        print_success "✅ kubectl installed successfully"
    fi
    
    # Install Helm
    if ! command_exists helm; then
        print_status "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        print_success "✅ Helm installed successfully"
    fi
    
    # Install ArgoCD CLI
    if ! command_exists argocd; then
        print_status "Installing ArgoCD CLI..."
        if curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64; then
            sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
            rm argocd-linux-amd64
            print_success "✅ ArgoCD CLI installed successfully"
        else
            print_error "Failed to download ArgoCD CLI"
            exit 1
        fi
    fi
    
    print_success "Kubernetes tools installation completed"
}

# Function to build Docker image
build_docker_image() {
    print_status "🔨 Building Docker image..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        return 1
    fi
    
    if ! sudo docker info &> /dev/null; then
        print_error "Docker is not running"
        return 1
    fi
    
    # Stop and remove existing container
    print_status "🔄 Stopping existing container..."
    sudo docker stop ${APP_NAME} || true
    sudo docker rm ${APP_NAME} || true
    
    # Build Docker image
    sudo docker build -t ${APP_NAME}:latest .
    
    if [ $? -eq 0 ]; then
        print_success "✅ Docker image built successfully"
        return 0
    else
        print_error "❌ Failed to build Docker image"
        return 1
    fi
}

# Function to deploy with Docker
deploy_docker() {
    print_status "🚀 Starting Docker deployment..."
    
    # Ensure Docker is available
    if ! command_exists docker; then
        print_status "Installing Docker..."
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ec2-user
        print_warning "Please logout and login again, then run this script."
        exit 1
    fi
    
    # Check if Docker is running
    if ! sudo docker info &> /dev/null; then
        print_status "Starting Docker..."
        sudo systemctl start docker
        sleep 5
    fi
    
    # Build image if needed
    if ! sudo docker images | grep -q "${APP_NAME}"; then
        build_docker_image
    fi
    
    # Run the application container
    print_status "🚀 Starting application container..."
    sudo docker run -d \
        --name ${APP_NAME} \
        --restart unless-stopped \
        -p ${PRODUCTION_PORT}:8000 \
        -e HOST=0.0.0.0 \
        -e PORT=8000 \
        -e ENVIRONMENT=production \
        -e MONGO_URI=mongodb://${PRODUCTION_HOST}:27017 \
        -e DATABASE_NAME=student_project_tracker \
        -e COLLECTION_NAME=students \
        ${APP_NAME}:latest
    
    if [ $? -eq 0 ]; then
        print_success "✅ Application container started successfully"
    else
        print_error "❌ Failed to start application container"
        return 1
    fi
    
    # Wait for application to start
    print_status "⏳ Waiting for application to start..."
    sleep 30
    
    # Health check with retry
    perform_health_check
    
    # Test all endpoints
    test_endpoints
    
    # Show deployment information
    show_deployment_info
    
    print_success "✅ Docker deployment completed successfully!"
}

# Function to perform health check
perform_health_check() {
    print_status "🔍 Performing health check..."
    retry_count=0
    max_retries=10
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
            print_success "✅ Application is healthy and responding"
            return 0
        else
            retry_count=$((retry_count + 1))
            print_warning "⚠️  Health check attempt $retry_count/$max_retries failed"
            if [ $retry_count -lt $max_retries ]; then
                sleep 10
            else
                print_error "❌ Health check failed after $max_retries attempts"
                print_info "Container logs:"
                sudo docker logs ${APP_NAME} --tail 20
                return 1
            fi
        fi
    done
}

# Function to test all endpoints
test_endpoints() {
    print_status "🧪 Testing all endpoints..."
    
    local endpoints=(
        "/health:Health endpoint"
        "/docs:API documentation"
        "/students/:Students interface"
        "/metrics:Metrics endpoint"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        IFS=':' read -r endpoint description <<< "$endpoint_info"
        if curl -f "${PRODUCTION_URL}${endpoint}" > /dev/null 2>&1; then
            print_success "✅ ${description} working"
        else
            print_error "❌ ${description} failed"
        fi
    done
}

# Function to show deployment information
show_deployment_info() {
    echo ""
    print_success "🎉 Deployment Complete!"
    echo ""
    echo "📋 Deployment Information:"
    echo "   Application: ${APP_NAME}"
    echo "   Production URL: ${PRODUCTION_URL}"
    echo "   API Documentation: ${PRODUCTION_URL}/docs"
    echo "   Health Check: ${PRODUCTION_URL}/health"
    echo "   Metrics: ${PRODUCTION_URL}/metrics"
    echo "   Students Interface: ${PRODUCTION_URL}/students/"
    echo ""
    echo "🌐 ArgoCD URLs:"
    echo "   Production: ${ARGOCD_PROD_URL}"
    echo "   Development: ${ARGOCD_DEV_URL}"
    echo "   Staging: ${ARGOCD_STAGING_URL}"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs: sudo docker logs -f ${APP_NAME}"
    echo "   Stop app: sudo docker stop ${APP_NAME}"
    echo "   Restart app: sudo docker restart ${APP_NAME}"
    echo "   Remove app: sudo docker rm -f ${APP_NAME}"
    echo "   View container: sudo docker ps"
    echo "   View images: sudo docker images"
    echo ""
    
    # Show container status
    print_status "📊 Container Status:"
    sudo docker ps --filter "name=${APP_NAME}"
    
    # Show recent logs
    echo ""
    print_status "📋 Recent Logs:"
    sudo docker logs ${APP_NAME} --tail 10
}

# Function to install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Create namespace
    kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    print_status "Applying ArgoCD manifests..."
    kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n "$ARGOCD_NAMESPACE" || {
        print_warning "ArgoCD server not ready within timeout, but continuing..."
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
    
    print_success "✅ ArgoCD installed successfully"
}

# Function to get ArgoCD password
get_argocd_password() {
    print_status "Getting ArgoCD admin password..."
    
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
    
    print_error "Failed to retrieve ArgoCD password"
    return 1
}

# Function to validate Helm chart
validate_helm_chart() {
    print_status "Validating Helm chart..."
    
    if [ ! -d "$HELM_CHART_PATH" ]; then
        print_error "Helm chart directory not found: $HELM_CHART_PATH"
        return 1
    fi
    
    # Add repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo update || true
    
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
    
    print_success "✅ Helm chart validation completed"
}

# Function to deploy Helm chart
deploy_helm_chart() {
    print_status "Deploying Helm chart..."
    
    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if ServiceMonitor CRD exists
    if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
        SERVICE_MONITOR_ENABLED="true"
    else
        SERVICE_MONITOR_ENABLED="false"
    fi
    
    # Install/upgrade Helm chart
    helm upgrade --install "$APP_NAME" "$HELM_CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set serviceMonitor.enabled="$SERVICE_MONITOR_ENABLED" \
        --set ingress.hosts[0].host="${PRODUCTION_HOST}.nip.io" \
        --set argocd.urls.production="${ARGOCD_PROD_URL}" \
        --set argocd.urls.development="${ARGOCD_DEV_URL}" \
        --set argocd.urls.staging="${ARGOCD_STAGING_URL}" \
        --timeout 10m
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/"$APP_NAME" -n "$NAMESPACE" || {
        print_warning "Deployment not ready within timeout"
    }
    
    print_success "✅ Helm chart deployed successfully"
}

# Function to deploy ArgoCD applications
deploy_argocd_apps() {
    print_status "Deploying ArgoCD applications..."
    
    # Deploy all environment applications
    local apps=("production" "development" "staging")
    
    for app in "${apps[@]}"; do
        if [ -f "$ARGOCD_APP_PATH/application-${app}.yaml" ]; then
            print_status "Deploying ${app} application..."
            kubectl apply -f "$ARGOCD_APP_PATH/application-${app}.yaml"
        fi
    done
    
    print_success "✅ ArgoCD applications deployed"
}

# Function to fix Helm deployment issues
fix_helm_deployment() {
    print_status "🔧 Fixing Helm deployment issues..."
    
    # Install tools if needed
    install_kubernetes_tools
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Please ensure you have:"
        print_info "1. A running Kubernetes cluster"
        print_info "2. kubectl configured to connect to your cluster"
        print_info "3. Proper permissions to access the cluster"
        return 1
    fi
    
    print_success "✅ Connected to Kubernetes cluster"
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_status "Creating namespace..."
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Check existing deployment
    if kubectl get deployment "$APP_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_warning "Existing deployment found"
        print_status "Rolling back to previous version..."
        helm rollback "$APP_NAME" -n "$NAMESPACE" || true
        sleep 30
    fi
    
    # Show current status
    print_status "Current pod status:"
    kubectl get pods -n "$NAMESPACE"
    
    print_status "Recent events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    
    # Fix ArgoCD configuration
    print_status "Checking ArgoCD configuration..."
    if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
        print_success "✅ ArgoCD namespace exists"
        
        # Get ArgoCD server address
        ARGOCD_SERVER=$(kubectl get service argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -z "$ARGOCD_SERVER" ]; then
            ARGOCD_SERVER=$(kubectl get service argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
        fi
        
        if [ -n "$ARGOCD_SERVER" ]; then
            print_status "ArgoCD server found at: $ARGOCD_SERVER"
        fi
    else
        print_warning "ArgoCD namespace not found"
        print_info "To install ArgoCD, run: ./deploy.sh argocd"
    fi
    
    print_success "✅ Helm deployment fix completed"
}

# Function to run comprehensive validation
run_validation() {
    print_status "Running comprehensive validation..."
    
    # Check required files
    local required_files=(
        "app/main.py"
        "app/crud.py" 
        "app/database.py"
        "app/models.py"
        "Dockerfile"
        "requirements.txt"
        "helm-chart/Chart.yaml"
        "helm-chart/values.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            return 1
        fi
    done
    
    # Validate Python code
    if command_exists python3; then
        print_status "Validating Python code..."
        python3 -m py_compile app/main.py app/crud.py app/database.py app/models.py || {
            print_error "Python code validation failed"
            return 1
        }
    fi
    
    # Validate Helm chart
    if command_exists helm; then
        validate_helm_chart || return 1
    fi
    
    # Validate ArgoCD applications
    for app in production development staging; do
        if [ -f "$ARGOCD_APP_PATH/application-${app}.yaml" ]; then
            print_status "Validating ArgoCD ${app} application..."
            if command_exists python3; then
                python3 -c "import yaml; yaml.safe_load(open('$ARGOCD_APP_PATH/application-${app}.yaml'))" 2>/dev/null || {
                    print_error "ArgoCD ${app} application validation failed"
                    return 1
                }
            fi
        fi
    done
    
    print_success "✅ Comprehensive validation completed successfully"
}

# Function to check deployment health
check_health() {
    print_status "🔍 Checking deployment health..."
    
    # Check Docker deployment
    if command_exists docker && sudo docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\t{{.Status}}" | grep -q "${APP_NAME}"; then
        print_success "✅ Docker container is running"
        
        # Get container details
        CONTAINER_ID=$(sudo docker ps | grep "${APP_NAME}" | awk '{print $1}')
        CONTAINER_STATUS=$(sudo docker inspect --format='{{.State.Status}}' "${APP_NAME}" 2>/dev/null)
        print_info "Container ID: ${CONTAINER_ID}"
        print_info "Container Status: ${CONTAINER_STATUS}"
        
        # Check port mapping
        if sudo docker port "${APP_NAME}" | grep -q "30011"; then
            print_success "✅ Port 30011 is exposed"
        else
            print_warning "⚠️ Port 30011 is not exposed"
            print_info "Container port mapping:"
            sudo docker port "${APP_NAME}"
        fi
        
        # Test health endpoint
        print_status "🔍 Testing health endpoint..."
        if curl -f "${PRODUCTION_URL}/health" >/dev/null 2>&1; then
            print_success "✅ Health endpoint is responding"
            
            # Get health response details
            HEALTH_RESPONSE=$(curl -s "${PRODUCTION_URL}/health" 2>/dev/null)
            if command_exists jq; then
                STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status' 2>/dev/null)
                UPTIME=$(echo "$HEALTH_RESPONSE" | jq -r '.uptime_seconds' 2>/dev/null)
                REQUEST_COUNT=$(echo "$HEALTH_RESPONSE" | jq -r '.request_count' 2>/dev/null)
                
                if [ "$STATUS" = "healthy" ]; then
                    print_success "✅ Application status: ${STATUS}"
                    print_info "Uptime: ${UPTIME} seconds"
                    print_info "Request count: ${REQUEST_COUNT}"
                else
                    print_warning "⚠️ Application status: ${STATUS}"
                fi
            else
                print_info "Health response: ${HEALTH_RESPONSE}"
            fi
        else
            print_error "❌ Health endpoint is not responding"
            print_info "Testing with verbose output:"
            curl -v "${PRODUCTION_URL}/health" 2>&1 | head -10
        fi
        
        # Test all endpoints
        print_status "🔍 Testing all endpoints..."
        ENDPOINTS=("docs" "students" "metrics")
        for endpoint in "${ENDPOINTS[@]}"; do
            if curl -f "${PRODUCTION_URL}/${endpoint}" >/dev/null 2>&1; then
                print_success "✅ ${endpoint} endpoint is responding"
            else
                print_warning "⚠️ ${endpoint} endpoint is not responding"
            fi
        done
        
        # Check system resources
        print_status "🔍 Checking system resources..."
        if command_exists htop; then
            CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
            print_info "CPU Usage: ${CPU_USAGE}%"
        fi
        
        MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}' 2>/dev/null || echo "N/A")
        print_info "Memory Usage: ${MEMORY_USAGE}"
        
        DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
        print_info "Disk Usage: ${DISK_USAGE}"
        
        # Check Docker resources
        print_status "🔍 Checking Docker resources..."
        sudo docker stats --no-stream "${APP_NAME}" 2>/dev/null || print_warning "⚠️ Could not get Docker stats"
        
    else
        print_warning "⚠️ Docker container not found"
        print_info "Available containers:"
        sudo docker ps -a 2>/dev/null || print_error "❌ Docker not available"
    fi
    
    # Check Kubernetes deployment if available
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        print_status "🔍 Checking Kubernetes deployment..."
        if kubectl get deployment "$APP_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
            print_success "✅ Kubernetes deployment exists"
            
            # Check pod status
            if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" --no-headers | grep -q "Running"; then
                print_success "✅ Kubernetes pods are running"
            else
                print_warning "⚠️ Kubernetes pods are not running"
                print_info "Pod status:"
                kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" 2>/dev/null
            fi
        else
            print_warning "⚠️ Kubernetes deployment not found"
        fi
    fi
    
    print_success "✅ Health check completed"
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status"
    echo "=================="
    
    # Docker status
    if command_exists docker; then
        echo ""
        echo "Docker Containers:"
        sudo docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No Docker containers found"
    fi
    
    # Kubernetes status
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        echo ""
        echo "Kubernetes Resources:"
        kubectl get all -n "$NAMESPACE" 2>/dev/null || echo "No Kubernetes resources found"
        
        if command_exists argocd; then
            echo ""
            echo "ArgoCD Applications:"
            argocd app list 2>/dev/null || echo "ArgoCD not accessible"
        fi
    fi
    
    echo ""
    echo "Application URLs:"
    echo "  - Main App: ${PRODUCTION_URL}"
    echo "  - API Docs: ${PRODUCTION_URL}/docs"
    echo "  - Health: ${PRODUCTION_URL}/health"
    echo "  - ArgoCD Prod: ${ARGOCD_PROD_URL}"
    echo "  - ArgoCD Dev: ${ARGOCD_DEV_URL}"
}

# Function to clean up deployments
cleanup_deployments() {
    print_status "Cleaning up deployments..."
    
    # Stop Docker containers
    if command_exists docker; then
        print_status "Stopping Docker containers..."
        sudo docker stop ${APP_NAME} 2>/dev/null || true
        sudo docker rm ${APP_NAME} 2>/dev/null || true
        print_success "Docker cleanup completed"
    fi
    
    # Clean Kubernetes resources
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        print_status "Cleaning Kubernetes resources..."
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        print_success "Kubernetes cleanup completed"
    fi
    
    print_success "✅ Cleanup completed"
}

# Function to deploy with full Kubernetes setup
deploy_kubernetes() {
    print_status "🚀 Starting full Kubernetes deployment..."
    
    # Install tools
    install_kubernetes_tools
    
    # Check cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "No Kubernetes cluster available"
        print_info "Please set up a cluster first (minikube, kind, or cloud provider)"
        return 1
    fi
    
    # Install ArgoCD
    install_argocd
    get_argocd_password
    
    # Build and deploy
    build_docker_image
    validate_helm_chart
    deploy_helm_chart
    deploy_argocd_apps
    
    # Show status
    show_status
    
    print_success "✅ Kubernetes deployment completed!"
}

# Function to deploy with monitoring
deploy_with_monitoring() {
    print_status "🚀 Deploying with Prometheus monitoring..."
    
    # Install Prometheus CRDs
    print_status "Installing Prometheus Operator CRDs..."
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
    
    # Wait for CRD
    kubectl wait --for=condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com || {
        print_warning "ServiceMonitor CRD not ready within timeout"
    }
    
    # Deploy with monitoring enabled
    deploy_kubernetes
    
    print_success "✅ Deployment with monitoring completed!"
}

# Main execution
main() {
    case "${1:-help}" in
        "docker")
            check_prerequisites
            deploy_docker
            ;;
        "ec2")
            check_prerequisites
            setup_ec2_environment
            deploy_docker
            ;;
        "kubernetes")
            check_prerequisites
            deploy_kubernetes
            ;;
        "helm-fix")
            check_prerequisites
            fix_helm_deployment
            ;;
        "validate")
            check_prerequisites
            run_validation
            ;;
        "ec2-validate")
            check_prerequisites
            if [ -f "scripts/ec2-validation.sh" ]; then
                ./scripts/ec2-validation.sh
            else
                print_error "EC2 validation script not found"
                exit 1
            fi
            ;;
        "build")
            check_prerequisites
            build_docker_image
            ;;
        "argocd")
            check_prerequisites
            install_kubernetes_tools
            install_argocd
            get_argocd_password
            ;;
        "monitoring")
            check_prerequisites
            deploy_with_monitoring
            ;;
        "health-check")
            check_health
            ;;
        "status")
            show_status
            ;;
        "clean")
            cleanup_deployments
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"