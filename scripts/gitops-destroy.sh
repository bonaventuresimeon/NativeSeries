#!/usr/bin/env bash
set -euo pipefail

KIND_CLUSTER_NAME="gitops"

echo "Uninstalling Helm releases (ignore errors if not installed)..."
helm uninstall nativeseries -n nativeseries || true
helm uninstall kube-prometheus-stack -n monitoring || true
helm uninstall loki -n logging || true

echo "Deleting ArgoCD and namespaces..."
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml || true
kubectl delete -f ./infra/argocd/argocd-nodeport.yaml || true

for ns in nativeseries argocd monitoring logging; do
  kubectl delete ns "$ns" --ignore-not-found=true || true
done

echo "Deleting Kind cluster '$KIND_CLUSTER_NAME'..."
kind delete cluster --name "$KIND_CLUSTER_NAME" || true

echo "Done."