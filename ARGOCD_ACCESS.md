# 🔄 ArgoCD Access Guide

## 🌐 **ArgoCD Production Access**

### **Access Information:**
- **URL**: http://18.206.89.183:30080
- **Username**: `admin`
- **Password**: Auto-generated (displayed after deployment)

## 🚀 **How to Access ArgoCD**

### **After Running deploy.sh:**
The deployment script automatically:
1. Installs ArgoCD in the Kubernetes cluster
2. Sets up port forwarding on port 30080
3. Displays the admin password in the terminal output

### **Manual Access:**
```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Set up port forwarding manually (if needed)
kubectl port-forward svc/argocd-server -n argocd 30080:443
```

## 📋 **ArgoCD Features**

### **🎯 Application Management:**
- **Application Name**: `student-tracker`
- **Source**: GitHub repository (https://github.com/bonaventuresimeon/NativeSeries)
- **Path**: `infra/helm/`
- **Target**: Kubernetes cluster

### **🔄 GitOps Workflow:**
1. **Source Control**: Changes pushed to GitHub
2. **ArgoCD Detection**: Automatically detects changes
3. **Sync Process**: Deploys updates to Kubernetes
4. **Health Monitoring**: Tracks application health

### **📊 Dashboard Features:**
- **Application Status**: Real-time deployment status
- **Resource Tree**: Visual representation of Kubernetes resources
- **Logs**: Application and deployment logs
- **Events**: Kubernetes events and notifications
- **Settings**: Application configuration

## 🔧 **Common ArgoCD Commands**

### **CLI Commands:**
```bash
# Login to ArgoCD
argocd login 18.206.89.183:30080 --username admin --password <password>

# List applications
argocd app list

# Get application status
argocd app get student-tracker

# Sync application
argocd app sync student-tracker

# View application logs
argocd app logs student-tracker

# Check application health
argocd app health student-tracker
```

### **Web UI Navigation:**
1. **Applications**: View all managed applications
2. **Settings**: Configure ArgoCD settings
3. **User Info**: Manage users and permissions
4. **Help**: Documentation and support

## 🎯 **Application Configuration**

### **Current Application Settings:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: student-tracker
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/bonaventuresimeon/NativeSeries
    targetRevision: HEAD
    path: infra/helm
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### **Sync Options:**
- **Automated Sync**: Enabled
- **Prune**: Remove resources not in Git
- **Self Heal**: Automatically fix drift
- **Retry**: 5 attempts with exponential backoff

## 📈 **Monitoring and Health**

### **Health Status Indicators:**
- 🟢 **Healthy**: Application running correctly
- 🟡 **Progressing**: Deployment in progress
- 🔴 **Degraded**: Issues detected
- ⚫ **Suspended**: Application paused

### **Sync Status:**
- ✅ **Synced**: Git and cluster in sync
- 🔄 **Out of Sync**: Differences detected
- ❌ **Sync Failed**: Deployment errors

## 🛠️ **Troubleshooting**

### **Common Issues:**

1. **Application Out of Sync**
   ```bash
   # Force sync
   argocd app sync student-tracker
   
   # Check differences
   argocd app diff student-tracker
   ```

2. **Sync Failed**
   ```bash
   # View logs
   argocd app logs student-tracker
   
   # Check events
   kubectl get events -n default
   ```

3. **Port Forward Issues**
   ```bash
   # Restart port forward
   kubectl port-forward svc/argocd-server -n argocd 30080:443
   ```

### **Debug Commands:**
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check application resources
kubectl get all -l app=student-tracker

# View ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server
```

## 🔐 **Security Considerations**

### **Access Control:**
- **Admin User**: Full access to all applications
- **Password**: Auto-generated, secure
- **HTTPS**: Secure communication (port 443 forwarded)

### **Best Practices:**
- Change default password after first login
- Use RBAC for production environments
- Enable SSO for enterprise deployments
- Regular backup of ArgoCD configuration

## 📚 **Additional Resources**

### **Documentation:**
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Kubernetes Resources](https://kubernetes.io/docs/)

### **Community:**
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [ArgoCD Slack](https://argoproj.github.io/community/join-slack/)

---

**🎉 ArgoCD is now fully integrated into your deployment pipeline!**

**Access your GitOps dashboard at: http://18.206.89.183:30080**