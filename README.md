# Student Tracker - GitOps Edition

A comprehensive FastAPI student tracking application deployed using modern GitOps practices with Kind, Helm, ArgoCD, and GitHub Actions.

## 🏗️ Architecture

This project demonstrates a complete GitOps workflow with:

- **Application**: FastAPI-based student tracker API
- **Containerization**: Docker for application packaging
- **Local Development**: Kind for local Kubernetes clusters
- **Package Management**: Helm for Kubernetes application deployment
- **GitOps**: ArgoCD for continuous deployment
- **CI/CD**: GitHub Actions for automated testing and deployment

## 📁 Project Structure

```
├── app/                          # FastAPI application source code
│   ├── main.py                   # Application entry point
│   ├── models.py                 # Database models
│   ├── crud.py                   # CRUD operations
│   ├── database.py               # Database configuration
│   └── routes/                   # API routes
├── infra/                        # Infrastructure as Code
│   ├── kind/                     # Kind cluster configuration
│   │   └── cluster-config.yaml   # Multi-node cluster setup
│   ├── helm/                     # Helm charts
│   │   ├── Chart.yaml            # Chart metadata
│   │   ├── values.yaml           # Default values
│   │   ├── values-dev.yaml       # Development values
│   │   ├── values-prod.yaml      # Production values
│   │   └── templates/            # Kubernetes templates
│   └── argocd/                   # ArgoCD applications
│       ├── parent/               # App-of-apps pattern
│       ├── dev/                  # Development environment
│       └── prod/                 # Production environment
├── k8s/                          # Generated Kubernetes manifests
│   ├── base/                     # Base Kubernetes resources
│   └── overlays/                 # Environment-specific overlays
├── .github/workflows/            # GitHub Actions CI/CD
├── scripts/                      # Utility scripts
│   ├── setup-kind.sh            # Kind cluster setup
│   ├── setup-argocd.sh          # ArgoCD installation
│   ├── deploy-all.sh            # Complete stack deployment
│   └── cleanup.sh               # Environment cleanup
├── docker/                       # Docker configuration
│   ├── Dockerfile               # Application container
│   └── docker-compose.yml       # Local development
└── docs/                         # Documentation
```

## 🚀 Quick Start

### Prerequisites

Make sure you have the following tools installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)

### One-Command Deployment

Deploy the entire GitOps stack with a single command:

```bash
./scripts/deploy-all.sh
```

This script will:
1. ✅ Check prerequisites
2. 🚀 Create Kind cluster with ingress support
3. 🐳 Build and load the application Docker image
4. 🎯 Install and configure ArgoCD
5. 📋 Create Kubernetes manifests
6. ⚙️ Deploy the application
7. 🌐 Set up port forwarding for local access

### Manual Step-by-Step Setup

If you prefer to run each step manually:

```bash
# 1. Setup Kind cluster
./scripts/setup-kind.sh

# 2. Build and load Docker image
docker build -t student-tracker:latest -f docker/Dockerfile .
kind load docker-image student-tracker:latest --name gitops-cluster

# 3. Setup ArgoCD
./scripts/setup-argocd.sh

# 4. Deploy using Helm
helm upgrade --install student-tracker infra/helm \
  --values infra/helm/values-dev.yaml \
  --namespace app-dev \
  --create-namespace

# 5. Access the application
kubectl port-forward svc/student-tracker -n app-dev 8000:80
```

## 🌐 Access Information

After deployment, you can access:

### ArgoCD UI
- **URL**: http://localhost:8080 (when using deploy-all.sh)
- **Username**: admin
- **Password**: Check `.argocd-password` file

### Student Tracker API
- **URL**: http://localhost:8000 (when using deploy-all.sh)
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

### Ingress (Optional)
Add to your `/etc/hosts`:
```
127.0.0.1 student-tracker.local
127.0.0.1 student-tracker-dev.local
```

## 🔄 GitOps Workflow

### App-of-Apps Pattern

This project uses the App-of-Apps pattern in ArgoCD:

1. **Parent Application**: `app-of-apps` manages child applications
2. **Child Applications**: Environment-specific deployments (dev, staging, prod)
3. **Helm Charts**: Parameterized Kubernetes resources
4. **Value Files**: Environment-specific configurations

### CI/CD Pipeline

The GitHub Actions workflow provides:

- **Testing**: Automated tests with pytest and coverage
- **Security**: Trivy vulnerability scanning
- **Building**: Multi-platform Docker images
- **Deployment**: GitOps-style deployments via git commits
- **Environments**: Separate dev, staging, and production flows

### Development Workflow

1. **Make changes** to application code
2. **Push to `develop` branch** → Triggers dev deployment
3. **Create PR to `main`** → Triggers staging deployment
4. **Merge to `main`** → Creates production deployment PR
5. **Review and merge production PR** → Deploys to production

## 🛠️ Development

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
uvicorn app.main:app --reload --port 8000

# Run tests
pytest app/ -v --cov=app

# Format code
black app/
flake8 app/
```

### Docker Development

```bash
# Build image
docker build -t student-tracker:dev -f docker/Dockerfile .

# Run container
docker run -p 8000:8000 -e APP_ENV=development student-tracker:dev

# Use docker-compose
docker-compose -f docker/docker-compose.yml up
```

### Kubernetes Development

```bash
# Deploy to dev environment
helm upgrade --install student-tracker infra/helm \
  --values infra/helm/values-dev.yaml \
  --namespace app-dev \
  --create-namespace

# Check deployment
kubectl get pods -n app-dev
kubectl logs -f deployment/student-tracker -n app-dev

# Port forward for testing
kubectl port-forward svc/student-tracker -n app-dev 8000:80
```

## 🎛️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `APP_ENV` | Environment (development/production) | development |
| `DEBUG` | Enable debug mode | false |
| `LOG_LEVEL` | Logging level | INFO |

### Helm Values

Customize deployments by modifying value files:

- `infra/helm/values.yaml` - Default values
- `infra/helm/values-dev.yaml` - Development environment
- `infra/helm/values-prod.yaml` - Production environment

Key configuration options:
- Resource limits and requests
- Replica count and autoscaling
- Ingress configuration
- Environment variables
- Security settings

## 🔒 Security

### Container Security
- Non-root user execution
- Read-only root filesystem
- Dropped capabilities
- Security context constraints

### Kubernetes Security
- Pod Security Standards compliance
- Network policies (when enabled)
- Secret management
- RBAC integration

### CI/CD Security
- Vulnerability scanning with Trivy
- Code quality checks
- Dependency scanning
- Container image signing (optional)

## 📊 Monitoring & Observability

### Health Checks
- Liveness and readiness probes
- Health endpoint at `/health`
- Graceful shutdown handling

### Metrics (Optional)
- Prometheus metrics endpoint
- ServiceMonitor for Prometheus Operator
- Grafana dashboards

### Logging
- Structured JSON logging
- Configurable log levels
- Kubernetes log aggregation ready

## 🗂️ ArgoCD Applications

### Parent Application
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
spec:
  source:
    repoURL: https://github.com/your-org/student-tracker.git
    path: infra/argocd/parent
```

### Environment Applications
- **Development**: Auto-sync enabled, deploys from `develop` branch
- **Staging**: Auto-sync enabled, deploys from `main` branch  
- **Production**: Manual sync, requires approval

## 🧰 Useful Commands

### Kind Cluster Management
```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name gitops-cluster

# Load Docker image
kind load docker-image student-tracker:latest --name gitops-cluster
```

### ArgoCD Management
```bash
# Login to ArgoCD CLI
argocd login localhost:8080

# List applications
argocd app list

# Sync application
argocd app sync student-tracker-dev

# Get application status
argocd app get student-tracker-dev
```

### Kubernetes Debugging
```bash
# Check pod status
kubectl get pods -n app-dev

# View logs
kubectl logs -f deployment/student-tracker -n app-dev

# Describe resources
kubectl describe deployment student-tracker -n app-dev

# Execute into pod
kubectl exec -it deployment/student-tracker -n app-dev -- /bin/sh
```

### Helm Commands
```bash
# List releases
helm list -A

# Upgrade release
helm upgrade student-tracker infra/helm --values infra/helm/values-dev.yaml

# Rollback release
helm rollback student-tracker 1

# Debug templates
helm template student-tracker infra/helm --values infra/helm/values-dev.yaml
```

## 🧹 Cleanup

To completely remove the GitOps stack:

```bash
./scripts/cleanup.sh
```

Or manually:
```bash
# Delete Kind cluster
kind delete cluster --name gitops-cluster

# Remove Docker images
docker rmi student-tracker:latest

# Clean up generated files
rm -f .argocd-password
rm -rf k8s/base/ k8s/argocd/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Troubleshooting

### Common Issues

**Kind cluster creation fails**
- Ensure Docker is running
- Check available disk space
- Try deleting existing clusters

**ArgoCD UI not accessible**
- Verify port forwarding is active
- Check ArgoCD pods are running: `kubectl get pods -n argocd`
- Restart port forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`

**Application deployment issues**
- Check ArgoCD application status
- Verify Helm chart syntax: `helm lint infra/helm`
- Check pod logs: `kubectl logs -f deployment/student-tracker -n app-dev`

**Image pull errors**
- Ensure image is loaded into Kind: `kind load docker-image student-tracker:latest --name gitops-cluster`
- Check image name and tag in values files

## 📄 License

This project is licensed under the MIT License - see the [License.md](License.md) file for details.

## 🙏 Acknowledgments

- [ArgoCD](https://argoproj.github.io/cd/) for GitOps capabilities
- [Kind](https://kind.sigs.k8s.io/) for local Kubernetes clusters
- [Helm](https://helm.sh/) for Kubernetes package management
- [FastAPI](https://fastapi.tiangolo.com/) for the web framework
