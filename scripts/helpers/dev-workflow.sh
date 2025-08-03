#!/bin/bash
# Development workflow helper script

set -e

show_help() {
    echo "Development Workflow Helper"
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup       Set up local development environment"
    echo "  build       Build and deploy to local cluster"
    echo "  test        Run application tests"
    echo "  logs        Show application logs"
    echo "  port-forward Start port forwarding to local app"
    echo "  status      Show deployment status"
    echo "  clean       Clean up development resources"
    echo "  help        Show this help message"
}

setup_dev() {
    echo "🔧 Setting up development environment..."
    
    # Setup local cluster
    ./setup-local-cluster.sh
    
    # Create namespace
    kubectl create namespace student-tracker --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Development environment ready!"
}

build_and_deploy() {
    echo "🏗️ Building and deploying application..."
    
    # Build Docker image
    docker build -t student-tracker:dev .
    
    # Load image into kind if using kind
    if kind get clusters | grep -q "student-tracker"; then
        kind load docker-image student-tracker:dev --name student-tracker
    fi
    
    # Deploy with Helm
    helm upgrade --install student-tracker ./helm-chart \
        --namespace student-tracker \
        --set image.repository=student-tracker \
        --set image.tag=dev \
        --set image.pullPolicy=Never \
        --set serviceMonitor.enabled=false
    
    echo "✅ Application deployed!"
}

show_logs() {
    echo "📄 Application logs:"
    kubectl logs -n student-tracker -l app.kubernetes.io/name=student-tracker --tail=50 -f
}

port_forward() {
    echo "🔌 Starting port forwarding..."
    echo "Application will be available at: http://localhost:8080"
    kubectl port-forward -n student-tracker service/student-tracker 8080:80
}

show_status() {
    echo "📊 Deployment Status:"
    echo "===================="
    kubectl get all -n student-tracker
    echo ""
    echo "Pod Details:"
    kubectl describe pods -n student-tracker -l app.kubernetes.io/name=student-tracker
}

cleanup() {
    echo "🧹 Cleaning up development resources..."
    helm uninstall student-tracker -n student-tracker || true
    kubectl delete namespace student-tracker || true
    docker rmi student-tracker:dev || true
    echo "✅ Cleanup completed!"
}

case "${1:-help}" in
    setup)
        setup_dev
        ;;
    build)
        build_and_deploy
        ;;
    test)
        echo "🧪 Running tests..."
        # Add your test commands here
        echo "No tests configured yet"
        ;;
    logs)
        show_logs
        ;;
    port-forward|pf)
        port_forward
        ;;
    status)
        show_status
        ;;
    clean)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
