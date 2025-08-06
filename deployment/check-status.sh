#!/bin/bash

echo "🔍 Checking deployment status on 54.166.101.159"
echo ""

echo "📱 Application Status:"
kubectl get pods,svc -n nativeseries
echo ""

echo "🎯 ArgoCD Status:"
kubectl get pods,svc -n argocd
echo ""

echo "📊 Monitoring Status:"
kubectl get pods,svc -n monitoring
echo ""

echo "🌐 Testing endpoints:"
echo "  📱 Application health: $(curl -s http://54.166.101.159:30011/health | jq -r .status 2>/dev/null || echo 'Not accessible')"
echo "  🎯 ArgoCD: $(curl -s -o /dev/null -w '%{http_code}' http://54.166.101.159:30080 2>/dev/null || echo 'Not accessible')"
echo "  📊 Grafana: $(curl -s -o /dev/null -w '%{http_code}' http://54.166.101.159:30081 2>/dev/null || echo 'Not accessible')"
echo "  📈 Prometheus: $(curl -s -o /dev/null -w '%{http_code}' http://54.166.101.159:30082 2>/dev/null || echo 'Not accessible')"
