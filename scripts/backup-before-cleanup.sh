#!/bin/bash

# BACKUP SCRIPT - Run BEFORE extreme cleanup
# This script creates backups of important data before machine reset

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
BACKUP_DIR="$HOME/machine-backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_ARCHIVE="$HOME/machine-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

print_header() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}💾 $1${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create backup directory
create_backup_dir() {
    print_status "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
}

# Backup Docker configurations
backup_docker() {
    print_header "🐳 Backing up Docker Configuration"
    
    if command_exists docker; then
        mkdir -p "$BACKUP_DIR/docker"
        
        # Export Docker images list
        print_status "Exporting Docker images list..."
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" > "$BACKUP_DIR/docker/images-list.txt" 2>/dev/null || true
        
        # Export running containers
        print_status "Exporting running containers list..."
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "$BACKUP_DIR/docker/containers-list.txt" 2>/dev/null || true
        
        # Export Docker Compose files
        print_status "Finding Docker Compose files..."
        find ~ -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -20 > "$BACKUP_DIR/docker/compose-files.txt" || true
        
        # Copy Docker daemon config if exists
        if [ -f "/etc/docker/daemon.json" ]; then
            sudo cp "/etc/docker/daemon.json" "$BACKUP_DIR/docker/" 2>/dev/null || true
        fi
        
        print_status "✅ Docker configuration backed up"
    else
        print_warning "Docker not found, skipping Docker backup"
    fi
}

# Backup Kubernetes configurations
backup_kubernetes() {
    print_header "☸️ Backing up Kubernetes Configuration"
    
    mkdir -p "$BACKUP_DIR/kubernetes"
    
    # Backup kubectl config
    if [ -d ~/.kube ]; then
        print_status "Backing up kubectl configuration..."
        cp -r ~/.kube "$BACKUP_DIR/kubernetes/" 2>/dev/null || true
    fi
    
    # Export Kind clusters info
    if command_exists kind; then
        print_status "Exporting Kind clusters..."
        kind get clusters > "$BACKUP_DIR/kubernetes/kind-clusters.txt" 2>/dev/null || true
    fi
    
    # Export Minikube info
    if command_exists minikube; then
        print_status "Exporting Minikube status..."
        minikube status > "$BACKUP_DIR/kubernetes/minikube-status.txt" 2>/dev/null || true
    fi
    
    # Backup Helm configurations
    if [ -d ~/.helm ]; then
        print_status "Backing up Helm configuration..."
        cp -r ~/.helm "$BACKUP_DIR/kubernetes/" 2>/dev/null || true
    fi
    
    print_status "✅ Kubernetes configuration backed up"
}

# Backup important project files
backup_project_files() {
    print_header "📁 Backing up Project Files"
    
    mkdir -p "$BACKUP_DIR/project"
    
    # Current project directory
    print_status "Backing up current project..."
    if [ -f "requirements.txt" ] || [ -f "package.json" ] || [ -f "Dockerfile" ]; then
        cp -r . "$BACKUP_DIR/project/current-project/" 2>/dev/null || true
    fi
    
    # SSH keys
    if [ -d ~/.ssh ]; then
        print_status "Backing up SSH keys..."
        cp -r ~/.ssh "$BACKUP_DIR/project/" 2>/dev/null || true
    fi
    
    # Git global configuration
    if [ -f ~/.gitconfig ]; then
        print_status "Backing up Git configuration..."
        cp ~/.gitconfig "$BACKUP_DIR/project/" 2>/dev/null || true
    fi
    
    # Environment files
    print_status "Finding environment files..."
    find ~ -maxdepth 3 -name ".env*" 2>/dev/null | head -10 | while read -r file; do
        cp "$file" "$BACKUP_DIR/project/" 2>/dev/null || true
    done
    
    print_status "✅ Project files backed up"
}

# Backup system configurations
backup_system_config() {
    print_header "⚙️ Backing up System Configuration"
    
    mkdir -p "$BACKUP_DIR/system"
    
    # Network configuration
    print_status "Backing up network configuration..."
    sudo cp /etc/hosts "$BACKUP_DIR/system/" 2>/dev/null || true
    sudo cp /etc/resolv.conf "$BACKUP_DIR/system/" 2>/dev/null || true
    
    # Installed packages list
    print_status "Exporting installed packages..."
    if command_exists apt; then
        apt list --installed > "$BACKUP_DIR/system/apt-packages.txt" 2>/dev/null || true
    elif command_exists yum; then
        yum list installed > "$BACKUP_DIR/system/yum-packages.txt" 2>/dev/null || true
    fi
    
    # Services status
    print_status "Exporting services status..."
    systemctl list-units --type=service > "$BACKUP_DIR/system/services.txt" 2>/dev/null || true
    
    # Environment variables
    print_status "Backing up environment variables..."
    env > "$BACKUP_DIR/system/environment.txt" 2>/dev/null || true
    
    print_status "✅ System configuration backed up"
}

# Create restoration script
create_restore_script() {
    print_header "📝 Creating Restoration Script"
    
    cat > "$BACKUP_DIR/RESTORE.sh" << 'EOF'
#!/bin/bash

# RESTORATION SCRIPT
# This script helps restore backed up configurations

set -euo pipefail

echo "🔄 Machine Restoration Helper"
echo "============================="
echo ""
echo "This backup contains:"
echo "  - Docker configurations and image lists"
echo "  - Kubernetes configurations (kubectl, helm)"
echo "  - Project files and SSH keys"
echo "  - System configuration backups"
echo ""
echo "To restore:"
echo ""
echo "1. Docker Images:"
echo "   - Review docker/images-list.txt"
echo "   - Pull needed images: docker pull <image:tag>"
echo ""
echo "2. Kubernetes:"
echo "   - Copy kubernetes/.kube to ~/.kube"
echo "   - Review kubernetes/kind-clusters.txt for cluster info"
echo ""
echo "3. Project Files:"
echo "   - Copy project/.ssh to ~/.ssh (chmod 600 ~/.ssh/*)"
echo "   - Copy project/.gitconfig to ~/.gitconfig"
echo ""
echo "4. System:"
echo "   - Review system/apt-packages.txt for needed packages"
echo "   - Review system/services.txt for services to enable"
echo ""
echo "⚠️  Manual review and selective restoration is recommended!"

EOF

    chmod +x "$BACKUP_DIR/RESTORE.sh"
    print_status "✅ Restoration script created"
}

# Create backup archive
create_archive() {
    print_header "📦 Creating Backup Archive"
    
    print_status "Compressing backup to: $BACKUP_ARCHIVE"
    tar -czf "$BACKUP_ARCHIVE" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
    
    # Remove uncompressed backup
    rm -rf "$BACKUP_DIR"
    
    print_status "✅ Backup archive created: $BACKUP_ARCHIVE"
}

# Main function
main() {
    print_header "💾 MACHINE BACKUP SCRIPT"
    
    print_status "Creating comprehensive backup before machine reset..."
    print_warning "This backup will help you restore important configurations later."
    echo ""
    
    # Create backup
    create_backup_dir
    backup_docker
    backup_kubernetes
    backup_project_files
    backup_system_config
    create_restore_script
    create_archive
    
    print_header "✅ BACKUP COMPLETE"
    print_status "Backup saved to: $BACKUP_ARCHIVE"
    print_status "Size: $(du -h "$BACKUP_ARCHIVE" | cut -f1)"
    echo ""
    print_warning "IMPORTANT: Copy this backup to a safe location (external drive, cloud storage)"
    print_warning "The extreme cleanup script will remove everything from this machine!"
    echo ""
    print_status "To extract backup later: tar -xzf $BACKUP_ARCHIVE"
    print_status "Then run: ./$(basename "$BACKUP_DIR")/RESTORE.sh"
}

# Run main function
main "$@"