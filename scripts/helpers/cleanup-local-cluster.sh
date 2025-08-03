#!/bin/bash
# Cleanup local Kubernetes cluster

set -e

echo "🧹 Cleaning up local Kubernetes cluster..."

# Check what's running and clean up
if kind get clusters | grep -q "student-tracker"; then
    echo "Deleting kind cluster: student-tracker"
    kind delete cluster --name student-tracker
fi

if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
    echo "Stopping and deleting minikube cluster"
    minikube stop
    minikube delete
fi

echo "✅ Local cluster cleanup completed!"
