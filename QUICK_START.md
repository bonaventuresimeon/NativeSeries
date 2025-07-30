# 🚀 Quick Start Guide

Get the Student Tracker GitOps stack running in minutes!

## ⚡ One-Command Installation

```bash
# Clone the repository
git clone https://github.com/bonaventuresimeon/Student-Tracker.git
cd Student-Tracker

# Run the complete installation (10-20 minutes)
./scripts/install-all.sh
```

## 🎯 What Gets Installed

✅ **Python 3.11** with virtual environment  
✅ **Docker** for containerization  
✅ **kubectl** for Kubernetes management  
✅ **Helm** for package management  
✅ **Kind** for local Kubernetes cluster  
✅ **ArgoCD** for GitOps continuous delivery  
✅ **Complete application stack** ready for production  

## 🌐 Access URLs

After installation:
- **📱 Application**: http://30.80.98.218:8011
- **📖 API Docs**: http://30.80.98.218:8011/docs
- **🩺 Health Check**: http://30.80.98.218:8011/health
- **🎯 ArgoCD UI**: http://30.80.98.218:30080

## 🔑 Default Credentials

- **ArgoCD Username**: `admin`
- **ArgoCD Password**: Check `.argocd-password` file

## ✅ Verification

```bash
# Check application health
curl http://localhost:8011/health

# Check Kubernetes resources
kubectl get all -n app-dev

# Check ArgoCD
kubectl get all -n argocd
```

## 🆘 Need Help?

- **Full Documentation**: [README.md](README.md)
- **Deployment Guide**: [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)
- **Troubleshooting**: See README.md troubleshooting section

## 🛠️ Manual Installation

If you prefer step-by-step:

1. **Install Python**: `sudo apt install python3.11 python3.11-pip python3.11-venv`
2. **Install Docker**: `curl -fsSL https://get.docker.com | sh`
3. **Install kubectl**: `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`
4. **Install Helm**: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
5. **Install Kind**: `curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64`
6. **Setup cluster**: `./scripts/setup-kind.sh`
7. **Deploy**: `./scripts/deploy-all.sh`

## 🎉 Ready to Deploy!

Your complete GitOps stack is ready for development and production use! 🚀