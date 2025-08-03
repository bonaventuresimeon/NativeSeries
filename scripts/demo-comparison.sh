#!/bin/bash

# 🎭 DEMO: Old vs New Deployment Comparison
# This script demonstrates the difference between complex ArgoCD setup and simple deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_old_way() {
    echo -e "${RED}❌ OLD WAY (Complex ArgoCD):${NC}"
    echo -e "${YELLOW}$1${NC}"
}

print_new_way() {
    echo -e "${GREEN}✅ NEW WAY (Super Simple):${NC}"
    echo -e "${CYAN}$1${NC}"
}

print_comparison() {
    echo ""
    echo -e "${BLUE}📊 COMPARISON:${NC}"
    echo "$1"
    echo ""
}

main() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
  ____  _     _   __     ___   _   _                
 / __ \| |   | | /  \   |   \ | | | |               
| |  | | |   | |/    \  | |\ \| |_| |  ___ __      __
| |  | | |   | |\    /  | | \ |  _  | / _ \\ \ /\ / /
| |__| | |___| | \  /   | |  \| | | ||  __/ \ V  V / 
 \____/|_____|_|  \/    |_|   |_| |_| \___|  \_/\_/  
                                                     
EOF
    echo -e "${NC}"
    
    print_header "🎭 DEPLOYMENT COMPARISON DEMO"
    
    echo -e "${BLUE}This demo shows the difference between:${NC}"
    echo -e "${RED}• Old Complex ArgoCD Approach${NC}"
    echo -e "${GREEN}• New Super Simple Approach${NC}"
    echo ""
    
    read -p "Press Enter to start the comparison..."
    
    # Step 1: Tool Installation
    print_header "STEP 1: TOOL INSTALLATION"
    
    print_old_way "1. Check if kubectl exists (manual install if missing)
2. Check if helm exists (manual install if missing)  
3. Check if docker exists (manual install if missing)
4. Install ArgoCD CLI manually
5. Configure each tool separately
6. Handle different OS package managers
7. Troubleshoot installation issues"
    
    print_new_way "1. Run: ./scripts/simple-deploy.sh
   → Automatically installs ALL tools
   → Handles all OS variations
   → No manual intervention needed"
    
    print_comparison "OLD: 7 manual steps, OS-specific issues
NEW: 1 command, works everywhere"
    
    read -p "Press Enter for next comparison..."
    
    # Step 2: Cluster Setup
    print_header "STEP 2: CLUSTER SETUP"
    
    print_old_way "1. Manually create Kubernetes cluster (minikube/kind)
2. Configure cluster networking
3. Set up kubectl context
4. Verify cluster connectivity
5. Install ingress controller separately
6. Configure port mappings manually"
    
    print_new_way "1. Automatically creates optimized kind cluster
2. Pre-configured with ingress and port mappings  
3. Sets kubectl context automatically
4. Includes health checks"
    
    print_comparison "OLD: 6 manual steps, easy to misconfigure
NEW: Automatic, optimized configuration"
    
    read -p "Press Enter for next comparison..."
    
    # Step 3: ArgoCD vs Direct Deploy
    print_header "STEP 3: APPLICATION DEPLOYMENT"
    
    print_old_way "1. Install ArgoCD in 'argocd' namespace
2. Wait for ArgoCD pods to be ready
3. Get ArgoCD admin password
4. Create ArgoCD application in separate namespace
5. Configure GitHub repository access
6. Wait for ArgoCD to sync from Git
7. Troubleshoot namespace permission issues
8. Debug ArgoCD sync problems"
    
    print_new_way "1. Build Docker image locally
2. Deploy app + database to single namespace
3. Set up ingress and DNS automatically
4. Everything ready in 2-3 minutes"
    
    print_comparison "OLD: 8+ steps, 2 namespaces, GitHub dependency, 10-15 minutes
NEW: 4 steps, 1 namespace, local build, 2-3 minutes"
    
    read -p "Press Enter for next comparison..."
    
    # Step 4: DNS and Access
    print_header "STEP 4: DNS AND ACCESS SETUP"
    
    print_old_way "1. Manually configure /etc/hosts
2. Remember port numbers (30011, 30080, 30443)
3. Set up port forwarding manually
4. Configure ingress rules separately
5. Test each access method individually"
    
    print_new_way "1. Automatic DNS setup (student-tracker.local)
2. Multiple access methods configured
3. Friendly URLs with no port numbers
4. Automatic health checking"
    
    print_comparison "OLD: Manual DNS, hard-to-remember ports
NEW: Automatic DNS, friendly URLs"
    
    read -p "Press Enter for next comparison..."
    
    # Step 5: Database Setup
    print_header "STEP 5: DATABASE SETUP"
    
    print_old_way "1. Install MongoDB separately
2. Configure MongoDB connection manually
3. Set up environment variables
4. Handle database networking between namespaces
5. Configure persistence volumes manually"
    
    print_new_way "1. MongoDB deployed automatically in same namespace
2. Service discovery configured automatically
3. Environment variables set automatically
4. Ready to use immediately"
    
    print_comparison "OLD: Separate database installation, complex networking
NEW: Integrated database, automatic configuration"
    
    read -p "Press Enter for next comparison..."
    
    # Step 6: Management and Troubleshooting
    print_header "STEP 6: MANAGEMENT AND TROUBLESHOOTING"
    
    print_old_way "1. Check ArgoCD namespace: kubectl get pods -n argocd
2. Check app namespace: kubectl get pods -n student-tracker
3. Debug ArgoCD sync issues
4. Check GitHub connectivity
5. Troubleshoot RBAC permissions
6. Debug cross-namespace networking
7. Multiple log sources to check"
    
    print_new_way "1. Run: ./check-status.sh (everything in one view)
2. Run: ./view-logs.sh (single log stream)
3. Run: ./cleanup.sh (remove everything)
4. All resources in one namespace"
    
    print_comparison "OLD: Complex troubleshooting across multiple systems
NEW: Simple management with helper scripts"
    
    read -p "Press Enter for final summary..."
    
    # Final Summary
    print_header "🎉 FINAL SUMMARY"
    
    echo -e "${RED}❌ OLD ARGOCD APPROACH:${NC}"
    echo "• 25+ manual steps"
    echo "• 2 namespaces (complex permissions)"
    echo "• GitHub dependency"
    echo "• 10-15 minutes deployment time"
    echo "• Requires Kubernetes expertise"
    echo "• Complex troubleshooting"
    echo "• Multiple failure points"
    echo ""
    
    echo -e "${GREEN}✅ NEW SIMPLE APPROACH:${NC}"
    echo "• 1 command deployment"
    echo "• 1 namespace (simple management)"
    echo "• No external dependencies"
    echo "• 2-3 minutes deployment time"
    echo "• Child-friendly"
    echo "• Easy troubleshooting"
    echo "• Self-contained"
    echo ""
    
    echo -e "${PURPLE}🚀 READY TO TRY THE NEW WAY?${NC}"
    echo ""
    echo -e "${CYAN}Just run: ./scripts/simple-deploy.sh${NC}"
    echo ""
    echo -e "${BLUE}That's it! Your app will be running at:${NC}"
    echo -e "${GREEN}http://student-tracker.local${NC}"
    echo ""
    
    print_header "🎊 DEMO COMPLETE!"
}

# Show help if requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "🎭 Deployment Comparison Demo"
    echo ""
    echo "This script demonstrates the difference between:"
    echo "• Complex ArgoCD deployment (old way)"
    echo "• Super simple deployment (new way)"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "The demo will walk you through each step showing:"
    echo "• What the old way required"
    echo "• What the new way does instead"
    echo "• Why the new way is better"
    exit 0
fi

main "$@"