# 🔧 NativeSeries Deployment Troubleshooting Guide

## 🚨 Current Issue Analysis

Based on your health check output, the main issues are:

1. **❌ NativeSeries deployment not found** - The Kubernetes deployment wasn't created properly
2. **❌ Application endpoints not responding** - The application isn't accessible
3. **⚠️ Cluster has only control-plane node** - No worker nodes for better resource distribution

## 🔍 Root Cause Analysis

The error `Error from server (NotFound): deployments.apps "nativeseries" not found` indicates that:

1. The Helm chart was installed but the deployment wasn't created successfully
2. The deployment might be in the wrong namespace
3. The cluster configuration might need worker nodes for better resource distribution

## 🛠️ Solution Steps

### Step 1: Update Cluster Configuration for Worker Nodes

Your current cluster only has a control-plane node. Adding worker nodes will provide better resource distribution and reliability.

```bash
# Run the cluster configuration update script
./update-cluster-config.sh
```

This script will:
- Create a new cluster configuration with 2 worker nodes
- Backup your existing configuration
- Recreate the cluster with worker nodes
- Deploy the application to the new cluster

### Step 2: Fix Deployment Issues

If you prefer to fix the existing deployment without recreating the cluster:

```bash
# Run the deployment fix script
./fix-deployment.sh
```

This script will:
- Check cluster status
- Verify existing deployments
- Redeploy the application if needed
- Verify application health

### Step 3: Manual Troubleshooting Commands

If you prefer manual troubleshooting:

#### Check Cluster Status
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

#### Check Deployment Status
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

#### Check Helm Releases
```bash
# Check if Helm is installed
which helm

# List Helm releases
helm list --all-namespaces

# Check specific release
helm status nativeseries -n student-tracker
```

#### Redeploy Application
```bash
# Navigate to helm directory
cd infra/helm

# Uninstall existing release (if exists)
helm uninstall nativeseries -n student-tracker

# Create namespace
kubectl create namespace student-tracker

# Install Helm chart
helm install nativeseries . -n student-tracker --wait --timeout=10m

# Check deployment status
kubectl get deployments -n student-tracker
kubectl get pods -n student-tracker
kubectl get services -n student-tracker
```

## 🔧 Cluster Configuration Updates

### Current Configuration (Single Node)
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

### Updated Configuration (With Worker Nodes)
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

## 🎯 Expected Results After Fix

After running the fix scripts, you should see:

1. **✅ Cluster with 3 nodes** (1 control-plane + 2 workers)
2. **✅ NativeSeries deployment running** in student-tracker namespace
3. **✅ Application accessible** on port 30012
4. **✅ Health endpoints responding** at http://localhost:30012/health

## 🔍 Verification Commands

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

## 🚀 Quick Fix Commands

For immediate resolution, run these commands in sequence:

```bash
# 1. Update cluster configuration and recreate with worker nodes
./update-cluster-config.sh

# 2. Or fix existing deployment
./fix-deployment.sh

# 3. Verify the fix
./health-check.sh
```

## 📞 Support

If issues persist after following this guide:

1. Check the logs: `kubectl logs -l app.kubernetes.io/name=nativeseries -n student-tracker`
2. Check pod events: `kubectl describe pods -n student-tracker`
3. Check service events: `kubectl describe service nativeseries -n student-tracker`
4. Run the comprehensive health check: `./health-check.sh`

## 🎉 Success Indicators

You'll know the fix was successful when:

- ✅ `kubectl get nodes` shows 3 nodes
- ✅ `kubectl get deployments -n student-tracker` shows nativeseries deployment
- ✅ `kubectl get pods -n student-tracker` shows running pods
- ✅ `curl http://localhost:30012/health` returns a successful response
- ✅ Health check script shows green status indicators