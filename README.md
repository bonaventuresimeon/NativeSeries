# 🚀 Student Tracker - Complete Application Platform

## 👨‍💻 **Author**

**Bonaventure Simeon**  
📧 Email: [contact@bonaventure.org.ng](mailto:contact@bonaventure.org.ng)  
📱 Phone: [+234 (812) 222 5406](tel:+2348122225406)

---

## 🎯 **Overview**

Student Tracker is a comprehensive student management application built with FastAPI, featuring Docker for containerization, Kubernetes for orchestration, and ArgoCD for GitOps automation. This platform provides complete deployment automation, health monitoring, and infrastructure management.

**🌐 Production URL**: [http://18.206.89.183:8011](http://18.206.89.183:8011)  
**📖 API Documentation**: [http://18.206.89.183:8011/docs](http://18.206.89.183:8011/docs)

---

## 🚀 **Quick Start - One Command Deployment**

### **🚀 Helm & ArgoCD Deployment (Recommended)**
```bash
# Clone and deploy with Helm and ArgoCD
git clone https://github.com/bonaventuresimeon/NativeSeries.git
cd NativeSeries
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**🎉 Your Student Tracker application will be live at:**
- **🌐 Application**: http://18.206.89.183:8011 (Production)
- **🔄 ArgoCD UI**: http://18.206.89.183:30080 (GitOps Management)
- **🔒 ArgoCD HTTPS**: https://18.206.89.183:30443 (Secure Access)

---

## 📁 **Project Structure**

```
NativeSeries/
├── app/                    # Application source code
│   ├── main.py            # FastAPI application entry point
│   ├── models.py          # Database models
│   ├── database.py        # Database configuration
│   ├── crud.py           # CRUD operations
│   └── routes/           # API routes
├── helm-chart/            # Helm chart for Kubernetes deployment
│   ├── templates/         # Kubernetes manifests
│   ├── Chart.yaml         # Chart metadata
│   └── values.yaml        # Configuration values
├── argocd/               # ArgoCD application manifests
├── scripts/              # Deployment and utility scripts
├── templates/            # HTML templates
├── .github/workflows/    # CI/CD pipelines
├── Dockerfile            # Container image definition
├── requirements.txt      # Python dependencies
└── README.md            # Project documentation
```

---

## 🛠️ **Deployment Options**

The deployment script provides comprehensive deployment and management capabilities:

```bash
# Full deployment with ArgoCD and application (default)
./scripts/deploy.sh

# Choose from the following options:
# 1. Install ArgoCD and deploy application
# 2. Deploy application only (ArgoCD already installed)
# 3. Build and push Docker image only
# 4. Validate configuration only
```

### **🔧 What the Deployment Script Does:**

#### **Option 1: Full Deployment**
- ✅ Installs ArgoCD server
- ✅ Builds and pushes Docker image
- ✅ Deploys Helm chart with dependencies
- ✅ Sets up ArgoCD application for GitOps
- ✅ Verifies deployment health

#### **Option 2: Application Only**
- ✅ Builds and pushes Docker image
- ✅ Deploys Helm chart with dependencies
- ✅ Sets up ArgoCD application for GitOps
- ✅ Verifies deployment health

#### **Option 3: Image Only**
- ✅ Builds and pushes Docker image
- ✅ Updates image tags in configuration

---

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   GitHub Actions│    │   Container     │
│                 │    │                 │    │   Registry      │
│  ┌───────────┐  │    │  ┌───────────┐  │    │                 │
│  │   Code    │──┼───▶│   Build    │──┼───▶│   Image         │
│  │   Push    │  │    │   & Test   │  │    │                 │
│  └───────────┘  │    └───────────┘  │    └─────────────────┘
└─────────────────┘    └─────────────────┘              │
                                                        │
┌─────────────────┐    ┌─────────────────┐              │
│   ArgoCD        │    │   Kubernetes    │              │
│   Server        │    │   Cluster       │              │
│                 │    │                 │              │
│  ┌───────────┐  │    │  ┌───────────┐  │              │
│  │   GitOps  │◀─┼────┼─▶│   Helm    │◀─┼──────────────┘
│  │   Sync    │  │    │  │   Chart   │  │
│  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘
```

---

## 📋 **Prerequisites**

### **Required Tools**
- `kubectl` (v1.24+)
- `helm` (v3.12+)
- `argocd` CLI
- `docker`
- `git`

### **Kubernetes Cluster**
- A running Kubernetes cluster (v1.24+)
- Ingress controller (nginx-ingress recommended)
- Cert-manager (for SSL certificates)
- Prometheus Operator (for monitoring)

### **Infrastructure Requirements**
- Minimum 4 CPU cores
- Minimum 8GB RAM
- Minimum 50GB storage
- Network access to container registries

---

## 🔧 **Installation**

### **1. Install Prerequisites**

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### **2. Setup Kubernetes Cluster**

```bash
# Verify cluster connectivity
kubectl cluster-info

# Install nginx-ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

### **3. Install ArgoCD**

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## ⚙️ **Configuration**

### **1. Update Helm Values**

Edit `helm-chart/values.yaml` to configure your application:

```yaml
app:
  name: student-tracker
  image:
    repository: student-tracker
    tag: latest
  replicas: 2
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

service:
  type: NodePort
  port: 80
  targetPort: 8000
  nodePort: 8011

ingress:
  enabled: true
  hosts:
    - host: 18.206.89.183
      paths:
        - path: /
          pathType: Prefix

postgresql:
  enabled: true
  auth:
    postgresPassword: "your-secure-password"
    database: studenttracker

redis:
  enabled: true
  auth:
    password: "your-redis-password"
```

### **2. Environment Variables**

Create a Kubernetes secret for sensitive data:

```bash
kubectl create secret generic app-secrets \
  --from-literal=SECRET_KEY=your-secret-key \
  --from-literal=API_KEY=your-api-key \
  -n student-tracker
```

---

## 🚀 **Deployment**

### **1. Automated Deployment (Recommended)**

The deployment is automated through GitHub Actions. Simply push to the main branch:

```bash
git add .
git commit -m "Update application"
git push origin main
```

### **2. Manual Deployment**

Use the provided deployment script:

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh
```

### **3. Helm Deployment**

Deploy manually with Helm:

```bash
# Add Bitnami repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Update dependencies
cd helm-chart
helm dependency update
cd ..

# Install chart
helm upgrade --install student-tracker helm-chart \
  --namespace student-tracker \
  --create-namespace \
  --wait \
  --timeout 10m
```

### **4. ArgoCD Deployment**

```bash
# Apply ArgoCD application
kubectl apply -f argocd/application.yaml

# Sync application
argocd app sync student-tracker --prune
```

---

## 📊 **Monitoring**

### **1. Application Metrics**

The application exposes metrics at `/metrics` endpoint. Prometheus automatically scrapes these metrics.

### **2. ArgoCD Monitoring**

Access ArgoCD UI at `http://18.206.89.183:30080`:
- Username: `admin`
- Password: Get from secret `argocd-initial-admin-secret`

**Alternative Access:**
- HTTPS: `https://18.206.89.183:30443`
- Local port-forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`

### **3. Kubernetes Monitoring**

```bash
# Check application status
kubectl get all -n student-tracker

# Check ArgoCD application status
argocd app get student-tracker

# Check logs
kubectl logs -f deployment/student-tracker -n student-tracker

# Check ingress
kubectl get ingress -n student-tracker
```

### **4. Prometheus Monitoring**

Access Prometheus at `http://localhost:9090` and Grafana at `http://localhost:3000`.

---

## 🔧 **Troubleshooting**

### **Common Issues**

1. **Image Pull Errors**
   ```bash
   # Check image pull secrets
   kubectl get secrets -n student-tracker
   
   # Create image pull secret if needed
   kubectl create secret docker-registry regcred \
     --docker-server=your-registry.com \
     --docker-username=your-username \
     --docker-password=your-password \
     -n student-tracker
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL status
   kubectl get pods -n student-tracker -l app=postgresql
   
   # Check database logs
   kubectl logs -f deployment/postgresql -n student-tracker
   ```

3. **ArgoCD Sync Issues**
   ```bash
   # Check ArgoCD application status
   argocd app get student-tracker
   
   # Force sync
   argocd app sync student-tracker --prune --force
   
   # Check ArgoCD logs
   kubectl logs -f deployment/argocd-server -n argocd
   ```

4. **Ingress Issues**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check ingress status
   kubectl describe ingress student-tracker -n student-tracker
   ```

### **Debug Commands**

```bash
# Get detailed application info
kubectl describe deployment student-tracker -n student-tracker

# Check events
kubectl get events -n student-tracker --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n student-tracker

# Check network policies
kubectl get networkpolicies -n student-tracker
```

---

## 🔒 **Security**

### **1. Network Security**

```yaml
# Network policy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: student-tracker-network-policy
  namespace: student-tracker
spec:
  podSelector:
    matchLabels:
      app: student-tracker
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
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: postgresql
    ports:
    - protocol: TCP
      port: 5432
```

### **2. RBAC Configuration**

```yaml
# Service account with minimal permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: student-tracker-sa
  namespace: student-tracker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: student-tracker-role
  namespace: student-tracker
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: student-tracker-rolebinding
  namespace: student-tracker
subjects:
- kind: ServiceAccount
  name: student-tracker-sa
  namespace: student-tracker
roleRef:
  kind: Role
  name: student-tracker-role
  apiGroup: rbac.authorization.k8s.io
```

### **3. Security Best Practices**

- Use non-root containers
- Implement resource limits
- Use secrets for sensitive data
- Enable network policies
- Regular security updates
- Monitor for vulnerabilities

---

## 🔄 **Maintenance**

### **1. Updates**

```bash
# Update Helm chart
helm upgrade student-tracker helm-chart --namespace student-tracker

# Update ArgoCD application
kubectl apply -f argocd/application.yaml
argocd app sync student-tracker
```

### **2. Backup**

```bash
# Backup PostgreSQL
kubectl exec -it deployment/postgresql -n student-tracker -- pg_dump -U postgres studenttracker > backup.sql

# Backup Kubernetes resources
kubectl get all -n student-tracker -o yaml > backup.yaml
```

### **3. Scaling**

```bash
# Scale application
kubectl scale deployment student-tracker --replicas=5 -n student-tracker

# Or update values.yaml and redeploy
```

---

## 📚 **API Documentation**

### **Available Endpoints**

- **🌐 Web Interface**: http://18.206.89.183:8011
- **📖 API Documentation**: http://18.206.89.183:8011/docs
- **🔍 ReDoc Documentation**: http://18.206.89.183:8011/redoc
- **🏥 Health Check**: http://18.206.89.183:8011/health
- **📊 Metrics**: http://18.206.89.183:8011/metrics
- **🔄 ArgoCD UI**: http://18.206.89.183:30080
- **🔒 ArgoCD HTTPS**: https://18.206.89.183:30443

### **Key Features**

- **Student Management** - Complete CRUD operations for student records
- **Course Management** - Multi-course enrollment system  
- **Progress Tracking** - Weekly progress monitoring and analytics
- **Assignment System** - Assignment creation, submission, and grading
- **Modern UI** - Responsive web interface
- **REST API** - Full RESTful API with OpenAPI documentation
- **Monitoring** - Health checks and metrics for production deployment

---

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## 📄 **License**

This project is licensed under the MIT License - see the [License.md](License.md) file for details.

---

## 🙏 **Acknowledgments**

- FastAPI community for the excellent framework
- Kubernetes community for container orchestration
- ArgoCD team for GitOps capabilities
- Docker community for containerization
- All contributors and supporters

---

**🚀 Happy Deploying!**

For issues and questions:
1. Check the troubleshooting section
2. Review ArgoCD and Helm documentation
3. Check GitHub Issues
4. Contact the development team

---

## 📞 **Support**

If issues persist after following this guide:

1. Check the logs: `kubectl logs -l app.kubernetes.io/name=student-tracker -n student-tracker`
2. Check pod events: `kubectl describe pods -n student-tracker`
3. Check service events: `kubectl describe service student-tracker -n student-tracker`
4. Run the comprehensive health check: `./scripts/deploy.sh`

---

## 🎉 **Success Indicators**

You'll know the deployment was successful when:

- ✅ `kubectl get nodes` shows your cluster nodes
- ✅ `kubectl get deployments -n student-tracker` shows student-tracker deployment
- ✅ `kubectl get pods -n student-tracker` shows running pods
- ✅ `curl http://18.206.89.183:8011/health` returns a successful response
- ✅ Application is accessible at http://18.206.89.183:8011
