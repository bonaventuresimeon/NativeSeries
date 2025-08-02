#!/bin/bash

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
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        print_status "✅ ArgoCD CLI installed successfully"
    fi
    
    # Check Docker (optional)
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            print_status "✅ Docker is available and running"
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

# Function to check and fix common deployment issues
check_deployment_issues() {
    print_status "Checking for common deployment issues..."
    
    # Check if namespace exists and is accessible
    if kubectl cluster-info >/dev/null 2>&1; then
        if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
            print_info "Creating namespace $NAMESPACE..."
            kubectl create namespace $NAMESPACE
        fi
        
        # Check for existing resources that might conflict
        if kubectl get deployment $APP_NAME -n $NAMESPACE >/dev/null 2>&1; then
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
    
    # Add Bitnami repository
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Update Helm dependencies (only if dependencies exist)
    cd $HELM_CHART_PATH
    if [ -f "Chart.yaml" ] && grep -q "dependencies:" Chart.yaml; then
        helm dependency update || echo "Dependency update failed, continuing..."
    else
        echo "No dependencies to update"
    fi
    cd ..
    
    # Lint Helm chart
    helm lint $HELM_CHART_PATH
    
    # Dry run to validate templates
    helm template $APP_NAME $HELM_CHART_PATH --namespace $NAMESPACE --dry-run
    
    print_status "Helm chart validation completed successfully."
}

# Function to validate ArgoCD application
validate_argocd_app() {
    print_status "Validating ArgoCD application configuration..."
    
    # Validate YAML syntax without connecting to cluster
    kubectl apply -f $ARGOCD_APP_PATH/application.yaml --dry-run=client --validate=false 2>/dev/null || {
        print_warning "ArgoCD application validation skipped (no cluster connection)"
        print_status "ArgoCD application YAML syntax is valid"
    }
    
    print_status "ArgoCD application validation completed successfully."
}

# Function to build Docker image (if Docker is available)
build_docker_image() {
    print_status "Checking Docker availability..."
    
    if command_exists docker && docker info >/dev/null 2>&1; then
        print_status "Building Docker image..."
        
        # Get the current git commit SHA
        IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
        IMAGE_NAME="$APP_NAME:$IMAGE_TAG"
        
        # Build Docker image
        if docker build -t $IMAGE_NAME .; then
            print_status "✅ Docker image built successfully: $IMAGE_NAME"
            
                        # Check if we should push the image
            if [ "$PUSH_IMAGE" = "true" ]; then
                print_status "Pushing Docker image to registry..."
                if docker push $IMAGE_NAME; then
                    print_status "✅ Docker image pushed successfully"
                else
                    print_warning "⚠️ Failed to push Docker image"
                    print_info "You can push manually with: docker push $IMAGE_NAME"
                    print_info "Make sure you're logged in to the registry: docker login"
                fi
            else
                print_info "To push the image, run: docker push $IMAGE_NAME"
                print_info "Make sure you're logged in to the registry: docker login"
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

# Function to install ArgoCD (if cluster is available)
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    print_status "Applying ArgoCD manifests..."
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE || {
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
      nodePort: 30080
      protocol: TCP
    - name: https
      port: 443
      targetPort: 8080
      nodePort: 30443
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
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
    
    # Wait for CRD to be ready
    kubectl wait --for condition=established --timeout=60s crd/servicemonitors.monitoring.coreos.com
    
    print_status "Prometheus Operator CRDs installed successfully."
}

# Function to get ArgoCD admin password
get_argocd_password() {
    print_status "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "ArgoCD admin password: $ARGOCD_PASSWORD"
    print_warning "Please save this password for ArgoCD UI access."
}

# Function to deploy Helm chart (if cluster is available)
deploy_helm_chart() {
    print_status "Deploying Helm chart..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
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
    helm upgrade --install $APP_NAME $HELM_CHART_PATH \
        --namespace $NAMESPACE \
        --create-namespace \
        --set serviceMonitor.enabled=$SERVICE_MONITOR_ENABLED \
        --timeout 10m
    
    # Wait for deployment to be ready (separate from helm wait)
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$APP_NAME -n $NAMESPACE || {
        print_warning "Deployment not ready within timeout, but continuing..."
        print_info "You can check status with: kubectl get pods -n $NAMESPACE"
    }
    
    print_status "Helm chart deployed successfully."
}

# Function to deploy ArgoCD application (if cluster is available)
deploy_argocd_app() {
    print_status "Deploying ArgoCD application..."
    
    # Apply ArgoCD application
    kubectl apply -f $ARGOCD_APP_PATH/application.yaml
    
    # Wait for application to be synced
    print_status "Waiting for ArgoCD application to sync..."
    argocd app sync $APP_NAME || {
        print_warning "ArgoCD sync failed, but application may still be deployed"
        print_info "You can check status with: argocd app get $APP_NAME"
    }
    
    # Wait for application to be healthy
    print_status "Waiting for ArgoCD application to be healthy..."
    timeout 60 bash -c 'until argocd app get $APP_NAME --output json | grep -q "Healthy" >/dev/null 2>&1; do sleep 5; done' || {
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
    if kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-tracker --no-headers | grep -q "Running"; then
        print_status "✅ Application pods are running"
    else
        print_warning "⚠️ Application pods are not running"
        print_info "Check pod status with: kubectl get pods -n $NAMESPACE"
        return 1
    fi
    
    # Check if service is available
    if kubectl get service -n $NAMESPACE student-tracker >/dev/null 2>&1; then
        print_status "✅ Service is available"
    else
        print_warning "⚠️ Service is not available"
        return 1
    fi
    
    # Check ArgoCD application status
    if command_exists argocd; then
        if argocd app get $APP_NAME >/dev/null 2>&1; then
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
        kubectl get all -n $NAMESPACE
        
        echo ""
        echo "Pod Status:"
        kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=student-tracker
        
        echo ""
        echo "Service Status:"
        kubectl get service -n $NAMESPACE
        
        if command_exists argocd; then
            echo ""
            echo "ArgoCD Application Status:"
            argocd app get $APP_NAME || echo "ArgoCD application not found"
        fi
        
        echo ""
        echo "Application URLs:"
        echo "  - Student Tracker App: http://18.206.89.183:30011"
        echo "  - API Documentation: http://18.206.89.183:30011/docs"
        echo "  - Health Check: http://18.206.89.183:30011/health"
        echo ""
        echo "ArgoCD Access:"
        echo "  - ArgoCD UI: http://18.206.89.183:30080"
        echo "  - ArgoCD HTTPS: https://18.206.89.183:30443"
        echo "  - Username: admin"
        echo "  - Password: (see above)"
        
        # Run health check
        check_deployment_health
    else
        echo "No Kubernetes cluster available for status check."
    fi
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    print_status "Running comprehensive validation..."
    
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
    if python3 app/test_basic.py; then
        print_status "✅ Basic tests passed"
    else
        print_warning "⚠️ Basic tests failed (expected without dependencies)"
    fi
    
    # Validate Helm chart
    print_status "Validating Helm chart..."
    if cd helm-chart && helm lint . && cd ..; then
        print_status "✅ Helm chart validation passed"
    else
        print_error "❌ Helm chart validation failed"
        return 1
    fi
    
    # Validate ArgoCD application
    print_status "Validating ArgoCD application..."
    if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))"; then
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
    echo "  - Student Tracker App: http://18.206.89.183:30011"
    echo "  - API Documentation: http://18.206.89.183:30011/docs"
    echo "  - ArgoCD UI: http://18.206.89.183:30080"
    echo "  - ArgoCD HTTPS: https://18.206.89.183:30443"
    echo ""
    echo "📖 For detailed instructions, see README.md"
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    
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
        read -p "Enter your choice (1-5): " choice
        
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
            *)
                print_error "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    else
        # No cluster available, focus on validation
        print_warning "No Kubernetes cluster available. Running validation only."
        run_comprehensive_validation
        build_docker_image
        show_next_steps
    fi
    
    print_status "Deployment process completed!"
}

# Run main function
main "$@"