# NativeSeries Deployment Guide

## Overview
This document describes the complete deployment setup for NativeSeries application with ArgoCD GitOps and comprehensive monitoring.

## Files Created/Updated

### 1. GitHub Actions Workflow with ArgoCD Integration
**File:** `.github/workflows/nativeseries.yml`

**Features:**
- ✅ Complete CI/CD pipeline with ArgoCD integration
- ✅ Tests application on every push/PR
- ✅ Builds Docker image on main branch
- ✅ Pushes to GitHub Container Registry
- ✅ Deploys to Kubernetes via ArgoCD
- ✅ Deploys monitoring stack (Prometheus, Grafana, Loki)
- ✅ Comprehensive deployment verification

**Pipeline Jobs:**
1. **Test:** Runs pytest on the application
2. **Build:** Creates and pushes Docker image
3. **Deploy ArgoCD:** Installs and configures ArgoCD
4. **Deploy Monitoring:** Deploys monitoring stack
5. **Verify:** Validates all deployments
6. **Notify:** Provides deployment summary

### 2. Netlify Configuration
**File:** `netlify.toml`

**Features:**
- ✅ Simple build configuration
- ✅ API redirects for FastAPI endpoints
- ✅ Security headers
- ✅ Development server configuration
- ✅ No complex environment variables

**Key Endpoints:**
- `/api/*` → Netlify Functions
- `/health` → Health check
- `/docs` → API documentation
- `/*` → SPA fallback

### 3. Build Script
**File:** `build.sh`

**Features:**
- ✅ Creates necessary directories
- ✅ Generates static files if missing
- ✅ Sets up health check function
- ✅ Simple error handling

### 4. Monitoring Stack
**File:** `deployment/production/06-monitoring-stack.yaml`

**Components:**
- ✅ **Prometheus:** Metrics collection and storage
- ✅ **Grafana:** Visualization and dashboards
- ✅ **Loki:** Log aggregation and querying
- ✅ **Promtail:** Log collection agent

## Deployment Process

### GitHub Actions (Docker + ArgoCD)
1. **Test:** Runs pytest on the application
2. **Build:** Creates Docker image with tag `latest`
3. **Push:** Uploads to `ghcr.io/bonaventuresimeon/nativeseries:latest`
4. **Deploy ArgoCD:** Installs ArgoCD and deploys application
5. **Deploy Monitoring:** Deploys Prometheus, Grafana, and Loki
6. **Verify:** Validates all services are running
7. **Notify:** Provides deployment summary

### Netlify (Serverless)
1. **Build:** Runs `./build.sh` script
2. **Publish:** Serves files from `public/` directory
3. **Functions:** Deploys serverless functions from `netlify/functions/`

## Access URLs

### Production (Docker + ArgoCD)
- **Application:** http://54.166.101.159:30011
- **Health Check:** http://54.166.101.159:30011/health
- **API Docs:** http://54.166.101.159:30011/docs
- **ArgoCD Dashboard:** http://54.166.101.159:30080
- **Grafana:** http://54.166.101.159:30081 (admin/admin123)
- **Prometheus:** http://54.166.101.159:30082
- **Loki:** http://54.166.101.159:30083

### Netlify (Serverless)
- **Application:** [Your Netlify URL]
- **Health Check:** [Your Netlify URL]/health
- **API Docs:** [Your Netlify URL]/docs

## ArgoCD Configuration

### Login Credentials
- **Username:** admin
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

### Application Management
- ArgoCD automatically syncs changes from the Git repository
- Application manifests are in `argocd/application.yaml`
- Helm charts are in `helm-chart/` directory

## Monitoring Stack

### Prometheus
- **Purpose:** Metrics collection and storage
- **Targets:** NativeSeries application, Kubernetes pods, Loki
- **Configuration:** `deployment/production/06-monitoring-stack.yaml`

### Grafana
- **Purpose:** Visualization and dashboards
- **Datasources:** Prometheus (metrics), Loki (logs)
- **Default Credentials:** admin/admin123

### Loki
- **Purpose:** Log aggregation and querying
- **Collection:** System logs, container logs via Promtail
- **Query Interface:** Available through Grafana

## Troubleshooting

### GitHub Actions Issues
1. Check workflow logs in GitHub Actions tab
2. Verify Docker build context
3. Ensure GitHub token has package write permissions
4. Check kubectl configuration for Kind cluster

### ArgoCD Issues
1. Verify ArgoCD installation: `kubectl get pods -n argocd`
2. Check application sync status in ArgoCD UI
3. Verify Helm chart syntax: `helm template test helm-chart`
4. Check application logs: `kubectl logs -n argocd deployment/argocd-server`

### Monitoring Issues
1. Check monitoring pods: `kubectl get pods -n monitoring -n logging`
2. Verify service endpoints: `kubectl get endpoints -n monitoring -n logging`
3. Check Prometheus targets: Access Prometheus UI and check targets
4. Verify Grafana datasources: Check datasource configuration

### Netlify Issues
1. Check build logs in Netlify dashboard
2. Verify `build.sh` script is executable
3. Ensure all required files exist in `public/`

### Common Fixes
- **Build fails:** Check `requirements.txt` and Python version
- **ArgoCD sync fails:** Verify Helm chart and application manifests
- **Monitoring not working:** Check service endpoints and network policies
- **Functions not working:** Verify `netlify/functions/` directory
- **Redirects not working:** Check `netlify.toml` syntax

## Environment Variables

### Required for Production
```bash
APP_ENV=production
APP_NAME=NativeSeries
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
```

### Required for Netlify
```bash
APP_ENV=production
APP_NAME=NativeSeries
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
```

### Optional
```bash
DEBUG=false
LOG_LEVEL=INFO
CORS_ORIGINS=*
```

## Security Notes
- ✅ All sensitive data moved to environment variables
- ✅ Security headers configured in Netlify
- ✅ CORS properly configured
- ✅ No hardcoded secrets in configuration files
- ✅ ArgoCD RBAC configured
- ✅ Monitoring stack secured

## Monitoring and Observability

### Metrics (Prometheus)
- Application metrics via `/metrics` endpoint
- Kubernetes pod metrics
- System resource metrics

### Logs (Loki)
- Application logs
- Container logs
- System logs

### Dashboards (Grafana)
- Application performance dashboards
- Infrastructure monitoring
- Custom dashboards for NativeSeries

## Next Steps
1. Connect your repository to Netlify
2. Set up environment variables in Netlify dashboard
3. Deploy and test all endpoints
4. Configure Grafana dashboards
5. Set up alerting rules in Prometheus
6. Monitor application performance and logs

---
**Last Updated:** August 7, 2024
**Version:** 2.0.0