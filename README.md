# 🎓 Student Tracker Application

A comprehensive student management system built with FastAPI, featuring modern deployment with Docker, Kubernetes, Helm, and ArgoCD. This application provides a complete solution for tracking student progress and managing educational data.

## 🌐 Live Application

- **Production URL**: http://18.206.89.183:30011
- **API Documentation**: http://18.206.89.183:30011/docs
- **Health Check**: http://18.206.89.183:30011/health
- **Metrics**: http://18.206.89.183:30011/metrics
- **Students Interface**: http://18.206.89.183:30011/students/

## 🚀 ArgoCD URLs

- **Production ArgoCD**: https://argocd-prod.18.206.89.183.nip.io
- **Development ArgoCD**: https://argocd-dev.18.206.89.183.nip.io
- **Staging ArgoCD**: https://argocd-staging.18.206.89.183.nip.io

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Deployment Options](#-deployment-options)
- [EC2 Deployment Guide](#-ec2-deployment-guide)
- [ArgoCD Configuration](#-argocd-configuration)
- [Architecture](#-architecture)
- [Development](#-development)
- [API Documentation](#-api-documentation)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## ✨ Features

### Core Features
- **Student Management**: Add, update, and track student information
- **Progress Tracking**: Monitor student progress across multiple weeks
- **RESTful API**: Comprehensive API with OpenAPI/Swagger documentation
- **Health Monitoring**: Built-in health checks and metrics
- **Responsive UI**: Modern web interface for student management

### Technical Features
- **FastAPI Backend**: High-performance async Python framework
- **MongoDB Integration**: Flexible document-based data storage
- **Docker Containerization**: Consistent deployment across environments
- **Kubernetes Ready**: Helm charts for scalable deployments
- **ArgoCD GitOps**: Automated deployment with GitOps principles
- **GitHub Actions**: CI/CD pipeline with automated testing and deployment
- **Security Scanning**: Integrated security checks with Trivy and Bandit
- **Code Quality**: Automated linting with Black, Flake8, and MyPy
- **Monitoring**: Prometheus metrics and health endpoints

## 🚀 Quick Start

### Option 1: Docker Deployment (Recommended)
```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Quick Docker deployment
./deploy.sh docker
```

### Option 2: EC2 Deployment
```bash
# Full EC2 setup and deployment
./deploy.sh ec2
```

### Option 3: Kubernetes Deployment
```bash
# Full Kubernetes deployment with ArgoCD
./deploy.sh kubernetes
```

## 🎯 Deployment Options

The application supports multiple deployment methods:

| Method | Use Case | Command | Requirements |
|--------|----------|---------|-------------|
| **Docker** | Quick testing, development | `./deploy.sh docker` | Docker |
| **EC2** | Production on EC2 | `./deploy.sh ec2` | EC2 instance |
| **Kubernetes** | Scalable production | `./deploy.sh kubernetes` | K8s cluster |
| **Helm Fix** | Troubleshooting | `./deploy.sh helm-fix` | kubectl, helm |
| **Validation** | Configuration check | `./deploy.sh validate` | Python |

### Deployment Script Options

```bash
./deploy.sh [OPTION]

OPTIONS:
  docker           Quick Docker deployment (recommended for EC2)
  ec2              Full EC2 deployment with system setup
  kubernetes       Full Kubernetes deployment with ArgoCD
  helm-fix         Fix Helm deployment issues
  validate         Validate configuration only
  build            Build Docker image only
  argocd           Install ArgoCD only
  monitoring       Deploy with Prometheus monitoring
  health-check     Check deployment health
  status           Show deployment status
  clean            Clean up deployments
  help             Show help message
```

## 🚀 EC2 Deployment Guide

### Prerequisites

#### EC2 Instance Requirements
- **OS**: Amazon Linux 2 or Ubuntu 20.04+
- **Instance Type**: t2.micro (minimum) or t2.small (recommended)
- **Storage**: 8GB minimum
- **Security Groups**: 
  - SSH (Port 22)
  - HTTP (Port 80)
  - Custom TCP (Port 30011) - Application
  - Custom TCP (Port 30080) - ArgoCD HTTP
  - Custom TCP (Port 30443) - ArgoCD HTTPS

#### GitHub Repository Setup
- Repository with Student Tracker code
- GitHub Actions enabled
- Repository secrets configured

### Step 1: EC2 Instance Setup

#### Launch EC2 Instance
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ec2-user@18.206.89.183

# Update system
sudo yum update -y

# Install basic tools
sudo yum install -y git curl wget unzip
```

#### Configure Security Groups
Create or modify security group with these rules:

| Type | Protocol | Port Range | Source |
|------|----------|------------|--------|
| SSH | TCP | 22 | Your IP |
| HTTP | TCP | 80 | 0.0.0.0/0 |
| Custom TCP | TCP | 30011 | 0.0.0.0/0 |
| Custom TCP | TCP | 30080 | 0.0.0.0/0 |
| Custom TCP | TCP | 30443 | 0.0.0.0/0 |

### Step 2: GitHub Secrets Configuration

#### Required Secrets
Add these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `EC2_HOST` | Your EC2 public IP or domain | `18.206.89.183` |
| `EC2_SSH_KEY` | Your private SSH key content | `-----BEGIN RSA PRIVATE KEY-----...` |

### Step 3: Manual Deployment

#### Quick Deployment
```bash
# Connect to EC2
ssh ec2-user@18.206.89.183

# Clone repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Run deployment
./deploy.sh ec2
```

#### Verify Deployment
```bash
# Check container status
sudo docker ps

# Test endpoints
curl http://18.206.89.183:30011/health
curl http://18.206.89.183:30011/docs
curl http://18.206.89.183:30011/students/

# View logs
sudo docker logs -f student-tracker
```

### Step 4: Automated Deployment

#### GitHub Actions Workflow
The repository includes GitHub Actions workflows that will:

1. **Validate** code and configurations
2. **Build** Docker image
3. **Push** to GitHub Container Registry
4. **Deploy** to EC2 automatically
5. **Verify** all endpoints

#### Trigger Deployment
```bash
# Push to main branch to trigger deployment
git add .
git commit -m "Update application"
git push origin main
```

### Step 5: Testing and Verification

#### Health Checks
```bash
# Test from EC2
curl http://18.206.89.183:30011/health

# Test from external
curl http://18.206.89.183:30011/health
```

#### Endpoint Testing
```bash
# All endpoints should return 200 OK
curl -I http://18.206.89.183:30011/health
curl -I http://18.206.89.183:30011/docs
curl -I http://18.206.89.183:30011/students/
curl -I http://18.206.89.183:30011/metrics
```

### Troubleshooting

#### Common Issues

**1. Docker Not Running**
```bash
# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker ec2-user
# Logout and login again
```

**2. Port Already in Use**
```bash
# Check what's using port 30011
sudo netstat -tlnp | grep 30011

# Kill process if needed
sudo kill -9 <PID>
```

**3. Container Won't Start**
```bash
# Check container logs
sudo docker logs student-tracker

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
```

**4. Health Check Fails**
```bash
# Check if container is running
sudo docker ps

# Check container logs
sudo docker logs student-tracker

# Check if port is exposed
sudo docker port student-tracker

# Test from inside container
sudo docker exec student-tracker curl http://18.206.89.183:8000/health
```

## 🎯 ArgoCD Configuration

### Environment Configurations

#### Production (`application-production.yaml`)
- **Application URL**: http://18.206.89.183:30011
- **ArgoCD URL**: https://argocd-prod.18.206.89.183.nip.io
- **Branch**: `main`
- **Namespace**: `student-tracker-prod`
- **Replicas**: 2-10 (auto-scaling)
- **Environment**: production

#### Staging (`application-staging.yaml`)
- **Application URL**: http://staging.18.206.89.183:30011
- **ArgoCD URL**: https://argocd-staging.18.206.89.183.nip.io
- **Branch**: `develop`
- **Namespace**: `student-tracker-staging`
- **Replicas**: 2-5 (auto-scaling)
- **Environment**: staging

#### Development (`application-development.yaml`)
- **Application URL**: http://dev.18.206.89.183:30011
- **ArgoCD URL**: https://argocd-dev.18.206.89.183.nip.io
- **Branch**: `develop`
- **Namespace**: `student-tracker-dev`
- **Replicas**: 1-3 (auto-scaling)
- **Environment**: development

### Deployment Process

#### Automatic Deployments
The GitHub Actions workflows automatically deploy to different environments:

1. **Development**: Triggered on pushes to `develop` branch
2. **Staging**: Triggered on workflow dispatch with staging environment selected
3. **Production**: Triggered on pushes to `main` branch

#### Manual Deployment
You can manually deploy using ArgoCD CLI:

```bash
# Deploy to development
kubectl apply -f argocd/application-development.yaml
argocd app sync student-tracker-development

# Deploy to staging
kubectl apply -f argocd/application-staging.yaml
argocd app sync student-tracker-staging

# Deploy to production
kubectl apply -f argocd/application-production.yaml
argocd app sync student-tracker-production
```

### Configuration Details

#### Helm Parameters
Each environment uses different Helm parameters:

- **Image tag**: `latest` (prod), `staging` (staging), `develop` (dev)
- **Environment variables**: Set according to environment
- **Resource limits**: Production has higher limits
- **Ingress hosts**: Different domains for each environment

#### Sync Policies
All environments use:
- **Automated sync**: Enabled with prune and self-heal
- **Retry policy**: Exponential backoff with environment-specific limits
- **Sync options**: CreateNamespace, PrunePropagationPolicy, PruneLast

## 🏗️ Architecture

### System Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │  GitHub Actions │    │   Docker Hub    │
│                 │───▶│                 │───▶│                 │
│  Source Code    │    │    CI/CD        │    │  Container      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     ArgoCD      │    │   Kubernetes    │    │      EC2        │
│                 │───▶│                 │───▶│                 │
│   GitOps CD     │    │   Orchestration │    │   Deployment    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Technology Stack
- **Backend**: FastAPI (Python)
- **Database**: MongoDB
- **Containerization**: Docker
- **Orchestration**: Kubernetes
- **Package Manager**: Helm
- **GitOps**: ArgoCD
- **CI/CD**: GitHub Actions
- **Infrastructure**: AWS EC2
- **Monitoring**: Prometheus + Grafana
- **Security**: Trivy, Bandit, Safety

## 💻 Development

### Local Development Setup

#### Prerequisites
- Python 3.11+
- Docker
- Git

#### Setup Steps
```bash
# Clone repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run locally
python app/main.py
```

#### Development Commands
```bash
# Run tests
python app/test_basic.py

# Format code
black app/

# Lint code
flake8 app/

# Type checking
mypy app/

# Run with hot reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Project Structure
```
NativeSeries/
├── app/                    # Application source code
│   ├── main.py            # FastAPI application
│   ├── crud.py            # Database operations
│   ├── models.py          # Data models
│   ├── database.py        # Database connection
│   └── routes/            # API routes
├── helm-chart/            # Helm deployment charts
│   ├── templates/         # Kubernetes templates
│   ├── Chart.yaml         # Chart metadata
│   └── values.yaml        # Configuration values
├── argocd/                # ArgoCD application configs
│   ├── application-production.yaml
│   ├── application-staging.yaml
│   └── application-development.yaml
├── .github/workflows/     # GitHub Actions workflows
├── deploy.sh              # Unified deployment script
├── Dockerfile             # Container definition
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

## 📚 API Documentation

### Core Endpoints

#### Health and Monitoring
- `GET /health` - Application health check
- `GET /metrics` - Prometheus metrics
- `GET /docs` - Interactive API documentation
- `GET /redoc` - Alternative API documentation

#### Student Management
- `GET /students/` - List all students (Web UI)
- `GET /api/students` - Get all students (JSON)
- `POST /api/register` - Register new student
- `POST /register` - Register student (Form)
- `GET /progress` - Student progress page
- `POST /progress` - Update student progress
- `GET /update` - Update student page
- `POST /update` - Update student data
- `GET /admin` - Admin interface

### API Examples

#### Register a Student
```bash
curl -X POST "http://18.206.89.183:30011/api/register?name=John%20Doe" \
     -H "accept: application/json"
```

#### Get All Students
```bash
curl -X GET "http://18.206.89.183:30011/api/students" \
     -H "accept: application/json"
```

#### Health Check
```bash
curl -X GET "http://18.206.89.183:30011/health" \
     -H "accept: application/json"
```

### Response Examples

#### Health Check Response
```json
{
  "status": "healthy",
  "service": "student-tracker",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "request_count": 150,
  "production_url": "http://18.206.89.183:30011",
  "database": "healthy",
  "environment": "production"
}
```

## 📊 Monitoring

### Application Monitoring
- **Health Check**: http://18.206.89.183:30011/health
- **Metrics**: http://18.206.89.183:30011/metrics
- **API Docs**: http://18.206.89.183:30011/docs

### System Monitoring
```bash
# Monitor system resources
htop

# Monitor Docker
sudo docker stats

# Monitor logs
sudo journalctl -f

# Monitor application logs
sudo docker logs -f student-tracker
```

### Metrics Available
- Request count and duration
- Response status codes
- Database connection status
- Memory and CPU usage
- Application uptime
- Error rates

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Application Won't Start
```bash
# Check container logs
sudo docker logs student-tracker

# Check if port is available
sudo netstat -tlnp | grep 30011

# Restart container
sudo docker restart student-tracker
```

#### Database Connection Issues
```bash
# Check MongoDB connectivity
sudo docker exec student-tracker curl http://18.206.89.183:27017

# Check environment variables
sudo docker exec student-tracker env | grep MONGO
```

#### Performance Issues
```bash
# Check resource usage
sudo docker stats student-tracker

# Check system resources
free -h
df -h
```

#### Network Issues
```bash
# Test connectivity
curl -v http://18.206.89.183:30011/health

# Check firewall
sudo iptables -L

# Check security groups (EC2)
# Ensure ports 30011, 30080, 30443 are open
```

### Debug Commands
```bash
# Check system resources
free -h
df -h
top

# Check Docker status
sudo docker info
sudo docker version

# Check network connectivity
curl -v http://18.206.89.183:30011/health
telnet 18.206.89.183 30011

# Check firewall
sudo iptables -L
```

### ArgoCD Troubleshooting

#### Common Issues
1. **Application not syncing**: Check the source repository and branch
2. **Image pull errors**: Verify GitHub Container Registry permissions
3. **Ingress issues**: Check cert-manager and NGINX ingress controller

#### Useful Commands
```bash
# Check application status
argocd app get student-tracker-production

# View application logs
argocd app logs student-tracker-production

# Force sync
argocd app sync student-tracker-production --force

# Rollback to previous version
argocd app rollback student-tracker-production
```

## 🔒 Security

### Security Features
- Input validation and sanitization
- CORS protection
- Security headers
- Container security scanning
- Dependency vulnerability scanning
- Code security analysis

### Security Best Practices
1. **Use HTTPS** in production
2. **Restrict security groups** to specific IPs
3. **Regular updates** of system packages
4. **Monitor logs** for suspicious activity
5. **Use IAM roles** instead of access keys
6. **Enable CloudWatch** monitoring

### Security Commands
```bash
# Update system regularly
sudo yum update -y

# Check for security updates
sudo yum check-update

# Monitor failed login attempts
sudo tail -f /var/log/secure

# Check open ports
sudo netstat -tlnp
```

## 🎯 Success Criteria

Your deployment is successful when:

✅ **Container is running**: `sudo docker ps` shows student-tracker  
✅ **Health check passes**: `curl http://18.206.89.183:30011/health` returns 200  
✅ **All endpoints work**: Health, docs, students, metrics all accessible  
✅ **External access**: Application accessible from internet  
✅ **Logs are clean**: No errors in container logs  
✅ **GitHub Actions pass**: All workflow steps complete successfully  

## 🤝 Contributing

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow PEP 8 style guidelines
- Add tests for new features
- Update documentation
- Ensure all checks pass

### Code Quality
- **Formatting**: Black
- **Linting**: Flake8
- **Type Checking**: MyPy
- **Security**: Bandit
- **Testing**: pytest

## 📞 Support

If you encounter issues:

1. **Check logs**: `sudo docker logs student-tracker`
2. **Verify configuration**: Review this guide
3. **Test manually**: Run deployment script step by step
4. **Check GitHub Actions**: Review workflow logs
5. **Contact support**: Create GitHub issue

### Useful Resources
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- FastAPI team for the excellent framework
- Docker for containerization platform
- Kubernetes community for orchestration
- ArgoCD team for GitOps solution
- GitHub for CI/CD platform

---

**🎉 Congratulations! Your Student Tracker is now deployed and running at http://18.206.89.183:30011!**

For the latest updates and documentation, visit the [GitHub repository](https://github.com/bonaventuresimeon/NativeSeries).
