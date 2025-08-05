# Student Tracker - Complete Monitoring & Observability Setup

## Overview

This document describes the comprehensive monitoring, logging, and observability setup for the Student Tracker application. The setup includes:

- **Prometheus & Grafana** for metrics collection and visualization
- **Loki** for log aggregation and querying
- **Secrets & ConfigMaps** for secure configuration management
- **Horizontal Pod Autoscaler (HPA)** for automatic scaling
- **Pod Disruption Budget (PDB)** for high availability
- **Network Policies** for security
- **Custom Grafana Dashboards** for application monitoring

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Prometheus    │    │     Grafana     │
│   (nativeseries)│◄──►│   (Monitoring)  │◄──►│   (Dashboard)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      Loki       │    │  ServiceMonitor │    │  PrometheusRule│
│   (Logging)     │    │   (Metrics)     │    │   (Alerts)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Monitoring Stack (Prometheus + Grafana)

**Namespace:** `monitoring`

**Components:**
- Prometheus Operator
- Prometheus Server
- Grafana Dashboard
- ServiceMonitor for application metrics
- PodMonitor for pod-level metrics
- PrometheusRule for alerting

**Access URLs:**
- Grafana: `http://54.166.101.159:30081` (admin/admin123)
- Prometheus: `http://54.166.101.159:30082`

### 2. Logging Stack (Loki)

**Namespace:** `logging`

**Components:**
- Loki server for log aggregation
- Log forwarding from application pods
- Log querying and visualization in Grafana

**Access URL:**
- Loki: `http://54.166.101.159:30083`

### 3. Application Security & Configuration

**Secrets:**
- Database credentials (`nativeseries-db-secret`)
- API keys and JWT secrets (`nativeseries-api-secret`)

**ConfigMaps:**
- Application configuration (`nativeseries-config`)
- Logging configuration (`nativeseries-logging-config`)

### 4. Auto-scaling & High Availability

**Horizontal Pod Autoscaler:**
- Min replicas: 2
- Max replicas: 10
- CPU threshold: 70%
- Memory threshold: 80%

**Pod Disruption Budget:**
- Minimum available: 1 pod
- Ensures high availability during updates

### 5. Network Security

**Network Policies:**
- Ingress: Allow traffic from ingress-nginx and monitoring namespaces
- Egress: Allow database access and DNS resolution

## Installation

### Quick Start

Run the complete installation script:

```bash
./scripts/install-all.sh
```

This will install:
1. All required tools (Docker, kubectl, Helm, Kind, ArgoCD)
2. Kubernetes cluster with Kind
3. Application deployment
4. Monitoring stack (Prometheus + Grafana)
5. Logging stack (Loki)
6. Secrets and ConfigMaps
7. Auto-scaling configuration
8. Network policies

### Manual Installation

If you prefer to install components individually:

#### 1. Install Monitoring Stack

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30081 \
  --set grafana.adminPassword=admin123
```

#### 2. Install Logging Stack

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
  --set loki.persistence.size=10Gi
```

#### 3. Deploy Application with Monitoring

```bash
# Deploy the application with Helm
helm upgrade --install nativeseries ./helm-chart \
  --namespace nativeseries \
  --create-namespace \
  --set serviceMonitor.enabled=true \
  --set podMonitor.enabled=true \
  --set prometheusRules.enabled=true \
  --set hpa.enabled=true \
  --set podDisruptionBudget.enabled=true \
  --set networkPolicy.enabled=true
```

## Configuration

### Application Configuration

The application is configured through ConfigMaps and Secrets:

**ConfigMap (`nativeseries-config`):**
```yaml
data:
  app_name: "Student Tracker API"
  log_level: "INFO"
  environment: "production"
  max_connections: "100"
  timeout_seconds: "30"
  cache_ttl: "3600"
  cors_origins: "http://localhost:3000,http://54.166.101.159:30011"
```

**Secrets:**
- Database credentials (username, password, host, database name)
- API keys (JWT secret, session secret, API key)

### Monitoring Configuration

**ServiceMonitor:**
- Scrapes metrics from application pods
- Interval: 30 seconds
- Path: `/metrics`

**PrometheusRules:**
- Application down alert (critical)
- High CPU usage alert (warning)
- High memory usage alert (warning)

### Logging Configuration

**Log Format:**
```
%(asctime)s - %(name)s - %(levelname)s - %(message)s
```

**Log Rotation:**
- Max file size: 10MB
- Backup count: 5 files
- Log location: `/app/logs/app.log`

## Monitoring Dashboards

### Grafana Dashboards

**Application Dashboard:**
- Application health status
- CPU usage graphs
- Memory usage graphs
- HTTP request rate
- Error rate monitoring

**Access:**
- URL: `http://54.166.101.159:30081`
- Username: `admin`
- Password: `admin123`

### Prometheus Queries

**Key Metrics:**
```promql
# Application health
up{app="nativeseries"}

# CPU usage
rate(container_cpu_usage_seconds_total{container="nativeseries"}[5m])

# Memory usage
container_memory_usage_bytes{container="nativeseries"}

# HTTP requests
rate(http_requests_total{app="nativeseries"}[5m])
```

## Alerts

### Alert Rules

1. **AppDown** (Critical)
   - Trigger: Application pod down for > 1 minute
   - Severity: Critical

2. **HighCPUUsage** (Warning)
   - Trigger: CPU usage > 80% for 5 minutes
   - Severity: Warning

3. **HighMemoryUsage** (Warning)
   - Trigger: Memory usage > 80% for 5 minutes
   - Severity: Warning

### Alert Configuration

Alerts are configured in PrometheusRules and can be viewed in:
- Prometheus UI: `http://54.166.101.159:30082`
- Grafana Alerting: `http://54.166.101.159:30081/alerting`

## Scaling

### Horizontal Pod Autoscaler

**Configuration:**
```yaml
minReplicas: 2
maxReplicas: 10
targetCPUUtilizationPercentage: 70
targetMemoryUtilizationPercentage: 80
```

**Scaling Behavior:**
- Scale up: 100% increase or 4 pods max per 15 seconds
- Scale down: 10% decrease per 60 seconds
- Stabilization window: 60s (up), 300s (down)

### Load Testing

To test auto-scaling:

```bash
# Install hey (load testing tool)
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 50 http://54.166.101.159:30011/health
```

## Logging

### Log Aggregation

**Loki Configuration:**
- URL: `http://loki.logging:3100`
- Labels: `app=nativeseries`, `namespace=nativeseries`

**Log Queries:**
```logql
# Application logs
{app="nativeseries"}

# Error logs
{app="nativeseries"} |= "ERROR"

# Recent logs
{app="nativeseries"} [5m]
```

### Log Visualization

Logs can be viewed in Grafana:
1. Go to Grafana: `http://54.166.101.159:30081`
2. Add Loki as a data source
3. Create log queries and dashboards

## Security

### Network Policies

**Ingress Rules:**
- Allow traffic from ingress-nginx namespace
- Allow traffic from monitoring namespace
- Port: 8000 (application port)

**Egress Rules:**
- Allow database access (port 5432)
- Allow DNS resolution (port 53)

### Secrets Management

**Best Practices:**
- All secrets are base64 encoded
- Rotate secrets regularly in production
- Use external secret management (HashiCorp Vault) for production
- Never commit secrets to version control

## Troubleshooting

### Common Issues

1. **Prometheus not scraping metrics**
   ```bash
   kubectl get servicemonitors -n monitoring
   kubectl describe servicemonitor nativeseries-monitor -n monitoring
   ```

2. **Grafana not accessible**
   ```bash
   kubectl get svc -n monitoring
   kubectl port-forward svc/prometheus-grafana -n monitoring 8081:80
   ```

3. **HPA not scaling**
   ```bash
   kubectl get hpa -n nativeseries
   kubectl describe hpa nativeseries-hpa -n nativeseries
   ```

4. **Logs not appearing in Loki**
   ```bash
   kubectl get pods -n logging
   kubectl logs -f deployment/loki -n logging
   ```

### Useful Commands

```bash
# Check all components
kubectl get all -n nativeseries
kubectl get all -n monitoring
kubectl get all -n logging

# View application logs
kubectl logs -f deployment/nativeseries -n nativeseries

# Check HPA status
kubectl get hpa -n nativeseries

# Port forward for local access
kubectl port-forward svc/nativeseries -n nativeseries 8000:8000
kubectl port-forward svc/prometheus-grafana -n monitoring 8081:80
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 8082:9090
```

## Performance Tuning

### Resource Limits

**Current Configuration:**
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

**Recommendations:**
- Monitor actual usage and adjust limits
- Set requests to 50-70% of limits
- Use resource quotas for namespace limits

### Monitoring Tuning

**Prometheus Configuration:**
- Scrape interval: 30s
- Retention: 15 days
- Storage: 50Gi

**Grafana Configuration:**
- Dashboard refresh: 30s
- Query timeout: 30s
- Max concurrent queries: 10

## Next Steps

1. **Custom Dashboards**: Create application-specific dashboards
2. **Alert Channels**: Configure Slack/Email notifications
3. **Log Analysis**: Set up log parsing and alerting
4. **Performance Testing**: Implement load testing automation
5. **Security Hardening**: Implement RBAC and network policies
6. **Backup Strategy**: Set up monitoring data backup
7. **Multi-cluster**: Extend to multiple environments

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Kubernetes events: `kubectl get events -n nativeseries`
3. Check component logs: `kubectl logs -n <namespace> <pod-name>`
4. Verify Helm chart values: `helm get values nativeseries -n nativeseries`