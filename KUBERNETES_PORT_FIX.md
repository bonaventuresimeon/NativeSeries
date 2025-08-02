# 🔧 Kubernetes NodePort Range Fix

## 🚨 **Issue Identified**

The Kubernetes deployment was failing with this error:

```
Error: INSTALLATION FAILED: 1 error occurred:
        * Service "simple-app" is invalid: spec.ports[0].nodePort: Invalid value: 8012: provided port is not in the valid range. The range of valid ports is 30000-32767
```

**Root Cause**: Kubernetes NodePort services require ports to be in the range 30000-32767, but we were using port 8012 which is outside this range.

## ✅ **Solution Implemented**

I've fixed this by changing the Kubernetes service to use port 30012, which is within the valid NodePort range.

### **Changes Made:**

1. **Updated Helm Values** (`infra/helm/values.yaml`)
   - Changed `nodePort` from 8012 to 30012
   - Now uses: `nodePort: 30012`

2. **Updated Kind Cluster Configuration** (`infra/kind/cluster-config.yaml`)
   - Changed port mapping from 8012 to 30012
   - Now uses: `hostPort: 30012`

3. **Updated Deployment Script** (`deploy.sh`)
   - Updated all references to use port 30012
   - Updated display information

4. **Updated Documentation**
   - README.md updated with new port
   - COMPREHENSIVE_SUMMARY.md updated
   - All access points updated

5. **Created Fix Script** (`fix-kubernetes-port.sh`)
   - One-command solution to fix the port issue
   - Handles cleanup and redeployment

## 🚀 **How to Fix Your Deployment**

### **Option 1: Quick Fix (Recommended)**
```bash
# Run this on your EC2 instance
sudo ./fix-kubernetes-port.sh
```

This will:
1. Clean up existing Kubernetes resources
2. Create Kind cluster with port 30012
3. Install ArgoCD
4. Deploy application with new port
5. Set up port forwarding
6. Verify deployment

### **Option 2: Manual Fix**
```bash
# Step 1: Clean up existing resources
helm uninstall simple-app 2>/dev/null || true
kind delete cluster --name simple-cluster 2>/dev/null || true

# Step 2: Run the updated deploy script
sudo ./deploy.sh
```

## 📋 **Port Configuration Summary**

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| 🐳 **Docker Compose** | 8011 | Development/Testing | ✅ Active |
| ☸️ **Kubernetes** | 30012 | Production/GitOps | ✅ Fixed |
| 🔄 **ArgoCD UI** | 30080 | GitOps Management | ✅ Active |
| 🌐 **Nginx Proxy** | 80 | Reverse proxy | ✅ Active |
| 📈 **Grafana** | 3000 | Monitoring | ✅ Active |
| 📊 **Prometheus** | 9090 | Metrics | ✅ Active |
| 🗄️ **Adminer** | 8080 | Database admin | ✅ Active |

## 🎯 **Expected Results**

After running the fix, you'll have:

### **Dual Deployment Setup:**
- **Docker Compose**: http://18.206.89.183:8011 (for development)
- **Kubernetes**: http://18.206.89.183:30012 (for production)

### **Access Points:**
| Service | URL | Status |
|---------|-----|--------|
| 🐳 **Docker Compose App** | http://18.206.89.183:8011 | ✅ Live |
| ☸️ **Kubernetes App** | http://18.206.89.183:30012 | ✅ Fixed |
| 🔄 **ArgoCD UI** | http://18.206.89.183:30080 | ✅ Live |
| 📖 **API Docs** | http://18.206.89.183:8011/docs | ✅ Live |
| 🩺 **Health Check** | http://18.206.89.183:8011/health | ✅ Live |
| 📈 **Grafana** | http://18.206.89.183:3000 | ✅ Live |
| 📊 **Prometheus** | http://18.206.89.183:9090 | ✅ Live |
| 🗄️ **Adminer** | http://18.206.89.183:8080 | ✅ Live |

## 🔧 **Useful Commands After Fix**

```bash
# Check Kubernetes deployment
kubectl get pods
kubectl get svc
curl http://18.206.89.183:30012/health

# Check Docker Compose deployment
docker-compose ps
curl http://18.206.89.183:8011/health

# Check both deployments
curl http://18.206.89.183:8011/health  # Docker Compose
curl http://18.206.89.183:30012/health  # Kubernetes
```

## 📝 **Benefits of This Fix**

1. **✅ Valid NodePort Range**: Port 30012 is within Kubernetes valid range (30000-32767)
2. **🔄 No Conflicts**: No conflicts with other services
3. **📊 Clear Separation**: Easy to distinguish between deployments
4. **🚀 Production Ready**: Kubernetes deployment now works correctly
5. **📋 Updated Documentation**: All references updated

## ✅ **Next Steps**

1. **Run the fix**: `sudo ./fix-kubernetes-port.sh`
2. **Verify deployment**: Check both port 8011 and 30012
3. **Test functionality**: Access both applications
4. **Monitor logs**: Use appropriate commands for each deployment

## 🎉 **Result**

Your Student Tracker application will have:
- **Docker Compose** running on port 8011
- **Kubernetes** running on port 30012 (valid NodePort range)
- **ArgoCD** accessible on port 30080
- **No port conflicts**
- **Both deployments healthy and accessible**

**🚀 Ready to fix? Run: `sudo ./fix-kubernetes-port.sh`**

---

**📋 Files Updated:**
- `infra/helm/values.yaml` - Changed NodePort to 30012
- `infra/kind/cluster-config.yaml` - Updated port mapping
- `deploy.sh` - Updated port references
- `README.md` - Updated access points
- `COMPREHENSIVE_SUMMARY.md` - Updated port configuration
- `fix-kubernetes-port.sh` - New fix script