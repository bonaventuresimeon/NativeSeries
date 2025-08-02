# 🔧 Kind Port Conflict Fix

## 🚨 **Issue Identified**

The Kind cluster creation was failing with this error:

```
ERROR: failed to create cluster: command "docker run ..." failed with error: exit status 125
docker: Error response from daemon: driver failed programming external connectivity on endpoint simple-cluster-control-plane: Bind for 0.0.0.0:8011 failed: port is already allocated.
```

**Root Cause**: Port 8011 was already in use by the Docker Compose services, causing a port conflict when Kind tried to create its cluster.

## ✅ **Solution Implemented**

I've fixed this by changing the Kind cluster to use port 8012 instead of 8011, allowing both deployments to run simultaneously.

### **Changes Made:**

1. **Updated Kind Cluster Configuration** (`infra/kind/cluster-config.yaml`)
   - Changed port from 8011 to 8012
   - Now uses: `hostPort: 8012`

2. **Updated Helm Values** (`infra/helm/values.yaml`)
   - Changed Kubernetes service port from 8011 to 8012
   - Now uses: `nodePort: 8012`

3. **Updated Deployment Script** (`deploy.sh`)
   - Added clear information about both deployment ports
   - Improved final status display

4. **Created Fix Script** (`fix-kind-deployment.sh`)
   - One-command solution to fix the port conflict
   - Handles cleanup and redeployment automatically

## 🚀 **How to Fix Your Deployment**

### **Option 1: Quick Fix (Recommended)**
```bash
# Run this on your EC2 instance
sudo ./fix-kind-deployment.sh
```

This will:
1. Clean up existing Kind clusters
2. Stop Docker Compose services temporarily
3. Create Kind cluster with port 8012
4. Deploy application to Kubernetes
5. Restart Docker Compose services
6. Verify both deployments

### **Option 2: Manual Fix**
```bash
# Step 1: Clean up existing clusters
kind delete cluster --name simple-cluster 2>/dev/null || true

# Step 2: Stop Docker Compose
docker-compose down

# Step 3: Run the updated deploy script
sudo ./deploy.sh
```

## 📋 **Port Configuration Summary**

| Service | Port | Purpose |
|---------|------|---------|
| 🐳 **Docker Compose** | 8011 | Development/Testing deployment |
| ☸️ **Kubernetes** | 8012 | Production/GitOps deployment |
| 🌐 **Nginx Proxy** | 80 | Reverse proxy |
| 📈 **Grafana** | 3000 | Monitoring dashboards |
| 📊 **Prometheus** | 9090 | Metrics collection |
| 🗄️ **Adminer** | 8080 | Database administration |

## 🎯 **Expected Results**

After running the fix, you'll have:

### **Dual Deployment Setup:**
- **Docker Compose**: http://18.206.89.183:8011 (for development)
- **Kubernetes**: http://18.206.89.183:8012 (for production)

### **Access Points:**
| Service | URL | Status |
|---------|-----|--------|
| 🐳 **Docker Compose App** | http://18.206.89.183:8011 | ✅ Live |
| ☸️ **Kubernetes App** | http://18.206.89.183:8012 | ✅ Live |
| 📖 **API Docs** | http://18.206.89.183:8011/docs | ✅ Live |
| 🩺 **Health Check** | http://18.206.89.183:8011/health | ✅ Live |
| 📈 **Grafana** | http://18.206.89.183:3000 | ✅ Live |
| 📊 **Prometheus** | http://18.206.89.183:9090 | ✅ Live |
| 🗄️ **Adminer** | http://18.206.89.183:8080 | ✅ Live |

## 🔧 **Useful Commands After Fix**

```bash
# Check Docker Compose deployment
docker-compose ps
curl http://18.206.89.183:8011/health

# Check Kubernetes deployment
kubectl get pods
kubectl get svc
curl http://18.206.89.183:8012/health

# Check both deployments
curl http://18.206.89.183:8011/health  # Docker Compose
curl http://18.206.89.183:8012/health  # Kubernetes
```

## 📝 **Benefits of This Setup**

### **Dual Deployment Advantages:**
1. **Development**: Use Docker Compose (port 8011) for quick testing
2. **Production**: Use Kubernetes (port 8012) for GitOps deployment
3. **Comparison**: Test both deployments side by side
4. **Fallback**: If one fails, the other continues working

### **Port Separation Benefits:**
1. **No Conflicts**: Each deployment uses its own port
2. **Clear Identification**: Easy to distinguish between deployments
3. **Independent Scaling**: Can scale each deployment separately
4. **Isolated Testing**: Test changes on one without affecting the other

## ✅ **Next Steps**

1. **Run the fix**: `sudo ./fix-kind-deployment.sh`
2. **Verify both deployments**: Check both port 8011 and 8012
3. **Test functionality**: Access both applications
4. **Monitor logs**: Use appropriate commands for each deployment

## 🎉 **Result**

You'll have a fully functional dual-deployment setup with:
- **Docker Compose** running on port 8011
- **Kubernetes** running on port 8012
- **No port conflicts**
- **Both deployments healthy and accessible**

**🚀 Ready to fix? Run: `sudo ./fix-kind-deployment.sh`**

---

**📋 Files Updated:**
- `infra/kind/cluster-config.yaml` - Changed port to 8012
- `infra/helm/values.yaml` - Updated service port
- `deploy.sh` - Improved status display
- `fix-kind-deployment.sh` - New fix script