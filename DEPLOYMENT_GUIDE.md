# Student Tracker Application Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Student Tracker application on the target server `18.206.89.183:8011` with both Docker Compose and ArgoCD GitOps approaches.

## Target Server Configuration

- **Server IP**: 18.206.89.183
- **Application Port**: 8011
- **ArgoCD Port**: 30080
- **Database Port**: 5432
- **Redis Port**: 6379

## Prerequisites

Before deployment, ensure the target server has:

1. **Operating System**: Ubuntu 20.04+ or CentOS 8+
2. **Minimum Resources**:
   - CPU: 2 cores
   - RAM: 4GB
   - Storage: 20GB
3. **Network Access**: Ports 80, 443, 8011, 5432, 6379, 30080, 9090, 3000, 8080
4. **User Permissions**: Sudo access for installation

## Deployment Options

### Option 1: Docker Compose Deployment (Recommended for Quick Setup)

This option provides a complete application stack with monitoring and is suitable for production deployment.

#### Quick Deployment

1. **Clone the repository on the target server**:
   ```bash
   git clone <your-repository-url>
   cd student-tracker
   ```

2. **Make the deployment script executable**:
   ```bash
   chmod +x deploy-docker-compose.sh
   ```

3. **Run the deployment script**:
   ```bash
   ./deploy-docker-compose.sh
   ```

The script will:
- Install Docker and Docker Compose if not present
- Create necessary configurations
- Build and deploy all services
- Set up SSL certificates
- Configure monitoring

#### Manual Deployment Steps

If you prefer manual deployment:

1. **Install Docker and Docker Compose**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker $USER
   sudo systemctl enable docker
   sudo systemctl start docker
   
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Create necessary directories**:
   ```bash
   mkdir -p logs docker/ssl docker/grafana/provisioning
   ```

3. **Deploy the application**:
   ```bash
   docker-compose up -d --build
   ```

### Option 2: ArgoCD GitOps Deployment (Recommended for Production)

This option provides GitOps workflow with Kubernetes and ArgoCD for continuous deployment.

#### Quick Deployment

1. **Clone the repository on the target server**:
   ```bash
   git clone <your-repository-url>
   cd student-tracker
   ```

2. **Make the deployment script executable**:
   ```bash
   chmod +x deploy-to-server.sh
   ```

3. **Run the deployment script**:
   ```bash
   ./deploy-to-server.sh
   ```

The script will:
- Install all required tools (Docker, kubectl, Helm, Kind)
- Set up a local Kubernetes cluster with Kind
- Install and configure ArgoCD
- Deploy the application using Helm
- Set up GitOps workflow

#### Manual ArgoCD Setup

1. **Install prerequisites**:
   ```bash
   # Install Kind
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
   sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
   
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

2. **Create Kind cluster**:
   ```bash
   kind create cluster --name gitops-cluster --config kind-config.yaml
   ```

3. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
   ```

4. **Deploy application**:
   ```bash
   helm upgrade --install student-tracker infra/helm \
     --values infra/helm/values-prod.yaml \
     --namespace app-prod \
     --create-namespace
   ```

## Application Architecture

The deployed application includes:

### Core Services
- **Student Tracker API**: FastAPI application on port 8011
- **PostgreSQL Database**: Student data storage on port 5432
- **Redis Cache**: Session and cache management on port 6379

### Infrastructure Services
- **Nginx Reverse Proxy**: SSL termination and load balancing
- **Prometheus**: Metrics collection on port 9090
- **Grafana**: Monitoring dashboards on port 3000
- **Node Exporter**: System metrics collection on port 9100
- **Adminer**: Database management interface on port 8080

### GitOps Components (ArgoCD deployment)
- **ArgoCD Server**: GitOps controller on port 30080
- **Kubernetes Cluster**: Local Kind cluster
- **Helm Charts**: Application packaging and deployment

## Access Information

### Application URLs
- **Main Application**: http://18.206.89.183:8011
- **API Documentation**: http://18.206.89.183:8011/docs
- **Health Check**: http://18.206.89.183:8011/health
- **Metrics**: http://18.206.89.183:8011/metrics

### Management Interfaces
- **ArgoCD UI**: http://18.206.89.183:30080
  - Username: `admin`
  - Password: Check `.argocd-password` file
- **Grafana**: http://18.206.89.183:3000
  - Username: `admin`
  - Password: `admin123`
- **Prometheus**: http://18.206.89.183:9090
- **Adminer**: http://18.206.89.183:8080
  - System: PostgreSQL
  - Username: `student_user`
  - Password: `student_pass`
  - Database: `student_db`

## Management Commands

### Docker Compose Management
```bash
# View logs
docker-compose logs -f student-tracker

# Restart application
docker-compose restart student-tracker

# Scale application
docker-compose up -d --scale student-tracker=3

# Stop all services
docker-compose down

# Update application
docker-compose pull && docker-compose up -d
```

### Kubernetes/ArgoCD Management
```bash
# View application status
kubectl get applications -n argocd

# View pods
kubectl get pods -n app-prod

# View logs
kubectl logs -f deployment/student-tracker -n app-prod

# Scale application
kubectl scale deployment student-tracker --replicas=3 -n app-prod

# Update with Helm
helm upgrade student-tracker infra/helm --values infra/helm/values-prod.yaml -n app-prod
```

## Security Considerations

### SSL/TLS Configuration
- Self-signed certificates are generated for development
- For production, replace with proper SSL certificates
- Configure Let's Encrypt or commercial certificates

### Firewall Configuration
```bash
# Allow required ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8011/tcp
sudo ufw allow 5432/tcp
sudo ufw allow 6379/tcp
sudo ufw allow 30080/tcp
sudo ufw allow 9090/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
```

### Database Security
- Change default passwords in production
- Restrict database access to application only
- Enable SSL for database connections
- Regular backup strategy

## Monitoring and Alerting

### Prometheus Metrics
The application exposes metrics at `/metrics` endpoint:
- Request counts and response times
- Database connection status
- Redis cache hit rates
- System resource usage

### Grafana Dashboards
Pre-configured dashboards for:
- Application performance
- Database metrics
- System resources
- Error rates and availability

### Health Checks
- Application health: `/health`
- Database connectivity
- Redis connectivity
- External service dependencies

## Backup and Recovery

### Database Backup
```bash
# Create backup
docker-compose exec postgres pg_dump -U student_user student_db > backup.sql

# Restore backup
docker-compose exec -T postgres psql -U student_user student_db < backup.sql
```

### Application Data Backup
```bash
# Backup volumes
docker run --rm -v student-tracker_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .

# Restore volumes
docker run --rm -v student-tracker_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_backup.tar.gz -C /data
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep :8011
   
   # Kill the process
   sudo kill -9 <PID>
   ```

2. **Database Connection Issues**
   ```bash
   # Check database status
   docker-compose exec postgres pg_isready -U student_user -d student_db
   
   # View database logs
   docker-compose logs postgres
   ```

3. **Application Not Starting**
   ```bash
   # Check application logs
   docker-compose logs student-tracker
   
   # Check health endpoint
   curl http://18.206.89.183:8011/health
   ```

4. **ArgoCD Sync Issues**
   ```bash
   # Check ArgoCD application status
   kubectl get applications -n argocd
   
   # View ArgoCD logs
   kubectl logs -f deployment/argocd-server -n argocd
   ```

### Log Locations
- Application logs: `logs/app.log`
- Docker logs: `docker-compose logs`
- Kubernetes logs: `kubectl logs`
- System logs: `/var/log/syslog`

## Performance Optimization

### Application Tuning
- Adjust worker processes based on CPU cores
- Configure connection pooling for database
- Enable Redis caching for frequently accessed data
- Implement rate limiting for API endpoints

### Infrastructure Tuning
- Configure appropriate resource limits
- Enable compression for web responses
- Optimize database queries and indexes
- Set up CDN for static assets

## Maintenance

### Regular Maintenance Tasks
1. **Security Updates**: Update base images regularly
2. **Database Maintenance**: Regular vacuum and analyze
3. **Log Rotation**: Configure log rotation policies
4. **Backup Verification**: Test backup restoration procedures
5. **Performance Monitoring**: Review metrics and optimize

### Update Procedures
1. **Docker Compose**: Pull new images and restart services
2. **ArgoCD**: Update Git repository and let ArgoCD sync
3. **Database Migrations**: Run migration scripts before updates
4. **Rollback Procedures**: Keep previous versions for quick rollback

## Support and Documentation

- **Application Documentation**: http://18.206.89.183:8011/docs
- **API Reference**: http://18.206.89.183:8011/redoc
- **Health Status**: http://18.206.89.183:8011/health
- **Metrics**: http://18.206.89.183:8011/metrics

For additional support, refer to the application logs and monitoring dashboards.