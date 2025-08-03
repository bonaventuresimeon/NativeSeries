#!/bin/bash

# 🚀 SUPER SIMPLE DEPLOY SCRIPT 🚀
# One command to rule them all: Download → Install → Build → Deploy → DNS
# Even a child can use this! Just run: ./simple-deploy.sh

set -e

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - EVERYTHING in one namespace!
NAMESPACE="student-tracker"
APP_NAME="student-tracker"
DOMAIN="${DOMAIN:-student-tracker.local}"
NODE_PORT="${NODE_PORT:-30080}"

# Print with style
print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}🚀 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}📋 Step: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install everything we need
install_tools() {
    print_header "INSTALLING ALL TOOLS"
    
    print_step "Updating system packages..."
    sudo apt update -y >/dev/null 2>&1
    sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release git >/dev/null 2>&1
    print_success "System packages updated"
    
    # Install Docker
    if ! command_exists docker; then
        print_step "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh >/dev/null 2>&1
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_success "Docker installed"
    else
        print_success "Docker already installed"
    fi
    
    # Install kubectl
    if ! command_exists kubectl; then
        print_step "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >/dev/null 2>&1
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
        print_success "kubectl installed"
    else
        print_success "kubectl already installed"
    fi
    
    # Install kind (Kubernetes in Docker)
    if ! command_exists kind; then
        print_step "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 >/dev/null 2>&1
        sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
        rm kind
        print_success "kind installed"
    else
        print_success "kind already installed"
    fi
    
    # Install helm
    if ! command_exists helm; then
        print_step "Installing helm..."
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 >/dev/null 2>&1
        chmod 700 get_helm.sh
        ./get_helm.sh >/dev/null 2>&1
        rm get_helm.sh
        print_success "helm installed"
    else
        print_success "helm already installed"
    fi
    
    print_success "ALL TOOLS INSTALLED! 🎉"
}

# Step 2: Create a simple local cluster
setup_cluster() {
    print_header "SETTING UP KUBERNETES CLUSTER"
    
    # Clean up any existing cluster
    if kind get clusters 2>/dev/null | grep -q "$APP_NAME"; then
        print_step "Cleaning existing cluster..."
        kind delete cluster --name "$APP_NAME" >/dev/null 2>&1
    fi
    
    print_step "Creating new Kubernetes cluster..."
    
    # Create cluster with ingress and port mappings
    cat <<EOF | kind create cluster --name "$APP_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: $NODE_PORT
    hostPort: $NODE_PORT
    protocol: TCP
EOF
    
    # Set context
    kubectl config use-context "kind-$APP_NAME" >/dev/null 2>&1
    
    print_success "Kubernetes cluster created and ready!"
}

# Step 3: Install ingress controller
setup_ingress() {
    print_header "SETTING UP INGRESS FOR DNS ACCESS"
    
    print_step "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml >/dev/null 2>&1
    
    print_step "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s >/dev/null 2>&1
    
    print_success "Ingress controller ready!"
}

# Step 4: Create the namespace and deploy everything there
create_namespace() {
    print_header "CREATING SINGLE NAMESPACE FOR EVERYTHING"
    
    print_step "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    print_success "Namespace '$NAMESPACE' created!"
}

# Step 5: Build and deploy the application
build_and_deploy() {
    print_header "BUILDING AND DEPLOYING APPLICATION"
    
    print_step "Building Docker image..."
    docker build -t "$APP_NAME:latest" . >/dev/null 2>&1
    
    print_step "Loading image into cluster..."
    kind load docker-image "$APP_NAME:latest" --name "$APP_NAME" >/dev/null 2>&1
    
    print_step "Creating simplified deployment..."
    
    # Create a simple all-in-one deployment
    cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $APP_NAME:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: MONGO_URI
          value: "mongodb://mongo:27017"
        - name: DATABASE_NAME
          value: "student_project_tracker"
        - name: COLLECTION_NAME
          value: "students"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8000
    nodePort: $NODE_PORT
  selector:
    app: $APP_NAME
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
  namespace: $NAMESPACE
  labels:
    app: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: mongo:5.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_DATABASE
          value: "student_project_tracker"
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: mongo-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mongo
  namespace: $NAMESPACE
  labels:
    app: mongo
spec:
  ports:
  - port: 27017
    targetPort: 27017
  selector:
    app: mongo
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME
            port:
              number: 80
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME
            port:
              number: 80
EOF
    
    print_step "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$APP_NAME -n $NAMESPACE >/dev/null 2>&1
    kubectl wait --for=condition=available --timeout=300s deployment/mongo -n $NAMESPACE >/dev/null 2>&1
    
    print_success "Application deployed successfully!"
}

# Step 6: Setup DNS and show access info
setup_dns_and_show_info() {
    print_header "SETTING UP DNS AND ACCESS"
    
    print_step "Configuring local DNS..."
    
    # Add to /etc/hosts if not already there
    if ! grep -q "$DOMAIN" /etc/hosts 2>/dev/null; then
        echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts >/dev/null
        print_success "Added $DOMAIN to /etc/hosts"
    else
        print_success "$DOMAIN already in /etc/hosts"
    fi
    
    print_step "Testing application health..."
    sleep 10
    
    # Test the application
    for i in {1..30}; do
        if curl -s http://localhost:$NODE_PORT/health >/dev/null 2>&1; then
            print_success "Application is healthy and responding!"
            break
        fi
        sleep 2
    done
    
    print_header "🎉 DEPLOYMENT COMPLETE! 🎉"
    
    echo ""
    echo -e "${GREEN}🌐 Your application is now available at:${NC}"
    echo -e "${CYAN}   • http://$DOMAIN${NC}"
    echo -e "${CYAN}   • http://localhost${NC}"
    echo -e "${CYAN}   • http://localhost:$NODE_PORT${NC}"
    echo ""
    echo -e "${GREEN}📊 Application URLs:${NC}"
    echo -e "${CYAN}   • Main App: http://$DOMAIN${NC}"
    echo -e "${CYAN}   • API Docs: http://$DOMAIN/docs${NC}"
    echo -e "${CYAN}   • Health: http://$DOMAIN/health${NC}"
    echo -e "${CYAN}   • Students: http://$DOMAIN/students/${NC}"
    echo ""
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo -e "${CYAN}   • View pods: kubectl get pods -n $NAMESPACE${NC}"
    echo -e "${CYAN}   • View logs: kubectl logs -f deployment/$APP_NAME -n $NAMESPACE${NC}"
    echo -e "${CYAN}   • Delete all: kind delete cluster --name $APP_NAME${NC}"
    echo ""
    echo -e "${PURPLE}✨ Everything is running in ONE cluster, ONE namespace: $NAMESPACE${NC}"
    echo -e "${PURPLE}✨ No complex ArgoCD setup needed!${NC}"
    echo ""
}

# Step 7: Create management commands
create_management_scripts() {
    print_header "CREATING MANAGEMENT SCRIPTS"
    
    # Create status script
    cat > check-status.sh << 'EOF'
#!/bin/bash
echo "🔍 Checking Student Tracker Status..."
echo ""
echo "📊 Pods:"
kubectl get pods -n student-tracker
echo ""
echo "🌐 Services:"
kubectl get services -n student-tracker
echo ""
echo "📡 Ingress:"
kubectl get ingress -n student-tracker
echo ""
echo "🔗 Application URLs:"
echo "  • http://student-tracker.local"
echo "  • http://localhost"
echo "  • http://localhost:30080"
EOF
    chmod +x check-status.sh
    
    # Create logs script
    cat > view-logs.sh << 'EOF'
#!/bin/bash
echo "📄 Viewing Student Tracker Logs..."
kubectl logs -f deployment/student-tracker -n student-tracker
EOF
    chmod +x view-logs.sh
    
    # Create cleanup script
    cat > cleanup.sh << 'EOF'
#!/bin/bash
echo "🧹 Cleaning up Student Tracker..."
kind delete cluster --name student-tracker
sudo sed -i '/student-tracker.local/d' /etc/hosts
echo "✅ Cleanup complete!"
EOF
    chmod +x cleanup.sh
    
    print_success "Management scripts created:"
    print_info "  • ./check-status.sh - Check application status"
    print_info "  • ./view-logs.sh - View application logs"
    print_info "  • ./cleanup.sh - Remove everything"
}

# Main execution
main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
   _____ __            __            __     ______                __            
  / ___// /___  ______/ /__  ____  / /_   /_  __/________ ______/ /_____  _____
  \__ \/ __/ / / / __  / _ \/ __ \/ __/    / / / ___/ __ `/ ___/ //_/ _ \/ ___/
 ___/ / /_/ /_/ / /_/ /  __/ / / / /_     / / / /  / /_/ / /__/ ,< /  __/ /    
/____/\__/\__,_/\__,_/\___/_/ /_/\__/    /_/ /_/   \__,_/\___/_/|_|\___/_/     
                                                                               
              🚀 SUPER SIMPLE DEPLOYMENT 🚀
            One Command • One Namespace • One DNS
EOF
    echo -e "${NC}"
    
    print_info "This script will:"
    print_info "  1. Install all required tools (Docker, kubectl, kind, helm)"
    print_info "  2. Create a local Kubernetes cluster"
    print_info "  3. Build your application"
    print_info "  4. Deploy everything to ONE namespace"
    print_info "  5. Set up DNS access"
    print_info "  6. Create management scripts"
    echo ""
    
    read -p "🚀 Ready to deploy? Press Enter to continue or Ctrl+C to cancel..."
    
    # Execute all steps
    install_tools
    setup_cluster
    setup_ingress
    create_namespace
    build_and_deploy
    setup_dns_and_show_info
    create_management_scripts
    
    print_header "🎊 SUCCESS! 🎊"
    echo -e "${GREEN}Your Student Tracker is now running!${NC}"
    echo -e "${CYAN}Visit: http://student-tracker.local${NC}"
    echo ""
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "🚀 Student Tracker Simple Deploy"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help"
        echo "  --domain NAME  Set custom domain (default: student-tracker.local)"
        echo "  --port PORT    Set custom port (default: 30080)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 --domain myapp.local              # Custom domain"
        echo "  $0 --domain myapp.local --port 8080  # Custom domain and port"
        echo ""
        echo "After deployment, use these scripts:"
        echo "  ./check-status.sh  # Check status"
        echo "  ./view-logs.sh     # View logs"
        echo "  ./cleanup.sh       # Remove everything"
        exit 0
        ;;
    --domain)
        DOMAIN="$2"
        shift 2
        ;;
    --port)
        NODE_PORT="$2"
        shift 2
        ;;
    *)
        # Continue with main execution
        ;;
esac

# Run main function
main "$@"