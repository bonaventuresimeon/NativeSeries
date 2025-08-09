#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST=${PUBLIC_HOST:-$(curl -fsSL https://checkip.amazonaws.com || hostname -I | awk '{print $1}')}
APP_PORT=${APP_PORT:-30011}
ARGOCD_PORT=${ARGOCD_PORT:-30080}
GRAFANA_PORT=${GRAFANA_PORT:-30081}
PROM_PORT=${PROM_PORT:-30082}
LOKI_PORT=${LOKI_PORT:-30083}

ns_ok() { kubectl get ns "$1" >/dev/null 2>&1; }
url_ok() { curl -fsS --max-time 5 "$1" >/dev/null 2>&1; }

kubectl config use-context kind-gitops >/dev/null 2>&1 || true

echo "Namespaces:"
for ns in argocd nativeseries monitoring logging; do
  if ns_ok "$ns"; then
    echo "- $ns: present"
    kubectl get pods -n "$ns"
  else
    echo "- $ns: missing"
  fi
done

echo
echo "ArgoCD Applications:"
kubectl -n argocd get applications || true

echo
echo "Service URLs:"
APP_URL="http://${PUBLIC_HOST}:${APP_PORT}"
ARGOCD_URL="http://${PUBLIC_HOST}:${ARGOCD_PORT}"
GRAFANA_URL="http://${PUBLIC_HOST}:${GRAFANA_PORT}"
PROM_URL="http://${PUBLIC_HOST}:${PROM_PORT}"
LOKI_URL="http://${PUBLIC_HOST}:${LOKI_PORT}"

echo "- App:       $APP_URL ($(url_ok "$APP_URL" && echo OK || echo FAIL))"
echo "- ArgoCD:    $ARGOCD_URL ($(url_ok "$ARGOCD_URL" && echo OK || echo FAIL))"
echo "- Grafana:   $GRAFANA_URL ($(url_ok "$GRAFANA_URL" && echo OK || echo FAIL))"
echo "- Prometheus:$PROM_URL ($(url_ok "$PROM_URL" && echo OK || echo FAIL))"
echo "- Loki:      $LOKI_URL ($(url_ok "$LOKI_URL" && echo OK || echo FAIL))"