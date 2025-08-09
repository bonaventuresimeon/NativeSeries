#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
KIND_CLUSTER_NAME="gitops"
KIND_CONFIG_PATH_BASE="$REPO_ROOT/infra/kind/cluster-config-with-workers.yaml"
KIND_CONFIG_PATH_TMP="/tmp/gitops-kind-config.yaml"

GRAFANA_NODEPORT_DEFAULT=30081
PROMETHEUS_NODEPORT_DEFAULT=30082
LOKI_NODEPORT_DEFAULT=30083
ARGOCD_NODEPORT_DEFAULT=30080
APP_NODEPORT_DEFAULT=30011

GRAFANA_NODEPORT=""
PROMETHEUS_NODEPORT=""
LOKI_NODEPORT=""
ARGOCD_NODEPORT=""
APP_NODEPORT=""

detect_public_host() {
  local ip
  ip=$(curl -fsSL https://checkip.amazonaws.com 2>/dev/null | tr -d '\n' | awk '{print $1}')
  if [[ -z "$ip" ]]; then
    # Try AWS IMDSv2
    local token
    token=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null)
    if [[ -n "$token" ]]; then
      ip=$(curl -fsS -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    fi
  fi
  if [[ -z "$ip" ]]; then
    ip=$(hostname -I | awk '{print $1}')
  fi
  echo "$ip"
}

PUBLIC_HOST=${PUBLIC_HOST:-$(detect_public_host)}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

prepare_host_networking() {
  if command -v alternatives >/dev/null 2>&1; then
    sudo alternatives --set iptables /usr/sbin/iptables-legacy || true
    sudo alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
    sudo alternatives --set arptables /usr/sbin/arptables-legacy || true
    sudo alternatives --set ebtables /usr/sbin/ebtables-legacy || true
  fi
  # Ensure iptables-legacy is available on Amazon Linux
  if ! iptables -V 2>/dev/null | grep -qi legacy; then
    sudo yum -y install iptables iptables-services || sudo dnf -y install iptables iptables-services || true
  fi
  sudo modprobe br_netfilter || true
  echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null || true
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables >/dev/null || true
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables >/dev/null || true
}

wait_for_docker() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now docker || true
    # Ensure ec2-user can access docker.sock immediately
    if command -v setfacl >/dev/null 2>&1; then sudo setfacl -m u:"$USER":rw /var/run/docker.sock || true; fi
  fi
  for i in {1..30}; do
    if docker info >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
}

is_port_free() { ! ss -ltn "sport = :$1" 2>/dev/null | grep -q ":$1"; }

pick_port() {
  local preferred="$1"; shift
  local candidates=("$preferred" "$@")
  for p in "${candidates[@]}"; do is_port_free "$p" && { echo "$p"; return 0; }; done
  for p in $(seq 30000 32767); do is_port_free "$p" && { echo "$p"; return 0; }; done
}

resolve_ports() {
  ARGOCD_NODEPORT=$(pick_port "$ARGOCD_NODEPORT_DEFAULT" 30480 32080 31080)
  APP_NODEPORT=$(pick_port "$APP_NODEPORT_DEFAULT" 31011 32011 30012)
  GRAFANA_NODEPORT=$(pick_port "$GRAFANA_NODEPORT_DEFAULT" 31081 32081 30084)
  PROMETHEUS_NODEPORT=$(pick_port "$PROMETHEUS_NODEPORT_DEFAULT" 31082 32082 30085)
  LOKI_NODEPORT=$(pick_port "$LOKI_NODEPORT_DEFAULT" 31083 32083 30086)
  echo "Using ports -> App:$APP_NODEPORT ArgoCD:$ARGOCD_NODEPORT Grafana:$GRAFANA_NODEPORT Prometheus:$PROMETHEUS_NODEPORT Loki:$LOKI_NODEPORT"
}

generate_kind_config() {
  sed -E \
    -e "s/hostPort: 30011/hostPort: ${APP_NODEPORT}/g" \
    -e "s/hostPort: 30080/hostPort: ${ARGOCD_NODEPORT}/g" \
    -e "s/hostPort: 30081/hostPort: ${GRAFANA_NODEPORT}/g" \
    -e "s/hostPort: 30082/hostPort: ${PROMETHEUS_NODEPORT}/g" \
    -e "s/hostPort: 30083/hostPort: ${LOKI_NODEPORT}/g" \
    "$KIND_CONFIG_PATH_BASE" > "$KIND_CONFIG_PATH_TMP"
}

generate_argocd_manifests() {
  sed -E -e "s/nodePort: [0-9]+/nodePort: ${ARGOCD_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/argocd-nodeport.yaml" > /tmp/argocd-nodeport.yaml

  sed -E -e "s/nodePort: 30081/nodePort: ${GRAFANA_NODEPORT}/" \
    -e "s/nodePort: 30082/nodePort: ${PROMETHEUS_NODEPORT}/" \
    -e "s#http://loki-stack\\.logging\\.svc\\.cluster\\.local:3100#http://loki-stack.logging.svc.cluster.local:3100#" \
    "$REPO_ROOT/infra/argocd/kube-prometheus-app.yaml" > /tmp/kube-prometheus-app.yaml

  sed -E -e "s/nodePort: 30083/nodePort: ${LOKI_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/loki-stack-app.yaml" > /tmp/loki-stack-app.yaml

  sed -E -e "s/nodePort: 30011/nodePort: ${APP_NODEPORT}/" \
    "$REPO_ROOT/infra/argocd/application.yaml" > /tmp/nativeseries-app.yaml
}

install_kubectl() { if need_cmd kubectl; then return; fi; curl -fsSLo kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; chmod +x kubectl; sudo mv kubectl /usr/local/bin/kubectl; }
install_helm() { if need_cmd helm; then return; fi; curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; }
install_kind() { if need_cmd kind; then return; fi; curl -fsSLo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64; chmod +x kind; sudo mv kind /usr/local/bin/kind; }
install_argocd_cli() { if need_cmd argocd; then return; fi; curl -fsSLo argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64; sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd; rm -f argocd-linux-amd64; }

create_cluster() {
  # Recreate docker 'kind' network if missing or broken
  docker network inspect kind >/dev/null 2>&1 || docker network create kind || true
  kind delete cluster --name "$KIND_CLUSTER_NAME" >/dev/null 2>&1 || true
  kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG_PATH_TMP"
  kubectl config use-context "kind-${KIND_CLUSTER_NAME}" >/dev/null
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s || true
  kubectl patch svc ingress-nginx-controller -n ingress-nginx --type='merge' -p '{"spec":{"type":"LoadBalancer"}}' || true
}

create_namespaces() { for ns in nativeseries argocd monitoring logging; do kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"; done; }

install_argocd() {
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml
  kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true
  kubectl apply -f /tmp/argocd-nodeport.yaml
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-prometheus-community
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  name: prometheus-community
  type: helm
  url: https://prometheus-community.github.io/helm-charts
---
apiVersion: v1
kind: Secret
metadata:
  name: repo-grafana
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  name: grafana
  type: helm
  url: https://grafana.github.io/helm-charts
EOF
  kubectl apply -f /tmp/kube-prometheus-app.yaml
  kubectl apply -f /tmp/loki-stack-app.yaml
  kubectl apply -f /tmp/nativeseries-app.yaml
  kubectl -n argocd annotate application kube-prometheus-stack argocd.argoproj.io/refresh=hard --overwrite || true
  kubectl -n argocd annotate application loki-stack argocd.argoproj.io/refresh=hard --overwrite || true
  kubectl -n argocd annotate application nativeseries argocd.argoproj.io/refresh=hard --overwrite || true
}

print_summary() {
  # Persist chosen ports
  cat > /tmp/gitops-ports.env <<EOF
PUBLIC_HOST=${PUBLIC_HOST}
APP_PORT=${APP_NODEPORT}
ARGOCD_PORT=${ARGOCD_NODEPORT}
GRAFANA_PORT=${GRAFANA_NODEPORT}
PROM_PORT=${PROMETHEUS_NODEPORT}
LOKI_PORT=${LOKI_NODEPORT}
EOF
  cp -f /tmp/gitops-ports.env "$REPO_ROOT/scripts/gitops-ports.env" 2>/dev/null || true

  echo "Deployment complete. Access endpoints:"
  echo "- App:       http://${PUBLIC_HOST}:${APP_NODEPORT}"
  echo "- ArgoCD:    http://${PUBLIC_HOST}:${ARGOCD_NODEPORT}"
  echo "- Grafana:   http://${PUBLIC_HOST}:${GRAFANA_NODEPORT}"
  echo "- Prometheus:http://${PUBLIC_HOST}:${PROMETHEUS_NODEPORT}"
  echo "- Loki:      http://${PUBLIC_HOST}:${LOKI_NODEPORT}"
  echo -n "ArgoCD admin password: "; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "<not ready yet>"; echo
}

main() {
  prepare_host_networking
  install_kubectl
  install_helm
  install_kind
  install_argocd_cli
  wait_for_docker
  resolve_ports
  generate_kind_config
  generate_argocd_manifests
  create_cluster
  create_namespaces
  install_argocd
  # Setup Python venv and install app deps for local tooling
  "$REPO_ROOT/scripts/setup-venv.sh" || true
  print_summary
}

main "$@"