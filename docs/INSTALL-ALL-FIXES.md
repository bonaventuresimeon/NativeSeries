# Install-All.sh Script Fixes and Improvements

## 🔧 **Issues Fixed**

### **1. Configuration Alignment**
- ✅ **Fixed IP/Port Configuration**: 
  - Changed `TARGET_IP="18.208.149.195"` and `TARGET_PORT="8011"` 
  - To use `PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"` and `PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"`
  - Now aligns with existing application configuration

- ✅ **Added Missing Variables**:
  - `APP_NAME="student-tracker"`
  - `NAMESPACE="student-tracker"`
  - `ARGOCD_NAMESPACE="argocd"`
  - `DOCKER_USERNAME` and `DOCKER_IMAGE` with proper fallback handling

### **2. Repository and Path Fixes**
- ✅ **Fixed Repository URL**: Updated to match actual repo `https://github.com/bonaventuresimeon/NativeSeries.git`
- ✅ **Fixed Helm Chart Path**: Changed from `infra/helm` to existing `helm-chart` directory
- ✅ **Fixed ArgoCD Path**: Changed from `infra/argocd/parent` to existing `argocd` directory

### **3. Namespace Consistency**
- ✅ **Consistent Namespace Usage**: All operations now use `${NAMESPACE}` and `${ARGOCD_NAMESPACE}` variables
- ✅ **Fixed Deployment Target**: Changed from hardcoded `app-dev` to configurable `${NAMESPACE}`
- ✅ **ArgoCD Namespace**: All ArgoCD operations use `${ARGOCD_NAMESPACE}` consistently

### **4. Docker Image Handling**
- ✅ **Smart Dockerfile Detection**: 
  - Checks for `Dockerfile` in root first
  - Falls back to `docker/Dockerfile` if needed
  - Proper error handling if neither exists
- ✅ **Proper Image Tagging**: Uses `${DOCKER_IMAGE}:latest` with fallback to `${APP_NAME}:latest`
- ✅ **Kind Integration**: Correctly loads image into Kind cluster

### **5. Helm Chart Management**
- ✅ **Preserve Existing Files**: Doesn't overwrite existing `Chart.yaml`
- ✅ **Dynamic Configuration**: Updates `values.yaml` with current configuration variables
- ✅ **Proper Image References**: Sets correct image repository and tag in Helm deployment

### **6. ArgoCD Integration**
- ✅ **Use Existing Application**: Checks for and uses existing `application.yaml`
- ✅ **Proper Configuration**: Creates properly configured ArgoCD application if missing
- ✅ **Correct Parameters**: Sets proper Helm parameters for image repository and tag

### **7. Error Handling and Logging**
- ✅ **Consistent Logging**: All functions now use `print_status`, `print_warning`, `print_error`
- ✅ **Better Error Messages**: More descriptive error messages and warnings
- ✅ **Graceful Fallbacks**: Proper handling when files don't exist

### **8. Script Safety**
- ✅ **Improved Bash Options**: Changed from `set -e` to `set -euo pipefail` for better error handling
- ✅ **Variable Validation**: Proper variable expansion and quoting
- ✅ **Function Isolation**: Better separation of concerns between functions

## 📋 **Configuration Variables**

### **Environment Variables**
```bash
# Application Configuration
APP_NAME="student-tracker"
NAMESPACE="student-tracker" 
ARGOCD_NAMESPACE="argocd"

# Network Configuration
PRODUCTION_HOST="${PRODUCTION_HOST:-18.206.89.183}"
PRODUCTION_PORT="${PRODUCTION_PORT:-30011}"
ARGOCD_PORT="30080"

# Docker Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
DOCKER_IMAGE="${DOCKER_USERNAME:+$DOCKER_USERNAME/}student-tracker"

# Repository Configuration
REPO_URL="https://github.com/bonaventuresimeon/NativeSeries.git"
HELM_CHART_PATH="helm-chart"
ARGOCD_APP_PATH="argocd"
```

### **Tool Versions**
```bash
PYTHON_VERSION="3.11"
DOCKER_VERSION="20.10"
KUBECTL_VERSION="1.28"
HELM_VERSION="3.13"
KIND_VERSION="0.20.0"
ARGOCD_VERSION="v2.9.3"
```

## 🚀 **Usage**

### **Basic Installation**
```bash
# Full installation with all components
./scripts/install-all.sh

# With custom Docker username
DOCKER_USERNAME=yourusername ./scripts/install-all.sh

# With custom production host
PRODUCTION_HOST=your.domain.com ./scripts/install-all.sh
```

### **What Gets Installed**
1. **Python 3.11** with virtual environment
2. **Docker** with proper user permissions
3. **kubectl** for Kubernetes management
4. **Helm** for package management
5. **Kind** for local Kubernetes cluster
6. **ArgoCD CLI** for GitOps management
7. **Additional tools** (jq, tree, htop, GitHub CLI)

### **What Gets Deployed**
1. **Kind Cluster** with proper port mappings
2. **Ingress Controller** (nginx)
3. **ArgoCD** with NodePort access
4. **Application** using Helm chart
5. **GitOps Configuration** with ArgoCD

## 🔍 **Key Improvements**

### **1. Alignment with Existing Structure**
- Script now works with your existing `helm-chart/` directory
- Uses your existing `argocd/application.yaml` configuration
- Respects your existing `Dockerfile` location
- Maintains your repository structure

### **2. Proper CI/CD Integration**
- Compatible with GitHub Actions pipeline
- Uses correct image names and tags
- Proper namespace management
- ArgoCD sync policies aligned with your setup

### **3. Production Ready**
- Correct production host and port configuration
- Proper security contexts and health checks
- Resource limits and requests
- NodePort services for external access

### **4. Error Recovery**
- Graceful handling of missing files
- Proper fallback mechanisms
- Clear error messages and warnings
- Non-destructive operations on existing files

## 🛠️ **Post-Installation Commands**

### **Check Status**
```bash
# Check all components
kubectl get all -n student-tracker
kubectl get all -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# Check ingress
kubectl get ingress -A
```

### **Access Services**
```bash
# Application (via NodePort)
curl http://18.206.89.183:30011/health

# ArgoCD UI (via NodePort) 
open http://18.206.89.183:30080

# Local port forwarding
kubectl port-forward svc/student-tracker -n student-tracker 8000:80
kubectl port-forward svc/argocd-server-nodeport -n argocd 8080:80
```

### **Logs and Debugging**
```bash
# Application logs
kubectl logs -f deployment/student-tracker -n student-tracker

# ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd

# Kind cluster info
kind get clusters
kubectl cluster-info
```

## 🔄 **Integration with Pipeline**

The fixed script now properly integrates with your CI/CD pipeline:

1. **GitHub Actions** can use the same configuration variables
2. **ArgoCD** will sync with your repository automatically
3. **Helm charts** are properly configured for all environments
4. **Docker images** are tagged and managed consistently

## ⚠️ **Important Notes**

1. **Existing Files**: Script preserves your existing configurations
2. **Namespaces**: Uses `student-tracker` namespace consistently
3. **Ports**: Maps to production port 30011 correctly
4. **Images**: Handles Docker username properly with fallbacks
5. **Repository**: Points to correct GitHub repository

## 🎯 **Next Steps**

After running the fixed script:

1. **Verify Installation**: Check all pods and services are running
2. **Test Application**: Access via http://18.206.89.183:30011
3. **Configure ArgoCD**: Login and verify application sync
4. **Update Pipeline**: Ensure CI/CD variables match script configuration
5. **Monitor Deployment**: Check logs and metrics

---

The script is now fully aligned with your application structure and should work seamlessly with your existing setup!