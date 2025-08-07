#!/bin/bash

# NativeSeries - Cluster Deployment Script
# Version: 1.0.0 - Deploy all resources to NativeSeries cluster
# This script applies all fixed manifests to the Kubernetes cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
PRODUCTION_HOST="54.166.101.159"
PRODUCTION_PORT="30011"
ARGOCD_PORT="30080"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"
LOKI_PORT="30083"
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="monitoring"
LOGGING_NAMESPACE="logging"
DOCKER_USERNAME="bonaventuresimeon"
DOCKER_IMAGE="ghcr.io/${DOCKER_USERNAME}/nativeseries"
ARGOCD_VERSION="v2.9.3"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[✅ SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠️  WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[❌ ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[ℹ️  INFO]${NC} $1"; }

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          🚀 NativeSeries - Cluster Deployment                    ║"
echo "║              Target: ${PRODUCTION_HOST}                          ║"
echo "║              Applying all resources to cluster                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirmation
echo -e "${YELLOW}This script will deploy all NativeSeries resources to your cluster:${NC}"
echo -e "${WHITE}  • Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}  • ArgoCD:      http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}  • Grafana:     http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}  • Prometheus:  http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo -e "${WHITE}  • Loki:        http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# ============================================================================
# PHASE 1: CLUSTER VERIFICATION
# ============================================================================

print_section "PHASE 1: Verifying Cluster Access"

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster access
print_info "Checking cluster access..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_error "Cannot access Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Cluster access verified"
kubectl cluster-info

# Check current context
print_info "Current cluster context:"
kubectl config current-context

# ============================================================================
# PHASE 2: MANIFEST VALIDATION
# ============================================================================

print_section "PHASE 2: Validating Manifests"

# Validate Helm chart
print_info "Validating Helm chart..."
if helm template test helm-chart >/dev/null 2>&1; then
    print_status "Helm chart validation passed"
else
    print_error "Helm chart validation failed"
    exit 1
fi

# Validate ArgoCD application
print_info "Validating ArgoCD application..."
if python3 -c "import yaml; yaml.safe_load(open('argocd/application.yaml'))" >/dev/null 2>&1; then
    print_status "ArgoCD application validation passed"
else
    print_error "ArgoCD application validation failed"
    exit 1
fi

# Validate all Kubernetes manifests
print_info "Validating Kubernetes manifests..."
for manifest in argocd/*.yaml deployment/production/*.yaml; do
    if [ -f "$manifest" ]; then
        if python3 -c "import yaml; list(yaml.safe_load_all(open('$manifest')))" >/dev/null 2>&1; then
            print_status "✓ $manifest validation passed"
        else
            print_error "✗ $manifest validation failed"
            exit 1
        fi
    fi
done

# ============================================================================
# PHASE 3: NAMESPACE CREATION
# ============================================================================

print_section "PHASE 3: Creating Namespaces"

# Create namespaces
print_info "Creating namespaces..."
kubectl apply -f deployment/production/01-namespace.yaml
print_status "Namespaces created successfully"

# Verify namespaces
print_info "Verifying namespaces..."
kubectl get namespaces | grep -E "(nativeseries|argocd|monitoring|logging)"

# ============================================================================
# PHASE 4: APPLICATION DEPLOYMENT
# ============================================================================

print_section "PHASE 4: Deploying NativeSeries Application"

# Deploy application using Helm
print_info "Deploying application using Helm..."
helm upgrade --install ${APP_NAME} helm-chart \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set image.repository=${DOCKER_IMAGE} \
    --set image.tag=latest \
    --set service.nodePort=${PRODUCTION_PORT} \
    --wait \
    --timeout=10m

print_status "Application deployed successfully"

# Verify application deployment
print_info "Verifying application deployment..."
kubectl get pods,services,ingress -n ${NAMESPACE}

# ============================================================================
# PHASE 5: ARGOCD DEPLOYMENT
# ============================================================================

print_section "PHASE 5: Deploying ArgoCD"

# Install ArgoCD
print_info "Installing ArgoCD..."
kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for ArgoCD to be ready
print_info "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE}

# Apply ArgoCD service
print_info "Applying ArgoCD service..."
kubectl apply -f deployment/production/04-argocd-service.yaml

print_status "ArgoCD deployed successfully"

# Verify ArgoCD deployment
print_info "Verifying ArgoCD deployment..."
kubectl get pods,services -n ${ARGOCD_NAMESPACE}

# ============================================================================
# PHASE 6: MONITORING AND LOGGING STACK
# ============================================================================

print_section "PHASE 6: Deploying Monitoring and Logging Stack"

# Deploy monitoring and logging stack
print_info "Deploying monitoring and logging stack..."
kubectl apply -f deployment/production/06-monitoring-stack.yaml

# Wait for monitoring components
print_info "Waiting for monitoring components..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n ${MONITORING_NAMESPACE} || true
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n ${MONITORING_NAMESPACE} || true

# Wait for logging components
print_info "Waiting for logging components..."
kubectl wait --for=condition=available --timeout=300s deployment/loki -n ${LOGGING_NAMESPACE} || true

print_status "Monitoring and logging stack deployed successfully"

# Verify monitoring deployment
print_info "Verifying monitoring deployment..."
kubectl get pods,services -n ${MONITORING_NAMESPACE}

# Verify logging deployment
print_info "Verifying logging deployment..."
kubectl get pods,services -n ${LOGGING_NAMESPACE}

# ============================================================================
# PHASE 7: ARGOCD APPLICATION
# ============================================================================

print_section "PHASE 7: Creating ArgoCD Application"

# Create ArgoCD application
print_info "Creating ArgoCD application..."
kubectl apply -f deployment/production/05-argocd-application.yaml

print_status "ArgoCD application created successfully"

# ============================================================================
# PHASE 8: VERIFICATION AND STATUS CHECKING
# ============================================================================

print_section "PHASE 8: Verification and Status Checking"

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label_selector=$2
    local timeout=300
    local interval=10
    
    print_info "Waiting for pods in namespace $namespace with selector $label_selector..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if kubectl get pods -n $namespace -l $label_selector --no-headers | grep -q "Running"; then
            local ready_pods=$(kubectl get pods -n $namespace -l $label_selector --no-headers | grep "Running" | wc -l)
            local total_pods=$(kubectl get pods -n $namespace -l $label_selector --no-headers | wc -l)
            if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
                print_status "All pods in $namespace are ready ($ready_pods/$total_pods)"
                return 0
            fi
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        print_info "Still waiting... ($elapsed/$timeout seconds elapsed)"
    done
    
    print_warning "Timeout waiting for pods in $namespace"
    return 1
}

# Function to check service endpoints
check_service_endpoints() {
    local namespace=$1
    local service_name=$2
    
    print_info "Checking service $service_name in namespace $namespace..."
    
    # Check if service exists
    if kubectl get service $service_name -n $namespace >/dev/null 2>&1; then
        print_status "✓ Service $service_name exists"
        
        # Check if endpoints are available
        local endpoints=$(kubectl get endpoints $service_name -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            print_status "✓ Service $service_name has endpoints: $endpoints"
            return 0
        else
            print_warning "⚠ Service $service_name has no endpoints yet"
            return 1
        fi
    else
        print_error "✗ Service $service_name not found"
        return 1
    fi
}

# Wait for all components to be ready
print_info "Waiting for all components to be ready..."

# Wait for application pods
wait_for_pods $NAMESPACE "app.kubernetes.io/name=$APP_NAME"

# Wait for ArgoCD pods
wait_for_pods $ARGOCD_NAMESPACE "app.kubernetes.io/name=argocd-server"

# Wait for monitoring pods
wait_for_pods $MONITORING_NAMESPACE "app=prometheus"
wait_for_pods $MONITORING_NAMESPACE "app=grafana"

# Wait for logging pods
wait_for_pods $LOGGING_NAMESPACE "app=loki"
wait_for_pods $LOGGING_NAMESPACE "app=promtail"

# Check all services
print_info "Verifying all services..."

# Application service
check_service_endpoints $NAMESPACE "${APP_NAME}-service"

# ArgoCD service
check_service_endpoints $ARGOCD_NAMESPACE "argocd-server-nodeport"

# Monitoring services
check_service_endpoints $MONITORING_NAMESPACE "prometheus-service"
check_service_endpoints $MONITORING_NAMESPACE "grafana-service"

# Logging services
check_service_endpoints $LOGGING_NAMESPACE "loki-service"

# ============================================================================
# PHASE 9: SHOW RUNNING STATUS
# ============================================================================

print_section "PHASE 9: Current Running Status"

# Show cluster status
print_info "Kubernetes Cluster Status:"
kubectl cluster-info

# Show all namespaces
print_info "All Namespaces:"
kubectl get namespaces

# Show application status
print_info "Application Status ($NAMESPACE namespace):"
kubectl get pods,services,ingress -n $NAMESPACE

# Show ArgoCD status
print_info "ArgoCD Status ($ARGOCD_NAMESPACE namespace):"
kubectl get pods,services -n $ARGOCD_NAMESPACE

# Show monitoring status
print_info "Monitoring Status ($MONITORING_NAMESPACE namespace):"
kubectl get pods,services -n $MONITORING_NAMESPACE

# Show logging status
print_info "Logging Status ($LOGGING_NAMESPACE namespace):"
kubectl get pods,services -n $LOGGING_NAMESPACE

# Show all services across namespaces
print_info "All Services (NodePort):"
kubectl get services --all-namespaces -o wide | grep NodePort

# Show resource usage
print_info "Resource Usage:"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
kubectl top pods --all-namespaces 2>/dev/null || print_warning "Pod metrics not available"

# ============================================================================
# PHASE 10: FINAL REPORT AND ACCESS LINKS
# ============================================================================

print_section "PHASE 10: Deployment Complete - Access Your NativeSeries Stack"

# Generate final deployment guide
cat > CLUSTER_DEPLOYMENT_GUIDE.md << EOF
# 🎉 NativeSeries - Cluster Deployment Summary

## ✅ Deployment Status: COMPLETE
**Target Server:** ${PRODUCTION_HOST}  
**Date:** $(date)

## 🌐 Access URLs

### 📱 NativeSeries Application
- **URL:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}
- **Health Check:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health
- **API Documentation:** http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs

### 🎯 ArgoCD GitOps Dashboard
- **URL:** http://${PRODUCTION_HOST}:${ARGOCD_PORT}
- **Username:** admin
- **Password:** Get with: \`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d\`

### 📊 Monitoring Stack
- **Grafana:** http://${PRODUCTION_HOST}:${GRAFANA_PORT} (admin/admin123)
- **Prometheus:** http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}

### 📝 Logging Stack
- **Loki:** http://${PRODUCTION_HOST}:${LOKI_PORT}
- **Grafana Logs:** Access through Grafana UI (Loki data source pre-configured)

## 📁 Deployed Resources
- **Application:** NativeSeries with Helm chart
- **GitOps:** ArgoCD for continuous deployment
- **Monitoring:** Prometheus + Grafana
- **Logging:** Loki + Promtail
- **Namespaces:** nativeseries, argocd, monitoring, logging

## 🎯 Next Steps
1. Access the application at http://${PRODUCTION_HOST}:${PRODUCTION_PORT}
2. Configure ArgoCD applications for GitOps
3. Set up monitoring dashboards in Grafana
4. Configure logging queries in Grafana with Loki
5. Configure CI/CD pipelines

Deployment completed successfully! 🎉
EOF

# Display final summary with access links
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 DEPLOYMENT COMPLETE! 🎉                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${WHITE}🌐 Your NativeSeries Stack is Ready! Access URLs:${NC}"
echo ""
echo -e "${CYAN}📱 NativeSeries Application:${NC}"
echo -e "${WHITE}   • Main App:     http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}   • Health Check: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health${NC}"
echo -e "${WHITE}   • API Docs:     http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs${NC}"
echo ""
echo -e "${CYAN}🎯 ArgoCD GitOps Dashboard:${NC}"
echo -e "${WHITE}   • URL:          http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}   • Username:     admin${NC}"
echo -e "${WHITE}   • Password:     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
echo ""
echo -e "${CYAN}📊 Monitoring Stack:${NC}"
echo -e "${WHITE}   • Grafana:      http://${PRODUCTION_HOST}:${GRAFANA_PORT} (admin/admin123)${NC}"
echo -e "${WHITE}   • Prometheus:   http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo ""
echo -e "${CYAN}📝 Logging Stack:${NC}"
echo -e "${WHITE}   • Loki:         http://${PRODUCTION_HOST}:${LOKI_PORT}${NC}"
echo -e "${WHITE}   • Grafana Logs: Access through Grafana UI (Loki data source pre-configured)${NC}"
echo ""

# Show current status summary
echo -e "${YELLOW}📊 Current Status Summary:${NC}"
echo -e "${WHITE}   • Application Pods: $(kubectl get pods -n $NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • ArgoCD Pods:     $(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $ARGOCD_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • Monitoring Pods: $(kubectl get pods -n $MONITORING_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $MONITORING_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo -e "${WHITE}   • Logging Pods:    $(kubectl get pods -n $LOGGING_NAMESPACE --no-headers | grep Running | wc -l | tr -d ' ')/$(kubectl get pods -n $LOGGING_NAMESPACE --no-headers | wc -l | tr -d ' ') running${NC}"
echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}📖 Full guide: CLUSTER_DEPLOYMENT_GUIDE.md${NC}"
echo ""

print_status "All resources deployed to NativeSeries cluster successfully!"
print_info "All services are now running and accessible!"