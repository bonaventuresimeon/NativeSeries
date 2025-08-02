# 🚀 NativeSeries - Complete Application Platform

## 👨‍💻 **Author**

**Bonaventure Simeon**  
📧 Email: [contact@bonaventure.org.ng](mailto:contact@bonaventure.org.ng)  
📱 Phone: [+234 (812) 222 5406](tel:+2348122225406)

---

## 🎯 **Overview**

NativeSeries is a comprehensive student management application built with FastAPI, featuring Docker Compose for development, Kubernetes for production, and ArgoCD for GitOps. This platform provides complete deployment automation, health monitoring, and infrastructure management with integrated troubleshooting and cluster management capabilities.

---

## 🌟 **Quick Start - One Command Deployment**

### **🚀 Unified Deployment (Recommended)**
```bash
# Clone and deploy with unified script (includes all fixes and troubleshooting)
git clone <your-repository-url>
cd NativeSeries
sudo ./deploy-unified.sh
```

**🎉 Your NativeSeries application will be live at:**
- **☸️ Kubernetes**: http://18.206.89.183:30012 (Production/GitOps)
- **🔄 ArgoCD**: http://18.206.89.183:30080 (GitOps Management)

---

## 🛠️ **Unified Deployment Script Options**

The `deploy-unified.sh` script provides comprehensive deployment and management capabilities:

```bash
# Full deployment with Kubernetes + ArgoCD (default)
sudo ./deploy-unified.sh

# Troubleshoot existing deployment issues
sudo ./deploy-unified.sh --troubleshoot

# Update cluster configuration with worker nodes
sudo ./deploy-unified.sh --update-cluster

# Run comprehensive health check
sudo ./deploy-unified.sh --health-check

# Clean up all resources
sudo ./deploy-unified.sh --cleanup

# Show help
sudo ./deploy-unified.sh --help
```

### **🔧 What the Unified Script Does:**

#### **Full Deployment (`--deploy`)**
- ✅ Installs all required tools (Docker, kubectl, Kind, Helm, ArgoCD)
- ✅ Creates Kubernetes cluster with worker nodes
- ✅ Deploys NativeSeries application
- ✅ Installs ArgoCD for GitOps
- ✅ Sets up port forwarding
- ✅ Verifies deployment health
- ✅ Includes all fixes and optimizations

#### **Troubleshooting (`--troubleshoot`)**
- 🔍 Checks cluster connectivity
- 🔍 Verifies existing deployments
- 🔍 Identifies deployment issues
- 🔍 Offers redeployment options
- 🔍 Provides detailed diagnostics

#### **Cluster Update (`--update-cluster`)**
- 🔄 Creates new cluster configuration with worker nodes
- 🔄 Recreates cluster with better resource distribution
- 🔄 Redeploys application to new cluster
- 🔄 Installs ArgoCD on new cluster

#### **Health Check (`--health-check`)**
- 🏥 Comprehensive system health verification
- 🏥 Cluster status monitoring
- 🏥 Application endpoint testing
- 🏥 Resource usage analysis
- 🏥 Detailed health report

#### **Cleanup (`--cleanup`)**
- 🧹 Removes all Kubernetes resources
- 🧹 Deletes ArgoCD and applications
- 🧹 Cleans up Docker resources
- 🧹 Removes Kind cluster

---

## 🌐 **Production Access Points**

| Service | Production URL | Status | Purpose | Credentials |
|---------|----------------|--------|---------|-------------|
| ☸️ **Kubernetes App** | [http://18.206.89.183:30012](http://18.206.89.183:30012) | ✅ **LIVE** | Production/GitOps | - |
| 🔄 **ArgoCD UI** | [http://18.206.89.183:30080](http://18.206.89.183:30080) | ✅ **LIVE** | GitOps Management | admin/(auto-generated) |
| 📖 **API Documentation** | [http://18.206.89.183:8011/docs](http://18.206.89.183:8011/docs) | ✅ **LIVE** | Interactive Swagger UI | - |
| 🩺 **Health Check** | [http://18.206.89.183:8011/health](http://18.206.89.183:8011/health) | ✅ **LIVE** | System Health Status | - |
| 📊 **Metrics** | [http://18.206.89.183:8011/metrics](http://18.206.89.183:8011/metrics) | ✅ **LIVE** | Prometheus Metrics | - |
| 🌐 **Nginx Proxy** | [http://18.206.89.183:80](http://18.206.89.183:80) | ✅ **LIVE** | Load Balancer | - |
| 📈 **Grafana** | [http://18.206.89.183:3000](http://18.206.89.183:3000) | ✅ **LIVE** | Monitoring Dashboards | admin/admin123 |
| 📊 **Prometheus** | [http://18.206.89.183:9090](http://18.206.89.183:9090) | ✅ **LIVE** | Metrics Collection | - |
| 🗄️ **Database Admin** | [http://18.206.89.183:8080](http://18.206.89.183:8080) | ✅ **LIVE** | Adminer Interface | student_user/student_pass |

---

## 🚀 **Deployment Options**

### 🎯 **Complete Deployment (Kubernetes + ArgoCD)**

```bash
# Complete automated deployment with all tools and fixes
sudo ./deploy-unified.sh
```

**✅ What this does:**
- Installs all required tools (Docker, kubectl, Kind, Helm, ArgoCD)
- Creates Kubernetes cluster with worker nodes (port 30012)
- Installs ArgoCD for GitOps (port 30080)
- Sets up port forwarding for ArgoCD UI
- Verifies all services are healthy
- **Includes all fixes**: Port conflicts, deployment timeouts, naming consistency
- **Perfect for**: Production, GitOps, learning Kubernetes
- **Time**: ~10-15 minutes
- **Requirements**: 8GB+ RAM, 20GB+ disk space

### 🏥 **Health Monitoring**

```bash
# Comprehensive health check
sudo ./deploy-unified.sh --health-check
```

**✅ What this does:**
- Verifies Kubernetes deployment status
- Monitors ArgoCD application health
- Tests network connectivity
- Validates database connectivity
- Monitors resource usage
- Provides detailed health report

### 🔧 **Troubleshooting**

```bash
# Troubleshoot deployment issues
sudo ./deploy-unified.sh --troubleshoot
```

**✅ What this does:**
- Diagnoses deployment problems
- Checks cluster connectivity
- Verifies resource status
- Offers repair options
- Provides detailed diagnostics

### 🔄 **Cluster Management**

```bash
# Update cluster with worker nodes
sudo ./deploy-unified.sh --update-cluster
```

**✅ What this does:**
- Creates cluster with worker nodes
- Improves resource distribution
- Enhances reliability
- Redeploys application
- Updates ArgoCD configuration

### 🧹 **Cleanup**

```bash
# Complete cleanup of all resources
sudo ./deploy-unified.sh --cleanup
```

**✅ What this does:**
- Stops and removes all Docker containers
- Cleans up Docker images and volumes
- Removes Kubernetes cluster
- Deletes ArgoCD and applications
- Cleans temporary files and logs

---

## 🏗️ **System Architecture**

### 🎯 **High-Level Architecture**

```mermaid
graph TB
    subgraph "🌐 Internet"
        User[👤 End Users]
    end
    
    subgraph "🖥️ Production Server (18.206.89.183)"
        subgraph "🐳 Docker Compose Stack"
            Nginx[🌐 Nginx<br/>Port 80<br/>Reverse Proxy]
            
            subgraph "🎓 Application Layer"
                App[🎓 Student Tracker<br/>FastAPI<br/>Port 8011]
            end
            
            subgraph "🗄️ Data Layer"
                DB[(🗄️ PostgreSQL<br/>Port 5432)]
                Cache[(📦 Redis<br/>Port 6379)]
            end
            
            subgraph "📊 Monitoring Stack"
                Prom[📈 Prometheus<br/>Port 9090]
                Graf[📊 Grafana<br/>Port 3000]
                Admin[🛠️ Adminer<br/>Port 8080]
            end
        end
        
        subgraph "☸️ Kubernetes Cluster (Optional)"
            K8s[☸️ Kind Cluster<br/>ArgoCD GitOps<br/>Port 30012]
        end
    end
    
    User --> Nginx
    Nginx --> App
    App --> DB
    App --> Cache
    App --> Prom
    Prom --> Graf
    Admin --> DB
    
    style User fill:#e1f5fe
    style App fill:#c8e6c9
    style DB fill:#fff3e0
    style Cache fill:#f3e5f5
    style Nginx fill:#e8f5e8
    style Prom fill:#ffe0b2
    style Graf fill:#fce4ec
    style Admin fill:#e0f2f1
```

### 🐳 **Container Architecture**

```mermaid
graph LR
    subgraph "🐳 Docker Compose Services"
        subgraph "🎓 Application Services"
            ST[🎓 student-tracker<br/>Port 8011<br/>FastAPI App]
        end
        
        subgraph "🗄️ Data Services"
            PG[🗄️ postgres<br/>Port 5432<br/>Database]
            RD[📦 redis<br/>Port 6379<br/>Cache]
        end
        
        subgraph "🌐 Network Services"
            NG[🌐 nginx<br/>Port 80<br/>Reverse Proxy]
        end
        
        subgraph "📊 Monitoring Services"
            PM[📈 prometheus<br/>Port 9090<br/>Metrics]
            GF[📊 grafana<br/>Port 3000<br/>Dashboards]
            AD[🛠️ adminer<br/>Port 8080<br/>DB Admin]
        end
    end
    
    NG --> ST
    ST --> PG
    ST --> RD
    ST --> PM
    PM --> GF
    AD --> PG
    
    style ST fill:#c8e6c9
    style PG fill:#fff3e0
    style RD fill:#f3e5f5
    style NG fill:#e8f5e8
    style PM fill:#ffe0b2
    style GF fill:#fce4ec
    style AD fill:#e0f2f1
```

---

## 🛠️ **Technology Stack**

### 🎓 **Application Stack**

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Backend** | FastAPI | Latest | REST API Framework |
| **Database** | PostgreSQL | 15+ | Primary Database |
| **Cache** | Redis | 7+ | Session & Cache Store |
| **Frontend** | HTML/CSS/JS | - | Web Interface |
| **API Docs** | Swagger UI | Auto | Interactive Documentation |

### 🐳 **Container & Orchestration**

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Containerization** | Docker | 25.0+ | Application Packaging |
| **Orchestration** | Kubernetes | 1.33+ | Container Orchestration |
| **Local K8s** | Kind | 0.20+ | Local Kubernetes Cluster |
| **Package Manager** | Helm | 3.12+ | Kubernetes Package Manager |
| **GitOps** | ArgoCD | 2.8+ | Continuous Deployment |

### 📊 **Monitoring & Observability**

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Metrics** | Prometheus | 2.45+ | Metrics Collection |
| **Visualization** | Grafana | 10.0+ | Dashboards & Alerts |
| **Database Admin** | Adminer | 4.8+ | Database Management |
| **Load Balancer** | Nginx | 1.25+ | Reverse Proxy |

---

## 🔧 **Troubleshooting Guide**

### 🚨 **Common Issues & Solutions**

#### **1. Deployment Not Found Error**
```bash
Error from server (NotFound): deployments.apps "nativeseries" not found
```

**Solution:**
```bash
# Run troubleshooting
sudo ./deploy-unified.sh --troubleshoot

# Or redeploy completely
sudo ./deploy-unified.sh --update-cluster
```

#### **2. Cluster Connectivity Issues**
```bash
Cannot connect to Kubernetes cluster
```

**Solution:**
```bash
# Check cluster status
kubectl cluster-info

# Recreate cluster if needed
sudo ./deploy-unified.sh --update-cluster
```

#### **3. Application Not Responding**
```bash
Application endpoints not responding
```

**Solution:**
```bash
# Check application health
sudo ./deploy-unified.sh --health-check

# Check pod status
kubectl get pods -n student-tracker

# Check logs
kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker
```

#### **4. Port Conflicts**
```bash
Port already in use
```

**Solution:**
```bash
# Clean up and redeploy
sudo ./deploy-unified.sh --cleanup
sudo ./deploy-unified.sh
```

### 🔍 **Manual Troubleshooting Commands**

#### **Check Cluster Status**
```bash
# Check if kubectl is available
which kubectl

# Check cluster connectivity
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check all resources
kubectl get all --all-namespaces
```

#### **Check Deployment Status**
```bash
# Check namespaces
kubectl get namespaces

# Check if student-tracker namespace exists
kubectl get namespace student-tracker

# Check deployments in student-tracker namespace
kubectl get deployments -n student-tracker

# Check pods in student-tracker namespace
kubectl get pods -n student-tracker

# Check services in student-tracker namespace
kubectl get services -n student-tracker
```

#### **Check Helm Releases**
```bash
# Check if Helm is installed
which helm

# List Helm releases
helm list --all-namespaces

# Check specific release
helm status nativeseries -n student-tracker
```

#### **Check Application Logs**
```bash
# Check pod logs
kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker

# Check pod events
kubectl describe pods -n student-tracker

# Check service events
kubectl describe service nativeseries -n student-tracker
```

### 🎯 **Expected Results After Fix**

After running the fix scripts, you should see:

1. **✅ Cluster with 3 nodes** (1 control-plane + 2 workers)
2. **✅ NativeSeries deployment running** in student-tracker namespace
3. **✅ Application accessible** on port 30012
4. **✅ Health endpoints responding** at http://localhost:30012/health

### 🔍 **Verification Commands**

After fixing the deployment, verify with:

```bash
# Check cluster nodes
kubectl get nodes -o wide

# Check deployment status
kubectl get deployments -n student-tracker

# Check pod status
kubectl get pods -n student-tracker -o wide

# Check service endpoints
kubectl get endpoints -n student-tracker

# Test application health
curl http://localhost:30012/health

# Check application logs
kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker
```

---

## 📋 **Cluster Configuration**

### **Current Configuration (Single Node)**
```yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: nativeseries
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30012
    hostPort: 30012
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
```

### **Updated Configuration (With Worker Nodes)**
```yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
name: nativeseries
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30012
    hostPort: 30012
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: KubeletConfiguration
    failSwapOn: false
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    failSwapOn: false
- role: worker
  kubeadmConfigPatches:
  - |
    kind: KubeletConfiguration
    failSwapOn: false
```

---

## 🚀 **Quick Fix Commands**

For immediate resolution, run these commands in sequence:

```bash
# 1. Update cluster configuration and recreate with worker nodes
sudo ./deploy-unified.sh --update-cluster

# 2. Or troubleshoot existing deployment
sudo ./deploy-unified.sh --troubleshoot

# 3. Verify the fix
sudo ./deploy-unified.sh --health-check
```

---

## 📞 **Support**

If issues persist after following this guide:

1. Check the logs: `kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker`
2. Check pod events: `kubectl describe pods -n student-tracker`
3. Check service events: `kubectl describe service nativeseries -n student-tracker`
4. Run the comprehensive health check: `sudo ./deploy-unified.sh --health-check`

---

## 🎉 **Success Indicators**

You'll know the fix was successful when:

- ✅ `kubectl get nodes` shows 3 nodes
- ✅ `kubectl get deployments -n student-tracker` shows nativeseries deployment
- ✅ `kubectl get pods -n student-tracker` shows running pods
- ✅ `curl http://localhost:30012/health` returns a successful response
- ✅ Health check script shows green status indicators

---

## 📚 **Additional Documentation**

- **📖 Comprehensive Documentation**: [COMPREHENSIVE_DOCUMENTATION.md](COMPREHENSIVE_DOCUMENTATION.md)
- **🏥 Health Check Guide**: [HEALTH_CHECK_GUIDE.md](HEALTH_CHECK_GUIDE.md)
- **🔧 Troubleshooting Guide**: [TROUBLESHOOTING_GUIDE.md](TROUBLESHOOTING_GUIDE.md)
- **📋 Deployment Summary**: [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)

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
