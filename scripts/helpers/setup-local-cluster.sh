#!/bin/bash
# Quick local Kubernetes cluster setup script

set -e

echo "🚀 Setting up local Kubernetes cluster..."

# Check if kind or minikube is available
if command -v kind >/dev/null 2>&1; then
    echo "Using kind for local cluster..."
    
    # Create kind cluster if it doesn't exist
    if ! kind get clusters | grep -q "student-tracker"; then
        echo "Creating kind cluster: student-tracker"
        kind create cluster --name student-tracker --config - <<EOL
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
EOL
    else
        echo "Kind cluster 'student-tracker' already exists"
    fi
    
    # Set kubectl context
    kubectl config use-context kind-student-tracker
    
elif command -v minikube >/dev/null 2>&1; then
    echo "Using minikube for local cluster..."
    
    # Start minikube if not running
    if ! minikube status >/dev/null 2>&1; then
        echo "Starting minikube..."
        minikube start --driver=docker --cpus=2 --memory=4096
        minikube addons enable ingress
    else
        echo "Minikube is already running"
    fi
    
    # Set kubectl context
    kubectl config use-context minikube
    
else
    echo "❌ Neither kind nor minikube is available. Please install one of them."
    exit 1
fi

echo "✅ Local Kubernetes cluster is ready!"
echo "📋 Cluster info:"
kubectl cluster-info
echo ""
echo "🔍 Available nodes:"
kubectl get nodes
