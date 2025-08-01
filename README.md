# 🎓 Student Tracker - Cloud Native Series

[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io)

A comprehensive **Student Tracker** application demonstrating cloud-native development practices, containerization, Kubernetes deployment, and GitOps workflows. Built with modern technologies and production-ready architecture.

## 🌟 Features

### 🎯 Core Application
- **FastAPI Backend**: High-performance async API with automatic OpenAPI documentation
- **Student Management**: Complete CRUD operations for student records
- **Progress Tracking**: Week-by-week student progress monitoring
- **Course Management**: Multi-course enrollment and tracking system
- **Assignment System**: Assignment creation, submission, and grading
- **Modern Web UI**: Responsive interface built with HTML/CSS/JavaScript

### 🏗️ Architecture & Infrastructure
- **Containerized**: Docker containers for all services
- **Microservices Ready**: Modular architecture with clear separation of concerns
- **Database**: PostgreSQL with proper schema, indexes, and relationships
- **Caching**: Redis for session management and performance optimization
- **Load Balancing**: Nginx reverse proxy with SSL termination
- **Monitoring**: Prometheus + Grafana observability stack
- **Health Checks**: Comprehensive health monitoring for all services

### 🚀 DevOps & Deployment
- **Kubernetes**: Complete K8s manifests with Helm charts
- **GitOps**: ArgoCD for continuous deployment
- **CI/CD**: GitHub Actions workflows
- **Infrastructure as Code**: Terraform configurations (coming soon)
- **Security**: SSL/TLS, proper secrets management, security headers
- **Scaling**: Horizontal pod autoscaling and load balancing

## 🛠️ Technology Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Backend** | FastAPI | 0.110+ | High-performance Python web framework |
| **Database** | PostgreSQL | 16+ | Primary data storage with ACID compliance |
| **Cache** | Redis | 7+ | Session storage and caching layer |
| **Web Server** | Nginx | Alpine | Reverse proxy and load balancer |
| **Container** | Docker | 20.10+ | Application containerization |
| **Orchestration** | Kubernetes | 1.28+ | Container orchestration platform |
| **Package Manager** | Helm | 3.16+ | Kubernetes application packaging |
| **GitOps** | ArgoCD | 2.13+ | Continuous deployment automation |
| **Monitoring** | Prometheus | Latest | Metrics collection and monitoring |
| **Visualization** | Grafana | Latest | Dashboards and alerting |
| **Language** | Python | 3.13+ | Primary programming language |

## 🚀 Quick Start

### Option 1: Fast Development Setup (Recommended)
```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries

# Run the development setup script
./scripts/dev-setup.sh

# Choose option 1 for Python development or option 2 for Docker
```

### Option 2: Manual Setup
```bash
# 1. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Start database services
docker-compose up -d postgres redis

# 4. Run the application
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Option 3: Full Production Setup
```bash
# Complete installation with Kubernetes, ArgoCD, and monitoring
./scripts/install-all.sh

# For development mode only
./scripts/install-all.sh dev
```

## 🌐 Access Points

Once running, access the application at:

| Service | URL | Purpose |
|---------|-----|---------|
| **Main Application** | http://localhost:8000 | Student Tracker web interface |
| **API Documentation** | http://localhost:8000/docs | Interactive Swagger UI |
| **Alternative Docs** | http://localhost:8000/redoc | ReDoc API documentation |
| **Health Check** | http://localhost:8000/health | Application health status |
| **Metrics** | http://localhost:8000/metrics | Prometheus metrics endpoint |
| **Database Admin** | http://localhost:8080 | Adminer database interface |
| **Monitoring** | http://localhost:9090 | Prometheus monitoring |
| **Dashboards** | http://localhost:3000 | Grafana dashboards (admin/admin123) |

## 📁 Project Structure

```
Student-Tracker/
├── 📱 app/                          # Application source code
│   ├── main.py                      # FastAPI application entry point
│   ├── models.py                    # SQLAlchemy database models
│   ├── crud.py                      # Database operations
│   ├── database.py                  # Database configuration
│   └── routes/                      # API route modules
├── 🐳 docker/                       # Docker configurations
│   ├── Dockerfile                   # Multi-stage application container
│   ├── nginx.conf                   # Nginx reverse proxy config
│   ├── redis.conf                   # Redis configuration
│   └── prometheus.yml               # Prometheus monitoring config
├── ☸️ infra/                        # Infrastructure as Code
│   ├── helm/                        # Helm charts for Kubernetes
│   │   ├── Chart.yaml               # Helm chart metadata
│   │   ├── values.yaml              # Default configuration values
│   │   └── templates/               # Kubernetes resource templates
│   ├── argocd/                      # ArgoCD GitOps configurations
│   └── kind/                        # Local Kubernetes cluster config
├── 🛠️ scripts/                      # Automation scripts
│   ├── install-all.sh               # Complete production setup
│   ├── dev-setup.sh                 # Fast development environment
│   └── init-db.sql                  # Database initialization
├── 🎨 templates/                    # HTML templates for web UI
├── 📊 monitoring/                   # Monitoring and observability
├── 🧪 tests/                        # Test suites
├── 📋 requirements.txt              # Python dependencies
├── 🐳 docker-compose.yml            # Local development stack
└── 📖 README.md                     # This file
```

## 🔧 Development Workflow

### 1. Local Development
```bash
# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start database services
docker-compose up -d postgres redis

# Run with auto-reload
python -m uvicorn app.main:app --reload

# Run tests
pytest

# Format code
black app/
flake8 app/
```

### 2. Docker Development
```bash
# Build and start all services
docker-compose up --build

# View logs
docker-compose logs -f student-tracker

# Rebuild specific service
docker-compose build student-tracker
docker-compose up -d student-tracker
```

### 3. Kubernetes Development
```bash
# Create local cluster
kind create cluster --config infra/kind/cluster-config.yaml

# Deploy with Helm
helm install student-tracker infra/helm/

# Check deployment
kubectl get pods
kubectl logs -f deployment/student-tracker
```

## 📊 API Endpoints

### Student Management
```http
GET    /students           # List all students
POST   /students           # Create new student
GET    /students/{id}      # Get student by ID
PUT    /students/{id}      # Update student
DELETE /students/{id}      # Delete student
```

### Progress Tracking
```http
GET    /students/{id}/progress        # Get student progress
POST   /students/{id}/progress        # Update progress
GET    /courses/{id}/progress         # Get course progress
```

### System Endpoints
```http
GET    /health            # Health check
GET    /metrics           # Prometheus metrics
GET    /docs              # API documentation
GET    /redoc             # Alternative documentation
```

## 🔐 Security Features

- **SSL/TLS**: HTTPS encryption with proper certificates
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.
- **Rate Limiting**: API endpoint protection
- **Input Validation**: Comprehensive request validation
- **SQL Injection Protection**: Parameterized queries
- **CORS Configuration**: Proper cross-origin resource sharing
- **Authentication Ready**: JWT token infrastructure in place

## 📈 Monitoring & Observability

### Metrics Collection
- **Application Metrics**: Request count, response time, error rates
- **System Metrics**: CPU, memory, disk usage via Node Exporter
- **Database Metrics**: Connection pools, query performance
- **Custom Metrics**: Business logic specific measurements

### Health Checks
- **Kubernetes Probes**: Liveness and readiness checks
- **Database Connectivity**: PostgreSQL connection validation
- **External Services**: Redis cache connectivity
- **Application Status**: Custom health indicators

### Logging
- **Structured Logging**: JSON formatted logs with correlation IDs
- **Log Levels**: Configurable logging levels (DEBUG, INFO, WARN, ERROR)
- **Centralized Logs**: Container log aggregation
- **Performance Logging**: Slow query and request monitoring

## 🚀 Deployment Options

### 1. Local Development
```bash
./scripts/dev-setup.sh
```

### 2. Docker Compose
```bash
docker-compose up -d
```

### 3. Kubernetes (Local)
```bash
# Using provided scripts
./scripts/install-all.sh

# Manual deployment
kind create cluster --config infra/kind/cluster-config.yaml
helm install student-tracker infra/helm/
```

### 4. Production Kubernetes
```bash
# Update values for production
helm install student-tracker infra/helm/ \
  --values infra/helm/values-prod.yaml \
  --namespace production
```

### 5. GitOps with ArgoCD
```bash
# Apply ArgoCD application
kubectl apply -f infra/argocd/student-tracker-app.yaml
```

## 🧪 Testing

### Running Tests
```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run all tests
pytest

# Run with coverage
pytest --cov=app tests/

# Run specific test file
pytest tests/test_students.py

# Run with verbose output
pytest -v
```

### Test Categories
- **Unit Tests**: Individual function testing
- **Integration Tests**: Database and API integration
- **End-to-End Tests**: Complete workflow testing
- **Performance Tests**: Load and stress testing

## 🐳 Container Images

### Building Images
```bash
# Build application image
docker build -f docker/Dockerfile -t student-tracker:latest .

# Build with specific version
docker build -f docker/Dockerfile -t student-tracker:v1.1.0 .

# Multi-architecture build
docker buildx build --platform linux/amd64,linux/arm64 -t student-tracker:latest .
```

### Image Features
- **Multi-stage Build**: Optimized for size and security
- **Non-root User**: Security best practices
- **Health Checks**: Built-in container health monitoring
- **Proper Layering**: Efficient Docker layer caching

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows
- **Test Pipeline**: Automated testing on pull requests
- **Build Pipeline**: Docker image building and pushing
- **Deploy Pipeline**: Automated deployment to staging/production
- **Security Scanning**: Vulnerability scanning for dependencies

### GitOps Workflow
1. **Code Push**: Developer pushes code to repository
2. **CI Pipeline**: Tests run and Docker image is built
3. **Image Update**: New image tag updated in Helm values
4. **ArgoCD Sync**: ArgoCD automatically deploys changes
5. **Health Checks**: Automated verification of deployment

## 🛠️ Configuration

### Environment Variables
```env
# Application
APP_ENV=development
LOG_LEVEL=INFO

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/studentdb
REDIS_URL=redis://localhost:6379

# Security
SECRET_KEY=your-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Monitoring
ENABLE_METRICS=true
ENABLE_TRACING=false
```

### Kubernetes Configuration
```yaml
# Example production values
replicaCount: 3
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## 🔍 Troubleshooting

### Common Issues

**Application won't start**
```bash
# Check logs
docker-compose logs student-tracker

# Verify environment variables
cat .env

# Test database connection
docker exec -it postgres psql -U student_user -d student_db
```

**Database connection failed**
```bash
# Restart database
docker-compose restart postgres

# Check database status
docker-compose ps postgres

# Test connection
docker exec postgres pg_isready -U student_user
```

**Kubernetes deployment issues**
```bash
# Check pod status
kubectl get pods -n app-dev

# View pod logs
kubectl logs deployment/student-tracker -n app-dev

# Describe pod for events
kubectl describe pod -l app=student-tracker -n app-dev
```

### Performance Optimization
- **Database Indexing**: Proper indexing for frequent queries
- **Connection Pooling**: Optimal database connection management
- **Caching Strategy**: Redis caching for frequently accessed data
- **Resource Limits**: Appropriate CPU and memory allocation

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** and add tests
4. **Run tests**: `pytest`
5. **Format code**: `black app/ && flake8 app/`
6. **Commit changes**: `git commit -m 'Add amazing feature'`
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

### Development Guidelines
- Follow PEP 8 style guidelines
- Write comprehensive tests for new features
- Update documentation for API changes
- Use conventional commit messages
- Ensure Docker builds successfully

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Development Team** - *Initial work* - [NativeSeries](https://github.com/bonaventuresimeon/NativeSeries)

## 🙏 Acknowledgments

- **FastAPI** for the excellent web framework
- **Kubernetes** community for orchestration tools
- **Docker** for containerization technology
- **PostgreSQL** for reliable database management
- **Prometheus & Grafana** for monitoring solutions

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bonaventuresimeon/NativeSeries/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bonaventuresimeon/NativeSeries/discussions)
- **Email**: dev@yourcompany.com

## 🔮 Roadmap

- [ ] **Authentication & Authorization**: JWT-based user management
- [ ] **Advanced Analytics**: Student performance analytics dashboard
- [ ] **Notification System**: Email and SMS notifications
- [ ] **Mobile App**: React Native mobile application
- [ ] **AI Integration**: Predictive analytics for student success
- [ ] **Multi-tenancy**: Support for multiple institutions
- [ ] **Audit Logging**: Comprehensive activity tracking
- [ ] **Advanced Monitoring**: Distributed tracing with Jaeger

---

⭐ **Star this repository** if you find it helpful!

🐛 **Found a bug?** [Open an issue](https://github.com/bonaventuresimeon/NativeSeries/issues)

💡 **Have suggestions?** [Start a discussion](https://github.com/bonaventuresimeon/NativeSeries/discussions)
