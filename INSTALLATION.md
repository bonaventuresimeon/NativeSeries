# NativeSeries - Complete Installation Guide

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Monitoring & Observability](#monitoring--observability)
- [Security & Auto-scaling](#security--auto-scaling)
- [Verification](#verification)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## 🎯 Overview

This guide provides comprehensive instructions for installing and deploying the NativeSeries application with full monitoring, logging, security, and auto-scaling capabilities. The application is designed to be deployed using modern cloud-native practices with Docker, Kubernetes, and GitOps.

### What You'll Get

- ✅ **FastAPI Application**: Modern Python web framework
- ✅ **Docker Containerization**: Portable and scalable deployment
- ✅ **Kubernetes Orchestration**: Production-ready container orchestration
- ✅ **ArgoCD GitOps**: Automated deployment and management
- ✅ **GitHub Actions CI/CD**: Automated testing and deployment
- ✅ **Prometheus & Grafana**: Complete monitoring stack
- ✅ **Loki Logging**: Centralized log aggregation
- ✅ **Secrets & ConfigMaps**: Secure configuration management
- ✅ **Horizontal Pod Autoscaler**: Automatic scaling based on CPU/memory
- ✅ **Pod Disruption Budget**: High availability during updates
- ✅ **Network Policies**: Security and traffic control
- ✅ **Custom Dashboards**: Application-specific monitoring
- ✅ **Alerting**: Prometheus-based alerting system

## 🔧 Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, Amazon Linux 2)
- **Memory**: Minimum 8GB RAM (16GB recommended for monitoring stack)
- **Storage**: Minimum 50GB free space (for monitoring data)
- **Network**: Internet connection for downloading dependencies

### Required Tools

- **Python**: 3.11 or higher
- **Docker**: 20.10 or higher
- **kubectl**: 1.28 or higher
- **Helm**: 3.13 or higher
- **Kind**: 0.20.0 or higher (for local Kubernetes)
- **ArgoCD CLI**: 2.9.3 or higher

## 🚀 Quick Installation

### Option 1: Automated Installation Script (Recommended)

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Run the automated installation script
chmod +x scripts/install-all.sh
./scripts/install-all.sh
```

This script will install:
1. All required tools (Docker, kubectl, Helm, Kind, ArgoCD)
2. Kubernetes cluster with Kind
3. Application deployment
4. **Monitoring stack (Prometheus + Grafana)**
5. **Logging stack (Loki)**
6. **Secrets and ConfigMaps**
7. **Auto-scaling configuration (HPA)**
8. **Network policies and security**

### Option 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Install Python dependencies
pip install -r requirements.txt

# Build Docker image
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .

# Run locally
docker run -p 8000:8000 ghcr.io/bonaventuresimeon/nativeseries:latest
```

## 📖 Detailed Installation

### Step 1: Environment Setup

#### Install Python 3.11

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install python3.11 python3.11-pip python3.11-venv
```

**CentOS/RHEL/Amazon Linux:**
```bash
sudo yum update -y
sudo yum install python3.11 python3.11-pip
```

**macOS:**
```bash
brew install python@3.11
```

#### Install Docker

```bash
# Download and run Docker installation script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
```

#### Install Kubernetes Tools

**Install kubectl:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**Install Helm:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**Install Kind (for local Kubernetes):**
```bash
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
kind version
```

**Install ArgoCD CLI:**
```bash
curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/v2.9.3/argocd-linux-amd64"
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client
```

### Step 2: Application Setup

#### Clone Repository

```bash
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries
```

#### Create Virtual Environment

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
```

#### Install Dependencies

```bash
pip install -r requirements.txt
```

#### Verify Installation

```bash
# Test Python imports
python -c "import fastapi, uvicorn, motor; print('✅ Dependencies installed successfully')"

# Test application startup
python -c "from app.main import app; print('✅ Application imports successfully')"
```

### Step 3: Docker Setup

#### Build Docker Image

```bash
# Build the application image
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .

# Verify the image was created
docker images | grep nativeseries
```

#### Test Docker Container

```bash
# Run the container
docker run -d --name native-series-test -p 8000:8000 ghcr.io/bonaventuresimeon/nativeseries:latest

# Wait for startup
sleep 10

# Test health endpoint
curl -f http://localhost:8000/health

# Stop and remove test container
docker stop native-series-test
docker rm native-series-test
```

### Step 4: Kubernetes Setup

#### Create Local Cluster (Kind)

```bash
# Create Kind cluster configuration with monitoring ports
cat <<EOF > kind-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: native-series-cluster
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
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30011
    hostPort: 30011
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30081
    hostPort: 30081
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30082
    hostPort: 30082
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 30083
    hostPort: 30083
    protocol: TCP
    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF

# Create the cluster
kind create cluster --config kind-cluster-config.yaml

# Verify cluster is ready
kubectl cluster-info
kubectl get nodes
```

#### Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Configure ArgoCD for insecure access
kubectl patch deployment argocd-server -n argocd -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' --type=json

# Create NodePort service for external access
cat <<EOF | kubectl apply -f -
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
    nodePort: 30080
  selector:
    app.kubernetes.io/name: argocd-server
EOF

# Get admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
echo "$ARGOCD_PASSWORD" > .argocd-password

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo "ArgoCD UI: http://localhost:30080"
echo "Username: admin"
```

### Step 5: Application Deployment

#### Deploy with Helm

```bash
# Create namespace
kubectl create namespace nativeseries

# Deploy application with all features
helm upgrade --install nativeseries helm-chart \
  --namespace nativeseries \
  --create-namespace \
  --wait \
  --timeout=300s \
  --set image.repository="ghcr.io/bonaventuresimeon/nativeseries" \
  --set image.tag="latest" \
  --set serviceMonitor.enabled=true \
  --set podMonitor.enabled=true \
  --set prometheusRules.enabled=true \
  --set hpa.enabled=true \
  --set podDisruptionBudget.enabled=true \
  --set networkPolicy.enabled=true
```

#### Deploy with ArgoCD

```bash
# Apply ArgoCD application
kubectl apply -f argocd/application.yaml

# Check application status
kubectl get applications -n argocd

# Sync application
argocd app sync nativeseries --server localhost:30080 --username admin --password "$(cat .argocd-password)" --insecure
```

## 📊 Monitoring & Observability

### Step 6: Install Monitoring Stack

#### Install Prometheus and Grafana

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.probeSelectorNilUsesHelmValues=false \
  --set grafana.enabled=true \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30081 \
  --set grafana.adminPassword=admin123 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30082 \
  --wait \
  --timeout=600s

# Wait for monitoring stack to be ready
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-grafana -n monitoring
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-kube-prometheus-operator -n monitoring
```

#### Install Loki for Logging

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki Stack
helm upgrade --install loki grafana/loki-stack \
  --namespace logging \
  --create-namespace \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.service.type=NodePort \
  --set loki.service.nodePort=30083 \
  --wait \
  --timeout=600s

# Wait for Loki to be ready
kubectl wait --for=condition=available --timeout=300s deployment/loki -n logging
```

### Step 7: Configure Application Monitoring

#### Create ServiceMonitor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nativeseries-monitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: nativeseries
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
EOF
```

#### Create PodMonitor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: nativeseries-pod-monitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: nativeseries
  podMetricsEndpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
EOF
```

#### Create PrometheusRules for Alerts

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: nativeseries-alerts
  namespace: monitoring
  labels:
    release: prometheus
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: nativeseries-alerts
    rules:
    - alert: AppDown
      expr: up{app="nativeseries"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Application {{ \$labels.app }} is down"
        description: "Application {{ \$labels.app }} has been down for more than 1 minute"
    
    - alert: HighCPUUsage
      expr: rate(container_cpu_usage_seconds_total{container="nativeseries"}[5m]) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage for {{ \$labels.app }}"
        description: "CPU usage is above 80% for {{ \$labels.app }}"
    
    - alert: HighMemoryUsage
      expr: (container_memory_usage_bytes{container="nativeseries"} / container_spec_memory_limit_bytes{container="nativeseries"}) > 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage for {{ \$labels.app }}"
        description: "Memory usage is above 80% for {{ \$labels.app }}"
EOF
```

### Step 8: Create Grafana Dashboard

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nativeseries-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  app-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Student Tracker Application",
        "tags": ["student-tracker", "application"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Application Health",
            "type": "stat",
            "targets": [
              {
                "expr": "up{app=\"nativeseries\"}",
                "legendFormat": "{{pod}}"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "thresholds"
                },
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": 0},
                    {"color": "green", "value": 1}
                  ]
                }
              }
            }
          },
          {
            "id": 2,
            "title": "CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{container=\"nativeseries\"}[5m])",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "container_memory_usage_bytes{container=\"nativeseries\"}",
                "legendFormat": "{{pod}}"
              }
            ]
          },
          {
            "id": 4,
            "title": "HTTP Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{app=\"nativeseries\"}[5m])",
                "legendFormat": "{{method}} {{endpoint}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF
```

## 🔐 Security & Auto-scaling

### Step 9: Setup Secrets and ConfigMaps

#### Create Application Secrets

```bash
# Create database secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: nativeseries-db-secret
  namespace: nativeseries
type: Opaque
data:
  db-username: $(echo -n "student_user" | base64)
  db-password: $(echo -n "secure_password_123" | base64)
  db-host: $(echo -n "postgres-service" | base64)
  db-name: $(echo -n "studentdb" | base64)
EOF

# Create API secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: nativeseries-api-secret
  namespace: nativeseries
type: Opaque
data:
  api-key: $(echo -n "your-super-secret-api-key-2024" | base64)
  jwt-secret: $(echo -n "your-jwt-secret-key-2024" | base64)
  session-secret: $(echo -n "your-session-secret-key-2024" | base64)
EOF
```

#### Create Application ConfigMaps

```bash
# Create application configmap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nativeseries-config
  namespace: nativeseries
data:
  app_name: "Student Tracker API"
  log_level: "INFO"
  environment: "production"
  max_connections: "100"
  timeout_seconds: "30"
  cache_ttl: "3600"
  cors_origins: "http://localhost:3000,http://54.166.101.159:30011"
EOF

# Create logging configmap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nativeseries-logging-config
  namespace: nativeseries
data:
  log-config.yaml: |
    version: 1
    formatters:
      simple:
        format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    handlers:
      console:
        class: logging.StreamHandler
        level: INFO
        formatter: simple
        stream: ext://sys.stdout
      file:
        class: logging.handlers.RotatingFileHandler
        level: INFO
        formatter: simple
        filename: /app/logs/app.log
        maxBytes: 10485760
        backupCount: 5
    loggers:
      app:
        level: INFO
        handlers: [console, file]
        propagate: false
    root:
      level: INFO
      handlers: [console]
EOF
```

### Step 10: Setup Auto-scaling

#### Create Horizontal Pod Autoscaler

```bash
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nativeseries-hpa
  namespace: nativeseries
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nativeseries
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
EOF
```

#### Create Pod Disruption Budget

```bash
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nativeseries-pdb
  namespace: nativeseries
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nativeseries
EOF
```

### Step 11: Setup Network Security

#### Create Network Policies

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nativeseries-network-policy
  namespace: nativeseries
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: nativeseries
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: nativeseries
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Application Configuration
ENVIRONMENT=production
DEBUG=false
HOST=0.0.0.0
PORT=8000

# Database Configuration
MONGO_URI=mongodb://localhost:27017
DATABASE_NAME=student_project_tracker
COLLECTION_NAME=students

# Vault Configuration (optional)
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=your-role-id
VAULT_SECRET_ID=your-secret-id

# Redis Configuration (optional)
REDIS_URL=redis://localhost:6379

# Production Configuration
PRODUCTION_HOST=54.166.101.159
PRODUCTION_PORT=30011

# Monitoring Configuration
GRAFANA_PORT=30081
PROMETHEUS_PORT=30082
LOKI_PORT=30083
```

### Helm Chart Configuration

Edit `helm-chart/values.yaml`:

```yaml
# Application configuration
app:
  name: nativeseries
  image:
    repository: ghcr.io/bonaventuresimeon/nativeseries
    tag: latest
    pullPolicy: IfNotPresent

# Service configuration
service:
  type: NodePort
  port: 8000
  targetPort: 8000
  nodePort: 30011

# Resource limits
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Health checks
healthCheck:
  enabled: true
  path: /health
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

# Secrets and ConfigMaps
secrets:
  enabled: true
  dbSecret:
    name: nativeseries-db-secret
  apiSecret:
    name: nativeseries-api-secret

configMaps:
  enabled: true
  appConfig:
    name: nativeseries-config
  loggingConfig:
    name: nativeseries-logging-config

# Horizontal Pod Autoscaler
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Network Policies
networkPolicy:
  enabled: true

# Service monitor for Prometheus
serviceMonitor:
  enabled: true
  interval: 30s
  path: /metrics
  labels:
    release: prometheus

# Pod monitor for Prometheus
podMonitor:
  enabled: true
  interval: 30s
  path: /metrics
  labels:
    release: prometheus

# Prometheus Rules for alerts
prometheusRules:
  enabled: true

# Logging configuration
logging:
  enabled: true
  loki:
    enabled: true
    url: "http://loki.logging:3100"
  volume:
    enabled: true
    size: 1Gi
    mountPath: /app/logs
```

## 🚀 Deployment

### Local Development Deployment

```bash
# Start the application locally
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Docker Deployment

```bash
# Build and run with Docker
docker build -t ghcr.io/bonaventuresimeon/nativeseries:latest .
docker run -d --name native-series -p 30011:8000 ghcr.io/bonaventuresimeon/nativeseries:latest
```

### Kubernetes Deployment

```bash
# Deploy to Kubernetes with all features
helm upgrade --install nativeseries helm-chart \
  --namespace nativeseries \
  --create-namespace \
  --set serviceMonitor.enabled=true \
  --set podMonitor.enabled=true \
  --set prometheusRules.enabled=true \
  --set hpa.enabled=true \
  --set podDisruptionBudget.enabled=true \
  --set networkPolicy.enabled=true
```

### Production Deployment

```bash
# Use the deployment script
chmod +x scripts/deploy.sh
./scripts/deploy.sh --deploy-prod
```

## ✅ Verification

### Health Checks

```bash
# Check application health
curl -f http://localhost:8000/health

# Check Kubernetes pods
kubectl get pods -n nativeseries

# Check ArgoCD status
kubectl get applications -n argocd

# Check monitoring stack
kubectl get pods -n monitoring

# Check logging stack
kubectl get pods -n logging
```

### Monitoring Verification

```bash
# Check ServiceMonitor
kubectl get servicemonitors -n monitoring

# Check PrometheusRules
kubectl get prometheusrules -n monitoring

# Check HPA status
kubectl get hpa -n nativeseries

# Check secrets and configmaps
kubectl get secrets,configmaps -n nativeseries
```

### Smoke Tests

```bash
# Run smoke tests
chmod +x scripts/smoke-tests.sh
./scripts/smoke-tests.sh http://localhost:8000
```

### Test Monitoring Setup

```bash
# Run comprehensive monitoring tests
chmod +x scripts/test-monitoring.sh
./scripts/test-monitoring.sh
```

### Access URLs

- **Application**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health
- **ArgoCD UI**: http://localhost:30080
- **Grafana Dashboard**: http://localhost:30081 (admin/admin123)
- **Prometheus**: http://localhost:30082
- **Loki Logs**: http://localhost:30083

## 🧪 Testing

### Load Testing for Auto-scaling

```bash
# Install hey (load testing tool)
go install github.com/rakyll/hey@latest

# Run load test to trigger auto-scaling
hey -n 1000 -c 50 http://localhost:8000/health

# Monitor HPA during test
kubectl get hpa -n nativeseries -w
```

### Monitoring Dashboard Testing

```bash
# Port forward Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 8081:80

# Access Grafana at http://localhost:8081
# Username: admin
# Password: admin123
```

### Log Testing

```bash
# Generate some application logs
curl http://localhost:8000/health
curl http://localhost:8000/docs

# View application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# Check Loki logs (if configured)
kubectl port-forward svc/loki -n logging 8083:3100
```

## 🔍 Troubleshooting

### Common Issues

#### Docker Issues

**Permission Denied:**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Docker Daemon Not Running:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### Kubernetes Issues

**Cluster Not Ready:**
```bash
kubectl cluster-info
kubectl get nodes
```

**Pods Not Starting:**
```bash
kubectl describe pod <pod-name> -n nativeseries
kubectl logs <pod-name> -n nativeseries
```

#### Monitoring Issues

**Prometheus not scraping metrics:**
```bash
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor nativeseries-monitor -n monitoring
```

**Grafana not accessible:**
```bash
kubectl get svc -n monitoring
kubectl port-forward svc/prometheus-grafana -n monitoring 8081:80
```

**HPA not scaling:**
```bash
kubectl get hpa -n nativeseries
kubectl describe hpa nativeseries-hpa -n nativeseries
```

#### ArgoCD Issues

**Application Not Syncing:**
```bash
kubectl get applications -n argocd
argocd app get nativeseries
argocd app sync nativeseries --force
```

**Cannot Access ArgoCD UI:**
```bash
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

### Logs and Debugging

```bash
# Application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd

# Monitoring logs
kubectl logs -f deployment/prometheus-grafana -n monitoring

# Logging logs
kubectl logs -f deployment/loki -n logging

# Docker logs
docker logs -f native-series
```

### Reset Installation

```bash
# Stop all processes
chmod +x scripts/stop-installation.sh
./scripts/stop-installation.sh

# Clean up Kubernetes
kubectl delete namespace nativeseries
kubectl delete namespace argocd
kubectl delete namespace monitoring
kubectl delete namespace logging

# Clean up Docker
docker system prune -af

# Remove Kind cluster
kind delete cluster --name native-series-cluster
```

## 🎯 Next Steps

### Immediate Actions

1. **Test the Application**
   - Visit http://localhost:8000
   - Explore API documentation at http://localhost:8000/docs
   - Run health checks

2. **Explore Monitoring**
   - Access Grafana at http://localhost:30081
   - View application dashboards
   - Check Prometheus metrics at http://localhost:30082

3. **Test Auto-scaling**
   - Run load tests to trigger HPA
   - Monitor scaling behavior
   - Verify resource usage

4. **Review Logs**
   - Check application logs in Grafana
   - Query logs in Loki
   - Set up log-based alerts

### Production Considerations

1. **Security**
   - Configure SSL/TLS certificates
   - Set up proper authentication
   - Implement RBAC policies
   - Rotate secrets regularly

2. **Scalability**
   - Fine-tune HPA parameters
   - Set up load balancing
   - Optimize resource limits
   - Implement custom metrics

3. **Backup and Recovery**
   - Set up database backups
   - Configure monitoring data backup
   - Test disaster recovery procedures

### Advanced Features

1. **Custom Dashboards**
   - Create application-specific dashboards
   - Add business metrics
   - Configure custom alerts

2. **Alert Channels**
   - Configure Slack notifications
   - Set up email alerts
   - Implement PagerDuty integration

3. **Performance Optimization**
   - Fine-tune resource limits
   - Optimize application performance
   - Implement caching strategies

4. **Multi-environment Setup**
   - Set up staging environment
   - Configure production deployment
   - Implement environment-specific configs

## 📞 Support

### Getting Help

- **Documentation**: Check this guide and the main README
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions
- **Email**: contact@bonaventure.org.ng

### Useful Commands

```bash
# Check application status
kubectl get all -n nativeseries

# View application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# Check monitoring status
kubectl get all -n monitoring
kubectl get all -n logging

# Check HPA status
kubectl get hpa -n nativeseries

# Port forward for local access
kubectl port-forward svc/nativeseries -n nativeseries 8000:80
kubectl port-forward svc/prometheus-grafana -n monitoring 8081:80
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 8082:9090

# Access ArgoCD locally
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

### Scripts Directory

All installation and deployment scripts are located in the `scripts/` directory:

- **`scripts/install-all.sh`**: Complete automated installation with monitoring
- **`scripts/deploy.sh`**: Production deployment script
- **`scripts/deploy-simple.sh`**: Simplified deployment for CI/CD
- **`scripts/stop-installation.sh`**: Stop all installation processes
- **`scripts/smoke-tests.sh`**: Health check and smoke tests
- **`scripts/test-monitoring.sh`**: Comprehensive monitoring tests
- **`scripts/get-docker.sh`**: Docker installation script
- **`scripts/setup-argocd.sh`**: ArgoCD setup script
- **`scripts/cleanup.sh`**: Cleanup and reset script
- **`scripts/backup-before-cleanup.sh`**: Backup before cleanup

### Quick Reference

```bash
# Quick start with all features
./scripts/install-all.sh

# Deploy to production
./scripts/deploy.sh

# Test monitoring setup
./scripts/test-monitoring.sh

# Stop installation
./scripts/stop-installation.sh

# Run tests
./scripts/smoke-tests.sh http://localhost:8000

# Cleanup everything
./scripts/cleanup.sh
```

## 🎓 Learning Outcomes

### Students will learn:
1. **Kubernetes deployment**: Complete application deployment
2. **Monitoring setup**: Prometheus and Grafana configuration
3. **Logging implementation**: Loki log aggregation
4. **Security practices**: Secrets and network policies
5. **Auto-scaling**: HPA configuration and testing
6. **GitOps**: ArgoCD for continuous deployment
7. **Observability**: Full-stack monitoring and alerting

### Portfolio Ready Features:
- ✅ Complete CI/CD pipeline
- ✅ GitOps implementation with ArgoCD
- ✅ Monitoring and observability stack
- ✅ Auto-scaling and high availability
- ✅ Security best practices
- ✅ Production-ready configuration
- ✅ Comprehensive documentation

---

**🎉 Congratulations! Your NativeSeries application is now installed with full monitoring, logging, security, and auto-scaling capabilities!**

For more information, visit: https://github.com/bonaventuresimeon/NativeSeries