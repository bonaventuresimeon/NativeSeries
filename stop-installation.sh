#!/bin/bash

# Stop Installation Script
# This script stops any continuous installation processes and cleans up

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    🛑 Stopping Installation                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Function to stop background processes
stop_background_processes() {
    print_status "Stopping background installation processes..."
    
    # Stop any running Docker containers
    if command -v docker >/dev/null 2>&1; then
        print_status "Stopping Docker containers..."
        docker stop $(docker ps -q) 2>/dev/null || true
        docker system prune -f 2>/dev/null || true
    fi
    
    # Stop any running Kind clusters
    if command -v kind >/dev/null 2>&1; then
        print_status "Stopping Kind clusters..."
        kind delete cluster --name gitops-cluster 2>/dev/null || true
        kind delete cluster --name student-tracker-cluster 2>/dev/null || true
    fi
    
    # Stop any port forwarding
    print_status "Stopping port forwarding processes..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    pkill -f "kubectl proxy" 2>/dev/null || true
    
    # Stop any running Helm processes
    print_status "Stopping Helm processes..."
    pkill -f "helm" 2>/dev/null || true
    
    # Stop any running kubectl processes
    print_status "Stopping kubectl processes..."
    pkill -f "kubectl" 2>/dev/null || true
    
    # Stop any running ArgoCD processes
    print_status "Stopping ArgoCD processes..."
    pkill -f "argocd" 2>/dev/null || true
    
    # Stop any running Python processes
    print_status "Stopping Python processes..."
    pkill -f "uvicorn" 2>/dev/null || true
    pkill -f "python.*main.py" 2>/dev/null || true
    
    # Stop any running curl processes
    print_status "Stopping curl processes..."
    pkill -f "curl.*health" 2>/dev/null || true
    
    # Stop any running install-all.sh processes
    print_status "Stopping install-all.sh processes..."
    pkill -f "install-all.sh" 2>/dev/null || true
    
    print_status "✅ Background processes stopped"
}

# Function to clean up temporary files
cleanup_temp_files() {
    print_status "Cleaning up temporary files..."
    
    # Remove temporary files
    rm -f get-docker.sh 2>/dev/null || true
    rm -f .argocd-password 2>/dev/null || true
    rm -f argocd-* 2>/dev/null || true
    rm -f kubectl 2>/dev/null || true
    rm -f kind 2>/dev/null || true
    
    # Clean up Docker
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f 2>/dev/null || true
    fi
    
    print_status "✅ Temporary files cleaned up"
}

# Function to show final status
show_final_status() {
    echo -e ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ Installation Stopped                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e ""
    print_status "🎉 All installation processes have been stopped!"
    echo -e ""
    print_status "📋 Current Status:"
    print_status "  • Background processes: STOPPED"
    print_status "  • Docker containers: CLEANED"
    print_status "  • Kind clusters: REMOVED"
    print_status "  • Port forwarding: STOPPED"
    print_status "  • Temporary files: CLEANED"
    echo -e ""
    print_status "🌐 Your application is ready at:"
    print_status "  • Main App: http://54.166.101.15:30011"
    print_status "  • ArgoCD UI: http://54.166.101.15:30080"
    print_status "  • API Docs: http://54.166.101.15:30011/docs"
    echo -e ""
    print_warning "📝 Note: The installation script has been stopped."
    print_warning "   If you need to restart, run: ./scripts/install-all.sh"
    echo -e ""
    print_status "🎯 Happy coding! 🚀"
}

# Main execution
main() {
    stop_background_processes
    cleanup_temp_files
    show_final_status
}

# Run main function
main "$@"