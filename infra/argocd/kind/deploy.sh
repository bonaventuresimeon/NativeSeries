#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="student-tracker"
KIND_CONFIG="k8s/kind-config.yaml"
K8S_DIR="k8s"
NAMESPACE="student-tracker"
INGRESS_NAMESPACE="ingress-nginx"
INGRESS_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml"

# Set EC2 IP and derived DNS (replace with your actual IP or auto-detect)
EC2_IP="3.80.98.218"
EC2_DNS="ec2-${EC2_IP//./-}.eu-west-1.compute.amazonaws.com"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

log "✅ Starting Deployment..."

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  log "Kind cluster '$CLUSTER_NAME' already exists."
else
  log "Creating Kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

kubectl config use-context "kind-$CLUSTER_NAME"

for ns in "$NAMESPACE" "$INGRESS_NAMESPACE"; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    log "Namespace '$ns' already exists."
  else
    log "Creating namespace '$ns'..."
    kubectl create namespace "$ns"
  fi
done

if ! kubectl get deployment ingress-nginx-controller -n "$INGRESS_NAMESPACE" >/dev/null 2>&1; then
  log "Deploying ingress-nginx controller..."
  kubectl apply --validate=false -f "$INGRESS_MANIFEST_URL"
  kubectl rollout status deployment/ingress-nginx-controller -n "$INGRESS_NAMESPACE" --timeout=180s
else
  log "Ingress controller already deployed."
fi

log "Patching ingress-nginx service to LoadBalancer..."
kubectl patch svc ingress-nginx-controller -n "$INGRESS_NAMESPACE" \
  --type='json' -p='[{"op":"replace","path":"/spec/type","value":"LoadBalancer"}]'

log "Applying manifests from $K8S_DIR..."
kubectl apply -n "$NAMESPACE" --validate=false -f "$K8S_DIR/vault-secret.yaml"
kubectl apply -n "$NAMESPACE" --validate=false -f "$K8S_DIR/deployment.yaml"
kubectl apply -n "$NAMESPACE" --validate=false -f "$K8S_DIR/service.yaml"
kubectl apply -n "$NAMESPACE" --validate=false -f "$K8S_DIR/ingress.yaml"

log "Waiting for Deployment rollout to complete..."
kubectl rollout status deployment/student-tracker -n "$NAMESPACE" --timeout=180s

log "✅ Resources in namespace '$NAMESPACE':"
kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

log "🌐 Testing access to http://$EC2_DNS ..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$EC2_DNS")
if [[ "$HTTP_CODE" =~ ^2 ]]; then
  log "🎉 App is accessible via Ingress (HTTP $HTTP_CODE)!"
else
  log "⚠ App might not be reachable yet. Got HTTP $HTTP_CODE. Check DNS, security groups, and ingress logs."
fi

log "✅ Deployment complete."
