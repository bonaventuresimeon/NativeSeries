#!/usr/bin/env bash
set -euo pipefail

# Defaults per user request
DEFAULT_PUBLIC_HOST="54.166.101.159"
DEFAULT_APP_PORT="30011"
DEFAULT_ARGOCD_PORT="30080"
DEFAULT_GRAFANA_PORT="30081"
DEFAULT_PROM_PORT="30082"
DEFAULT_LOKI_PORT="30083"

# Load persisted ports from installer if present (ignore errors)
if [[ -f "$(dirname "$0")/gitops-ports.env" ]]; then
  # shellcheck disable=SC1090
  source "$(dirname "$0")/gitops-ports.env" || true
fi

# Prefer env/ports file; fall back to configured defaults
PUBLIC_HOST=${PUBLIC_HOST:-$DEFAULT_PUBLIC_HOST}
APP_PORT=${APP_PORT:-$DEFAULT_APP_PORT}
ARGOCD_PORT=${ARGOCD_PORT:-$DEFAULT_ARGOCD_PORT}
GRAFANA_PORT=${GRAFANA_PORT:-$DEFAULT_GRAFANA_PORT}
PROM_PORT=${PROM_PORT:-$DEFAULT_PROM_PORT}
LOKI_PORT=${LOKI_PORT:-$DEFAULT_LOKI_PORT}

ns_ok() { kubectl get ns "$1" >/dev/null 2>&1; }
url_ok() { curl -fsS --max-time 5 "$1" >/dev/null 2>&1; }

# Try to use the kind-gitops context if available
kubectl config use-context kind-gitops >/dev/null 2>&1 || true

echo "Using PUBLIC_HOST=${PUBLIC_HOST}"

echo "Namespaces:"
for ns in argocd nativeseries monitoring logging; do
  if ns_ok "$ns"; then
    echo "- $ns: present"
    kubectl get pods -n "$ns" || true
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