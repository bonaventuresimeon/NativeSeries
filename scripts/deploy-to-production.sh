#!/bin/bash

# Production Deployment Script for 54.166.101.159
# Version: 1.0.0 - Complete deployment to production server

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

# Production Configuration
PRODUCTION_HOST="54.166.101.159"
PRODUCTION_PORT="30011"
ARGOCD_PORT="30080"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
DOCKER_IMAGE="ghcr.io/bonaventuresimeon/nativeseries"

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
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          🚀 Student Tracker - Production Deployment          ║"
echo "║              Target: ${PRODUCTION_HOST}:${PRODUCTION_PORT}                ║"
echo "║              Complete GitOps Stack Deployment               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_info "🎯 Production Configuration:"
print_info "  📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
print_info "  🎯 ArgoCD UI: http://${PRODUCTION_HOST}:${ARGOCD_PORT}"
print_info "  📊 Grafana: http://${PRODUCTION_HOST}:${GRAFANA_PORT}"
print_info "  📈 Prometheus: http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}"
print_info "  🐳 Docker Image: ${DOCKER_IMAGE}:latest"
print_info "  📁 Namespace: ${NAMESPACE}"
echo ""

# 1. Prepare Docker Image
print_section "🐳 Preparing Docker Image"

print_info "Building production Docker image..."
if docker build -t ${DOCKER_IMAGE}:latest . --network=host; then
    print_status "Docker image built successfully"
else
    print_error "Docker image build failed"
    exit 1
fi

print_info "Tagging image for production..."
docker tag ${DOCKER_IMAGE}:latest ${DOCKER_IMAGE}:v1.1.0
docker tag ${DOCKER_IMAGE}:latest ${APP_NAME}:latest

print_status "Docker images prepared for deployment"

# 2. Validate Helm Chart
print_section "⎈ Validating Helm Chart"

print_info "Linting Helm chart..."
if helm lint helm-chart; then
    print_status "Helm chart validation passed"
else
    print_error "Helm chart validation failed"
    exit 1
fi

print_info "Testing template rendering..."
if helm template ${APP_NAME} helm-chart --namespace ${NAMESPACE} > /tmp/rendered-manifests.yaml; then
    print_status "Helm templates render successfully"
    print_info "Rendered manifests saved to /tmp/rendered-manifests.yaml"
else
    print_error "Helm template rendering failed"
    exit 1
fi

# 3. Create Production Deployment Manifests
print_section "📄 Creating Production Deployment Manifests"

mkdir -p deployment/production

# Create namespace
cat <<EOF > deployment/production/01-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    name: ${NAMESPACE}
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging
    environment: production
EOF

# Create application deployment using Helm
helm template ${APP_NAME} helm-chart \
    --namespace ${NAMESPACE} \
    --set app.image.repository=${DOCKER_IMAGE} \
    --set app.image.tag=latest \
    --set service.nodePort=${PRODUCTION_PORT} \
    > deployment/production/02-application.yaml

print_status "Application manifests created"

# 4. Create ArgoCD Installation
print_section "🎯 Preparing ArgoCD Installation"

# Download ArgoCD installation manifests
curl -sSL -o deployment/production/03-argocd-install.yaml \
    "https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml"

# Create ArgoCD NodePort service
cat <<EOF > deployment/production/04-argocd-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-nodeport
  namespace: argocd
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
  - name: server
    port: 80
    protocol: TCP
    targetPort: 8080
    nodePort: ${ARGOCD_PORT}
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Create ArgoCD application
cat <<EOF > deployment/production/05-argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/bonaventuresimeon/nativeseries.git
    targetRevision: HEAD
    path: helm-chart
    helm:
      valueFiles:
        - values.yaml
      parameters:
        - name: app.image.repository
          value: ${DOCKER_IMAGE}
        - name: app.image.tag
          value: latest
        - name: service.nodePort
          value: "${PRODUCTION_PORT}"
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
EOF

print_status "ArgoCD configuration prepared"

# 5. Create Monitoring Stack
print_section "📊 Preparing Monitoring Stack"

# Create Prometheus and Grafana deployment
cat <<EOF > deployment/production/06-monitoring-stack.yaml
# Prometheus ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    rule_files:
      - "prometheus_rules.yml"
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: '${APP_NAME}'
        static_configs:
          - targets: ['${APP_NAME}.${NAMESPACE}.svc.cluster.local:8000']
        metrics_path: '/metrics'
        scrape_interval: 30s
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
---
# Prometheus Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=200h'
          - '--web.enable-lifecycle'
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
---
# Prometheus Service
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: ${PROMETHEUS_PORT}
  selector:
    app: prometheus
---
# Grafana Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
---
# Grafana Service
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: ${GRAFANA_PORT}
  selector:
    app: grafana
EOF

print_status "Monitoring stack configuration prepared"

# 6. Create Deployment Scripts
print_section "📜 Creating Deployment Scripts"

# Create deploy script
cat <<EOF > deployment/deploy.sh
#!/bin/bash

# Production Deployment Script
set -e

echo "🚀 Deploying Student Tracker to ${PRODUCTION_HOST}"

# Apply manifests in order
echo "📁 Creating namespaces..."
kubectl apply -f production/01-namespace.yaml

echo "📱 Deploying application..."
kubectl apply -f production/02-application.yaml

echo "🎯 Installing ArgoCD..."
kubectl apply -f production/03-argocd-install.yaml
kubectl apply -f production/04-argocd-service.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🎯 Creating ArgoCD application..."
kubectl apply -f production/05-argocd-application.yaml

echo "📊 Installing monitoring stack..."
kubectl apply -f production/06-monitoring-stack.yaml

echo "✅ Deployment complete!"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Application: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
echo "  🎯 ArgoCD: http://${PRODUCTION_HOST}:${ARGOCD_PORT}"
echo "  📊 Grafana: http://${PRODUCTION_HOST}:${GRAFANA_PORT}"
echo "  📈 Prometheus: http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}"
echo ""
echo "🔑 Default Credentials:"
echo "  ArgoCD: admin / \$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo "  Grafana: admin / admin123"
EOF

chmod +x deployment/deploy.sh

# Create status check script
cat <<EOF > deployment/check-status.sh
#!/bin/bash

echo "🔍 Checking deployment status on ${PRODUCTION_HOST}"
echo ""

echo "📱 Application Status:"
kubectl get pods,svc -n ${NAMESPACE}
echo ""

echo "🎯 ArgoCD Status:"
kubectl get pods,svc -n argocd
echo ""

echo "📊 Monitoring Status:"
kubectl get pods,svc -n monitoring
echo ""

echo "🌐 Testing endpoints:"
echo "  📱 Application health: \$(curl -s http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health | jq -r .status 2>/dev/null || echo 'Not accessible')"
echo "  🎯 ArgoCD: \$(curl -s -o /dev/null -w '%{http_code}' http://${PRODUCTION_HOST}:${ARGOCD_PORT} 2>/dev/null || echo 'Not accessible')"
echo "  📊 Grafana: \$(curl -s -o /dev/null -w '%{http_code}' http://${PRODUCTION_HOST}:${GRAFANA_PORT} 2>/dev/null || echo 'Not accessible')"
echo "  📈 Prometheus: \$(curl -s -o /dev/null -w '%{http_code}' http://${PRODUCTION_HOST}:${PROMETHEUS_PORT} 2>/dev/null || echo 'Not accessible')"
EOF

chmod +x deployment/check-status.sh

print_status "Deployment scripts created"

# 7. Create Docker Push Script
print_section "🐳 Creating Docker Push Script"

cat <<EOF > deployment/push-images.sh
#!/bin/bash

# Docker Image Push Script
set -e

echo "🐳 Pushing Docker images to registry..."

# Login to GitHub Container Registry (requires token)
# echo \$GITHUB_TOKEN | docker login ghcr.io -u \$GITHUB_USERNAME --password-stdin

# Push images
echo "📤 Pushing ${DOCKER_IMAGE}:latest..."
docker push ${DOCKER_IMAGE}:latest

echo "📤 Pushing ${DOCKER_IMAGE}:v1.1.0..."
docker push ${DOCKER_IMAGE}:v1.1.0

echo "✅ Images pushed successfully!"
EOF

chmod +x deployment/push-images.sh

print_status "Docker push script created"

# 8. Create Complete Installation Guide
print_section "📚 Creating Installation Guide"

cat <<EOF > deployment/DEPLOYMENT_GUIDE.md
# 🚀 Student Tracker Production Deployment Guide

## Target Environment
- **Server**: ${PRODUCTION_HOST}
- **Application Port**: ${PRODUCTION_PORT}
- **ArgoCD Port**: ${ARGOCD_PORT}
- **Grafana Port**: ${GRAFANA_PORT}
- **Prometheus Port**: ${PROMETHEUS_PORT}

## Prerequisites
1. Kubernetes cluster accessible via kubectl
2. Helm 3.x installed
3. Docker registry access (GitHub Container Registry)
4. kubectl configured to access the target cluster

## Deployment Steps

### 1. Push Docker Images (Optional)
\`\`\`bash
cd deployment
./push-images.sh
\`\`\`

### 2. Deploy to Kubernetes
\`\`\`bash
cd deployment
./deploy.sh
\`\`\`

### 3. Check Deployment Status
\`\`\`bash
cd deployment
./check-status.sh
\`\`\`

## Access Information

### Application
- **URL**: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}
- **Health Check**: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/health
- **API Docs**: http://${PRODUCTION_HOST}:${PRODUCTION_PORT}/docs

### ArgoCD
- **URL**: http://${PRODUCTION_HOST}:${ARGOCD_PORT}
- **Username**: admin
- **Password**: Get with: \`kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d\`

### Grafana
- **URL**: http://${PRODUCTION_HOST}:${GRAFANA_PORT}
- **Username**: admin
- **Password**: admin123

### Prometheus
- **URL**: http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}

## Manual Deployment Commands

If you prefer manual deployment:

\`\`\`bash
# 1. Create namespaces
kubectl apply -f production/01-namespace.yaml

# 2. Deploy application
kubectl apply -f production/02-application.yaml

# 3. Install ArgoCD
kubectl apply -f production/03-argocd-install.yaml
kubectl apply -f production/04-argocd-service.yaml

# 4. Wait for ArgoCD
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 5. Create ArgoCD application
kubectl apply -f production/05-argocd-application.yaml

# 6. Install monitoring
kubectl apply -f production/06-monitoring-stack.yaml
\`\`\`

## Troubleshooting

### Check Pod Status
\`\`\`bash
kubectl get pods -n ${NAMESPACE}
kubectl get pods -n argocd
kubectl get pods -n monitoring
\`\`\`

### Check Logs
\`\`\`bash
kubectl logs -f deployment/${APP_NAME} -n ${NAMESPACE}
kubectl logs -f deployment/argocd-server -n argocd
\`\`\`

### Port Forward for Local Access
\`\`\`bash
kubectl port-forward svc/${APP_NAME} -n ${NAMESPACE} 8000:8000
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/grafana -n monitoring 3000:3000
\`\`\`

## Security Notes
- Change default passwords in production
- Configure proper RBAC
- Enable TLS/SSL certificates
- Set up proper secrets management
- Configure network policies

## Monitoring
- Prometheus scrapes metrics from the application
- Grafana provides visualization dashboards
- ArgoCD provides GitOps deployment status
- Application health endpoint: /health

## Scaling
- HPA is configured for auto-scaling based on CPU/memory
- Adjust replica counts in helm-chart/values.yaml
- Monitor resource usage via Grafana dashboards

---
Generated on $(date) for deployment to ${PRODUCTION_HOST}
EOF

print_status "Installation guide created"

# Final Summary
print_section "🎉 Deployment Package Ready"

echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                    DEPLOYMENT PACKAGE READY                    ║${NC}"
echo -e "${WHITE}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${WHITE}║${NC} Target Server:    ${CYAN}${PRODUCTION_HOST}${NC}"
echo -e "${WHITE}║${NC} Application:      ${CYAN}http://${PRODUCTION_HOST}:${PRODUCTION_PORT}${NC}"
echo -e "${WHITE}║${NC} ArgoCD:          ${CYAN}http://${PRODUCTION_HOST}:${ARGOCD_PORT}${NC}"
echo -e "${WHITE}║${NC} Grafana:         ${CYAN}http://${PRODUCTION_HOST}:${GRAFANA_PORT}${NC}"
echo -e "${WHITE}║${NC} Prometheus:      ${CYAN}http://${PRODUCTION_HOST}:${PROMETHEUS_PORT}${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"

echo ""
print_status "✅ Docker image built and ready"
print_status "✅ Helm chart validated and templates rendered"
print_status "✅ Kubernetes manifests generated"
print_status "✅ ArgoCD configuration prepared"
print_status "✅ Monitoring stack configured"
print_status "✅ Deployment scripts created"
print_status "✅ Installation guide generated"

echo ""
print_info "📁 Deployment files created in: ./deployment/"
print_info "📚 Read deployment/DEPLOYMENT_GUIDE.md for detailed instructions"
print_info "🚀 Run './deployment/deploy.sh' on your Kubernetes cluster to deploy"

echo ""
print_warning "⚠️  Important Notes:"
print_warning "  • Ensure kubectl is configured for your target cluster"
print_warning "  • Push Docker images to registry before deployment"
print_warning "  • Change default passwords in production"
print_warning "  • Configure proper DNS/Load Balancer for ${PRODUCTION_HOST}"

echo ""
print_status "🎯 Ready for deployment to ${PRODUCTION_HOST}!"