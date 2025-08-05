#!/bin/bash

# Test Monitoring Setup Script
# This script tests the monitoring, logging, and observability components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="nativeseries"
NAMESPACE="nativeseries"
MONITORING_NAMESPACE="monitoring"
LOGGING_NAMESPACE="logging"
PRODUCTION_HOST="54.166.101.159"
PRODUCTION_PORT="30011"
GRAFANA_PORT="30081"
PROMETHEUS_PORT="30082"

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}🧪 Testing Monitoring & Observability Setup${NC}"
echo ""

# Test 1: Check if all namespaces exist
print_status "Testing namespace existence..."
for ns in "$NAMESPACE" "$MONITORING_NAMESPACE" "$LOGGING_NAMESPACE"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        print_status "✅ Namespace $ns exists"
    else
        print_error "❌ Namespace $ns does not exist"
    fi
done
echo ""

# Test 2: Check application pods
print_status "Testing application deployment..."
if kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$APP_NAME" --no-headers | grep -q Running; then
    print_status "✅ Application pods are running"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$APP_NAME"
else
    print_error "❌ Application pods are not running"
fi
echo ""

# Test 3: Check monitoring stack
print_status "Testing monitoring stack..."
if kubectl get pods -n "$MONITORING_NAMESPACE" --no-headers | grep -q Running; then
    print_status "✅ Monitoring stack pods are running"
    kubectl get pods -n "$MONITORING_NAMESPACE"
else
    print_error "❌ Monitoring stack pods are not running"
fi
echo ""

# Test 4: Check logging stack
print_status "Testing logging stack..."
if kubectl get pods -n "$LOGGING_NAMESPACE" --no-headers | grep -q Running; then
    print_status "✅ Logging stack pods are running"
    kubectl get pods -n "$LOGGING_NAMESPACE"
else
    print_error "❌ Logging stack pods are not running"
fi
echo ""

# Test 5: Check secrets and configmaps
print_status "Testing secrets and configmaps..."
if kubectl get secrets -n "$NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ Application secrets exist"
else
    print_error "❌ Application secrets not found"
fi

if kubectl get configmaps -n "$NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ Application configmaps exist"
else
    print_error "❌ Application configmaps not found"
fi
echo ""

# Test 6: Check HPA
print_status "Testing Horizontal Pod Autoscaler..."
if kubectl get hpa -n "$NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ HPA exists and is configured"
    kubectl get hpa -n "$NAMESPACE"
else
    print_error "❌ HPA not found"
fi
echo ""

# Test 7: Check network policies
print_status "Testing network policies..."
if kubectl get networkpolicies -n "$NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ Network policies exist"
else
    print_error "❌ Network policies not found"
fi
echo ""

# Test 8: Check ServiceMonitor
print_status "Testing ServiceMonitor..."
if kubectl get servicemonitors -n "$MONITORING_NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ ServiceMonitor exists"
else
    print_error "❌ ServiceMonitor not found"
fi
echo ""

# Test 9: Check PrometheusRules
print_status "Testing PrometheusRules..."
if kubectl get prometheusrules -n "$MONITORING_NAMESPACE" | grep -q "$APP_NAME"; then
    print_status "✅ PrometheusRules exist"
else
    print_error "❌ PrometheusRules not found"
fi
echo ""

# Test 10: Test application health endpoint
print_status "Testing application health endpoint..."
if curl -s "http://$PRODUCTION_HOST:$PRODUCTION_PORT/health" >/dev/null; then
    print_status "✅ Application health endpoint is accessible"
else
    print_warning "⚠️  Application health endpoint not accessible (may need port forwarding)"
fi
echo ""

# Test 11: Test Grafana accessibility
print_status "Testing Grafana accessibility..."
if curl -s "http://$PRODUCTION_HOST:$GRAFANA_PORT" >/dev/null; then
    print_status "✅ Grafana is accessible"
else
    print_warning "⚠️  Grafana not accessible (may need port forwarding)"
fi
echo ""

# Test 12: Test Prometheus accessibility
print_status "Testing Prometheus accessibility..."
if curl -s "http://$PRODUCTION_HOST:$PROMETHEUS_PORT" >/dev/null; then
    print_status "✅ Prometheus is accessible"
else
    print_warning "⚠️  Prometheus not accessible (may need port forwarding)"
fi
echo ""

# Test 13: Check application logs
print_status "Testing application logs..."
if kubectl logs -n "$NAMESPACE" deployment/"$APP_NAME" --tail=10 >/dev/null 2>&1; then
    print_status "✅ Application logs are accessible"
    print_status "Recent application logs:"
    kubectl logs -n "$NAMESPACE" deployment/"$APP_NAME" --tail=5
else
    print_error "❌ Application logs not accessible"
fi
echo ""

# Test 14: Check metrics endpoint
print_status "Testing metrics endpoint..."
if kubectl port-forward svc/"$APP_NAME" -n "$NAMESPACE" 8080:8000 &>/dev/null &
then
    PF_PID=$!
    sleep 3
    if curl -s http://localhost:8080/metrics >/dev/null; then
        print_status "✅ Metrics endpoint is accessible"
    else
        print_warning "⚠️  Metrics endpoint not accessible"
    fi
    kill $PF_PID 2>/dev/null || true
else
    print_warning "⚠️  Could not port-forward to test metrics endpoint"
fi
echo ""

# Test 15: Check resource usage
print_status "Testing resource usage..."
print_status "Current resource usage:"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || print_warning "⚠️  Metrics server not available"
echo ""

# Summary
echo -e "${BLUE}📊 Test Summary${NC}"
echo "=================="
echo ""
print_status "Access URLs:"
echo "  🌐 Application: http://$PRODUCTION_HOST:$PRODUCTION_PORT"
echo "  📊 Grafana: http://$PRODUCTION_HOST:$GRAFANA_PORT (admin/admin123)"
echo "  📈 Prometheus: http://$PRODUCTION_HOST:$PROMETHEUS_PORT"
echo "  📝 Loki: http://$PRODUCTION_HOST:30083"
echo ""
print_status "Useful commands:"
echo "  # View application logs"
echo "  kubectl logs -f deployment/$APP_NAME -n $NAMESPACE"
echo ""
echo "  # Check HPA status"
echo "  kubectl get hpa -n $NAMESPACE"
echo ""
echo "  # Port forward for local access"
echo "  kubectl port-forward svc/$APP_NAME -n $NAMESPACE 8000:8000"
echo "  kubectl port-forward svc/prometheus-grafana -n $MONITORING_NAMESPACE 8081:80"
echo ""
print_status "🎉 Monitoring setup test completed!"