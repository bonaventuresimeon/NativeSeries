#!/bin/bash

# EXTREME MACHINE CLEANUP SCRIPT
# WARNING: This script will completely reset your machine!
# Use with EXTREME CAUTION - This is DESTRUCTIVE and IRREVERSIBLE!

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Safety flags
FORCE_MODE=false
SKIP_CONFIRMATIONS=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE=true
            shift
            ;;
        --yes-i-am-sure)
            SKIP_CONFIRMATIONS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "EXTREME MACHINE CLEANUP SCRIPT"
            echo "================================"
            echo ""
            echo "⚠️  WARNING: This script will COMPLETELY RESET your machine!"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run              Show what would be done without executing"
            echo "  --force                Skip some safety checks (still requires confirmation)"
            echo "  --yes-i-am-sure        Skip individual confirmations (DANGEROUS!)"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "What this script does:"
            echo "  🔥 Stops and removes ALL Docker containers and images"
            echo "  🔥 Deletes ALL Kubernetes clusters (Kind, Minikube, etc.)"
            echo "  🔥 Removes ALL Docker networks and volumes"
            echo "  🔥 Cleans ALL system packages and caches"
            echo "  🔥 Resets network configuration"
            echo "  🔥 Clears ALL temporary files and logs"
            echo "  🔥 Removes development tools and environments"
            echo "  🔥 Cleans user data and configurations"
            echo ""
            echo "⚠️  THIS IS IRREVERSIBLE! Make sure you have backups!"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}🔥 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_danger() { echo -e "${RED}[DANGER]${NC} $1"; }
print_dry_run() { echo -e "${CYAN}[DRY RUN]${NC} $1"; }

# Function to execute command with dry run support
execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "$description: $cmd"
    else
        print_status "$description..."
        eval "$cmd" || {
            print_warning "Command failed (continuing): $cmd"
        }
    fi
}

# Function to ask for confirmation
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    
    if [[ "$SKIP_CONFIRMATIONS" == "true" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would ask: $message"
        return 0
    fi
    
    echo ""
    echo -e "${WHITE}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Skipped by user"
        return 1
    fi
    
    return 0
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ultimate safety check
ultimate_safety_check() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_header "DRY RUN MODE - No actual changes will be made"
        return 0
    fi
    
    print_header "⚠️  FINAL SAFETY CHECK ⚠️"
    
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                        🚨 DANGER ZONE 🚨                      ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║  This script will COMPLETELY RESET your machine!            ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║  • ALL Docker containers, images, and volumes will be       ║${NC}"
    echo -e "${RED}║    PERMANENTLY DELETED                                       ║${NC}"
    echo -e "${RED}║  • ALL Kubernetes clusters will be DESTROYED                ║${NC}"
    echo -e "${RED}║  • ALL network configurations will be RESET                 ║${NC}"
    echo -e "${RED}║  • ALL temporary files and caches will be WIPED             ║${NC}"
    echo -e "${RED}║  • ALL development environments will be REMOVED             ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║            THIS CANNOT BE UNDONE!                           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${WHITE}Are you ABSOLUTELY SURE you want to proceed?${NC}"
    echo -e "${YELLOW}Type 'RESET MY MACHINE' (exactly) to continue:${NC}"
    read -r confirmation
    
    if [[ "$confirmation" != "RESET MY MACHINE" ]]; then
        print_error "Safety check failed. Exiting for your protection."
        exit 1
    fi
    
    echo ""
    echo -e "${WHITE}Last chance! Type 'YES I AM SURE' to proceed:${NC}"
    read -r final_confirmation
    
    if [[ "$final_confirmation" != "YES I AM SURE" ]]; then
        print_error "Final confirmation failed. Exiting."
        exit 1
    fi
    
    print_danger "Proceeding with machine reset in 10 seconds..."
    print_danger "Press Ctrl+C NOW to abort!"
    sleep 10
}

# Docker cleanup functions
cleanup_docker() {
    print_header "🐳 Docker Complete Cleanup"
    
    if ! command_exists docker; then
        print_warning "Docker not installed, skipping Docker cleanup"
        return 0
    fi
    
    # Stop all running containers
    if confirm_action "Stop ALL running Docker containers?"; then
        execute_cmd "docker stop \$(docker ps -q) 2>/dev/null || true" "Stopping all containers"
    fi
    
    # Remove all containers
    if confirm_action "Remove ALL Docker containers (running and stopped)?"; then
        execute_cmd "docker rm -f \$(docker ps -aq) 2>/dev/null || true" "Removing all containers"
    fi
    
    # Remove all images
    if confirm_action "Remove ALL Docker images?"; then
        execute_cmd "docker rmi -f \$(docker images -q) 2>/dev/null || true" "Removing all images"
    fi
    
    # Remove all volumes
    if confirm_action "Remove ALL Docker volumes?"; then
        execute_cmd "docker volume rm \$(docker volume ls -q) 2>/dev/null || true" "Removing all volumes"
    fi
    
    # Remove all networks
    if confirm_action "Remove ALL custom Docker networks?"; then
        execute_cmd "docker network rm \$(docker network ls -q --filter type=custom) 2>/dev/null || true" "Removing custom networks"
    fi
    
    # System prune
    if confirm_action "Run Docker system prune (remove all unused data)?"; then
        execute_cmd "docker system prune -af --volumes" "Running system prune"
    fi
    
    # Reset Docker daemon (if possible)
    if confirm_action "Reset Docker daemon configuration?"; then
        execute_cmd "sudo systemctl stop docker 2>/dev/null || true" "Stopping Docker daemon"
        execute_cmd "sudo rm -rf /var/lib/docker/* 2>/dev/null || true" "Clearing Docker data directory"
        execute_cmd "sudo systemctl start docker 2>/dev/null || true" "Starting Docker daemon"
    fi
}

# Kubernetes cleanup
cleanup_kubernetes() {
    print_header "☸️  Kubernetes Complete Cleanup"
    
    # Kind clusters
    if command_exists kind; then
        if confirm_action "Delete ALL Kind clusters?"; then
            local clusters=$(kind get clusters 2>/dev/null || echo "")
            if [[ -n "$clusters" ]]; then
                for cluster in $clusters; do
                    execute_cmd "kind delete cluster --name $cluster" "Deleting Kind cluster: $cluster"
                done
            else
                print_status "No Kind clusters found"
            fi
        fi
    fi
    
    # Minikube cleanup
    if command_exists minikube; then
        if confirm_action "Delete ALL Minikube clusters and data?"; then
            execute_cmd "minikube delete --all --purge" "Deleting all Minikube clusters"
        fi
    fi
    
    # K3s cleanup
    if command_exists k3s-uninstall.sh; then
        if confirm_action "Uninstall K3s completely?"; then
            execute_cmd "sudo k3s-uninstall.sh" "Uninstalling K3s"
        fi
    fi
    
    # Remove kubectl config
    if confirm_action "Remove ALL kubectl configurations?"; then
        execute_cmd "rm -rf ~/.kube" "Removing kubectl config"
    fi
    
    # Remove Helm data
    if confirm_action "Remove ALL Helm data?"; then
        execute_cmd "rm -rf ~/.helm ~/.cache/helm" "Removing Helm data"
    fi
}

# Network cleanup
cleanup_network() {
    print_header "🌐 Network Configuration Reset"
    
    if confirm_action "Reset network configuration? (This may disconnect you!)"; then
        # Flush iptables
        execute_cmd "sudo iptables -F" "Flushing iptables rules"
        execute_cmd "sudo iptables -X" "Deleting custom iptables chains"
        execute_cmd "sudo iptables -t nat -F" "Flushing NAT table"
        execute_cmd "sudo iptables -t nat -X" "Deleting NAT chains"
        
        # Reset network interfaces (be very careful here)
        execute_cmd "sudo ip route flush table main" "Flushing routing table"
        
        # Restart networking (distribution-specific)
        if command_exists systemctl; then
            execute_cmd "sudo systemctl restart networking 2>/dev/null || sudo systemctl restart NetworkManager 2>/dev/null || true" "Restarting network services"
        fi
    fi
    
    # Clear DNS cache
    if confirm_action "Clear DNS cache?"; then
        execute_cmd "sudo systemctl flush-dns 2>/dev/null || sudo systemd-resolve --flush-caches 2>/dev/null || true" "Flushing DNS cache"
    fi
}

# System packages cleanup
cleanup_packages() {
    print_header "📦 System Packages Cleanup"
    
    # Detect package manager and clean
    if command_exists apt; then
        if confirm_action "Clean APT package cache and remove unused packages?"; then
            execute_cmd "sudo apt autoremove -y" "Removing unused packages"
            execute_cmd "sudo apt autoclean" "Cleaning package cache"
            execute_cmd "sudo apt clean" "Cleaning all cached packages"
        fi
        
        if confirm_action "Remove development packages? (docker, kubectl, helm, etc.)"; then
            execute_cmd "sudo apt remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io 2>/dev/null || true" "Removing Docker packages"
            execute_cmd "sudo apt remove -y kubectl helm 2>/dev/null || true" "Removing Kubernetes tools"
            execute_cmd "sudo apt autoremove -y" "Cleaning up dependencies"
        fi
    elif command_exists yum; then
        if confirm_action "Clean YUM/DNF cache and remove unused packages?"; then
            execute_cmd "sudo yum clean all" "Cleaning YUM cache"
            execute_cmd "sudo yum autoremove -y" "Removing unused packages"
        fi
        
        if confirm_action "Remove development packages?"; then
            execute_cmd "sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true" "Removing Docker packages"
            execute_cmd "sudo yum remove -y kubectl helm 2>/dev/null || true" "Removing Kubernetes tools"
        fi
    fi
    
    # Remove snap packages
    if command_exists snap; then
        if confirm_action "Remove ALL snap packages?"; then
            local snaps=$(snap list | awk 'NR>1 {print $1}' 2>/dev/null || echo "")
            for snap_pkg in $snaps; do
                execute_cmd "sudo snap remove $snap_pkg" "Removing snap: $snap_pkg"
            done
        fi
    fi
}

# File system cleanup
cleanup_filesystem() {
    print_header "🗂️  File System Deep Clean"
    
    # Temporary files
    if confirm_action "Remove ALL temporary files?"; then
        execute_cmd "sudo rm -rf /tmp/* /var/tmp/*" "Cleaning temporary directories"
        execute_cmd "rm -rf ~/.cache/*" "Cleaning user cache"
    fi
    
    # Log files
    if confirm_action "Clear ALL system logs?"; then
        execute_cmd "sudo journalctl --vacuum-time=1s" "Cleaning systemd logs"
        execute_cmd "sudo rm -rf /var/log/*.log /var/log/*/*.log" "Removing log files"
        execute_cmd "sudo rm -rf /var/log/syslog* /var/log/messages*" "Removing system logs"
    fi
    
    # User-specific cleanup
    if confirm_action "Clean user configuration and data files?"; then
        execute_cmd "rm -rf ~/.docker ~/.minikube ~/.helm ~/.kube" "Removing container/k8s configs"
        execute_cmd "rm -rf ~/.npm ~/.yarn ~/.pip" "Removing package manager caches"
        execute_cmd "rm -rf ~/.local/share/containers" "Removing container data"
    fi
    
    # Development environments
    if confirm_action "Remove development environments? (node_modules, venv, etc.)"; then
        execute_cmd "find ~ -name 'node_modules' -type d -exec rm -rf {} + 2>/dev/null || true" "Removing node_modules"
        execute_cmd "find ~ -name 'venv' -type d -exec rm -rf {} + 2>/dev/null || true" "Removing Python virtual environments"
        execute_cmd "find ~ -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true" "Removing Python cache"
    fi
    
    # Project-specific cleanup
    if confirm_action "Remove project-specific files? (.git, build artifacts, etc.)"; then
        execute_cmd "rm -rf .git .gitignore" "Removing git repository"
        execute_cmd "rm -rf build dist *.egg-info" "Removing build artifacts"
        execute_cmd "rm -rf .pytest_cache .coverage" "Removing test artifacts"
        execute_cmd "rm -rf .docker_image_name .argocd* deployment_validation_report.txt" "Removing deployment files"
    fi
}

# Service cleanup
cleanup_services() {
    print_header "🔧 Services and Processes Cleanup"
    
    # Stop development services
    if confirm_action "Stop all development-related services?"; then
        execute_cmd "sudo systemctl stop docker 2>/dev/null || true" "Stopping Docker service"
        execute_cmd "sudo systemctl disable docker 2>/dev/null || true" "Disabling Docker service"
        execute_cmd "sudo systemctl stop containerd 2>/dev/null || true" "Stopping containerd"
        execute_cmd "sudo systemctl disable containerd 2>/dev/null || true" "Disabling containerd"
    fi
    
    # Kill development processes
    if confirm_action "Kill all development processes?"; then
        execute_cmd "sudo pkill -f docker 2>/dev/null || true" "Killing Docker processes"
        execute_cmd "sudo pkill -f containerd 2>/dev/null || true" "Killing containerd processes"
        execute_cmd "sudo pkill -f kubectl 2>/dev/null || true" "Killing kubectl processes"
    fi
}

# Disk cleanup and optimization
cleanup_disk() {
    print_header "💾 Disk Cleanup and Optimization"
    
    # Free up disk space
    if confirm_action "Run aggressive disk cleanup?"; then
        execute_cmd "sudo apt autoremove --purge -y 2>/dev/null || sudo yum autoremove -y 2>/dev/null || true" "Removing unused packages"
        execute_cmd "sudo apt autoclean 2>/dev/null || sudo yum clean all 2>/dev/null || true" "Cleaning package cache"
    fi
    
    # Clear swap
    if confirm_action "Clear swap space?"; then
        execute_cmd "sudo swapoff -a && sudo swapon -a" "Clearing swap"
    fi
    
    # Clear page cache
    if confirm_action "Clear system caches?"; then
        execute_cmd "sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches" "Clearing system caches"
    fi
}

# Final system reset
final_system_reset() {
    print_header "🔄 Final System Reset"
    
    if confirm_action "Perform final system reset? (This may require a reboot)"; then
        # Reset user shell history
        execute_cmd "history -c && history -w" "Clearing shell history"
        
        # Reset environment variables
        execute_cmd "unset DOCKER_USERNAME PRODUCTION_HOST PRODUCTION_PORT" "Clearing environment variables"
        
        print_status "System reset completed!"
        print_warning "A system reboot is recommended to complete the reset process."
        
        if confirm_action "Reboot the system now?"; then
            print_danger "Rebooting system in 5 seconds..."
            sleep 5
            execute_cmd "sudo reboot" "Rebooting system"
        fi
    fi
}

# Main execution function
main() {
    print_header "🔥 EXTREME MACHINE CLEANUP SCRIPT 🔥"
    
    # Show current system state
    print_status "Current system state:"
    echo "  - Docker containers: $(docker ps -q 2>/dev/null | wc -l || echo '0')"
    echo "  - Docker images: $(docker images -q 2>/dev/null | wc -l || echo '0')"
    echo "  - Kind clusters: $(kind get clusters 2>/dev/null | wc -l || echo '0')"
    echo "  - Disk usage: $(df -h / | awk 'NR==2 {print $5}' || echo 'Unknown')"
    
    # Ultimate safety check
    ultimate_safety_check
    
    # Execute cleanup phases
    cleanup_docker
    cleanup_kubernetes
    cleanup_network
    cleanup_packages
    cleanup_filesystem
    cleanup_services
    cleanup_disk
    final_system_reset
    
    print_header "✅ MACHINE RESET COMPLETE"
    print_status "Your machine has been completely reset!"
    print_status "All Docker containers, images, Kubernetes clusters, and development data have been removed."
    print_warning "Please reboot your system to complete the reset process."
}

# Trap to handle interruption
trap 'echo -e "\n${RED}Script interrupted by user. Exiting safely.${NC}"; exit 130' INT

# Run main function
main "$@"