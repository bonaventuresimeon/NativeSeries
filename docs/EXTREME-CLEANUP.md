# 🔥 EXTREME MACHINE CLEANUP DOCUMENTATION

## ⚠️ CRITICAL WARNING

**THIS IS AN EXTREMELY DESTRUCTIVE OPERATION THAT WILL COMPLETELY RESET YOUR MACHINE!**

The cleanup script will:
- 🔥 **PERMANENTLY DELETE** all Docker containers, images, and volumes
- 🔥 **DESTROY** all Kubernetes clusters (Kind, Minikube, K3s, etc.)
- 🔥 **RESET** network configurations and iptables rules
- 🔥 **REMOVE** all development tools and packages
- 🔥 **WIPE** all temporary files, logs, and caches
- 🔥 **CLEAR** all user configurations and data
- 🔥 **ERASE** project files and build artifacts

**THIS CANNOT BE UNDONE!**

## 📋 Prerequisites

### Before Running Cleanup

1. **Create a Backup** (MANDATORY):
   ```bash
   ./scripts/backup-before-cleanup.sh
   ```

2. **Copy Important Data** to external storage:
   - SSH keys (`~/.ssh/`)
   - Important projects
   - Configuration files
   - Any irreplaceable data

3. **Verify Backup Location**:
   - Ensure backup is saved to external drive or cloud storage
   - Test that backup archive can be extracted

## 🛠️ Usage

### Basic Usage

```bash
# Show help and options
./scripts/cleanup.sh --help

# Dry run (see what would be done without executing)
./scripts/cleanup.sh --dry-run

# Full interactive cleanup (recommended)
./scripts/cleanup.sh

# Skip individual confirmations (DANGEROUS!)
./scripts/cleanup.sh --yes-i-am-sure

# Force mode with fewer safety checks
./scripts/cleanup.sh --force
```

### Step-by-Step Process

1. **Create Backup First**:
   ```bash
   ./scripts/backup-before-cleanup.sh
   ```

2. **Review What Will Be Cleaned**:
   ```bash
   ./scripts/cleanup.sh --dry-run
   ```

3. **Run the Cleanup**:
   ```bash
   ./scripts/cleanup.sh
   ```

4. **Follow the Safety Prompts**:
   - Type `RESET MY MACHINE` exactly when prompted
   - Type `YES I AM SURE` for final confirmation
   - Wait 10 seconds for the countdown

## 🔍 What Gets Cleaned

### 🐳 Docker Cleanup
- Stops all running containers
- Removes all containers (running and stopped)
- Deletes all Docker images
- Removes all Docker volumes
- Deletes all custom Docker networks
- Runs `docker system prune -af --volumes`
- Resets Docker daemon configuration
- Clears `/var/lib/docker/` directory

### ☸️ Kubernetes Cleanup
- Deletes ALL Kind clusters
- Removes ALL Minikube clusters and data
- Uninstalls K3s completely
- Removes kubectl configuration (`~/.kube`)
- Deletes Helm data (`~/.helm`, `~/.cache/helm`)

### 🌐 Network Reset
- Flushes all iptables rules
- Deletes custom iptables chains
- Flushes NAT table
- Resets routing table
- Restarts network services
- Clears DNS cache

### 📦 Package Cleanup
- Removes unused system packages
- Cleans package manager caches (APT/YUM)
- Removes development packages:
  - Docker packages
  - Kubernetes tools (kubectl, helm)
  - Container runtimes
- Removes ALL snap packages

### 🗂️ File System Deep Clean
- Removes ALL temporary files (`/tmp/*`, `/var/tmp/*`)
- Clears user cache (`~/.cache/*`)
- Cleans ALL system logs
- Removes container/k8s configs
- Deletes package manager caches
- Removes development environments:
  - `node_modules` directories
  - Python virtual environments (`venv`)
  - Python cache (`__pycache__`)
- Removes project artifacts:
  - Git repositories (`.git`)
  - Build artifacts (`build`, `dist`)
  - Test artifacts (`.pytest_cache`)

### 🔧 Services Cleanup
- Stops and disables Docker service
- Stops and disables containerd
- Kills all development processes

### 💾 Disk Optimization
- Aggressive package cleanup
- Clears swap space
- Drops system caches
- Frees maximum disk space

### 🔄 Final System Reset
- Clears shell history
- Resets environment variables
- Offers system reboot

## 🛡️ Safety Features

### Multiple Confirmation Levels
1. **Ultimate Safety Check**: Requires exact text input
2. **Individual Confirmations**: Each cleanup phase asks for permission
3. **10-Second Countdown**: Final chance to abort
4. **Ctrl+C Protection**: Can interrupt at any time

### Safety Options
- `--dry-run`: See what would be done without executing
- Individual confirmations for each cleanup phase
- Graceful error handling (continues on non-critical failures)
- Interrupt protection (Ctrl+C exits safely)

### Pre-Cleanup Validation
- Shows current system state
- Counts containers, images, clusters
- Displays disk usage
- Lists what will be affected

## 📦 Backup & Restore

### Automatic Backup Script

The `backup-before-cleanup.sh` script creates comprehensive backups:

```bash
./scripts/backup-before-cleanup.sh
```

**Backup Contents**:
- Docker configurations and image lists
- Kubernetes configurations (kubectl, helm)
- SSH keys and Git configuration
- Project files and environment files
- System configuration and package lists
- Network configuration
- Services status

**Backup Location**: `~/machine-backup-YYYYMMDD-HHMMSS.tar.gz`

### Restoration Process

1. **Extract Backup**:
   ```bash
   tar -xzf ~/machine-backup-YYYYMMDD-HHMMSS.tar.gz
   ```

2. **Run Restoration Helper**:
   ```bash
   cd machine-backup-YYYYMMDD-HHMMSS
   ./RESTORE.sh
   ```

3. **Manual Restoration**:
   - Review backed up configurations
   - Selectively restore needed files
   - Reinstall required packages
   - Recreate development environments

## 🚨 Emergency Procedures

### If Script Gets Interrupted
- The script handles interruption gracefully
- Partial cleanup may have occurred
- Check system state manually
- Re-run specific cleanup phases if needed

### If System Becomes Unstable
- Reboot the system: `sudo reboot`
- Boot from recovery media if needed
- Restore from system backup if available

### If Network Connectivity Lost
- Network reset may disconnect you
- Physical console access may be required
- Restart network services: `sudo systemctl restart networking`

## 🔧 Troubleshooting

### Common Issues

1. **Permission Denied Errors**:
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   
   # Run with proper sudo access
   sudo -v
   ```

2. **Docker Daemon Not Accessible**:
   ```bash
   # Start Docker daemon
   sudo systemctl start docker
   
   # Add user to docker group
   sudo usermod -a -G docker $USER
   newgrp docker
   ```

3. **Kubernetes Tools Not Found**:
   - Tools may already be removed
   - Script continues gracefully
   - No action needed

4. **Network Issues After Cleanup**:
   ```bash
   # Restart network services
   sudo systemctl restart networking
   sudo systemctl restart NetworkManager
   
   # Reset DNS
   sudo systemd-resolve --flush-caches
   ```

### Recovery Steps

1. **After Cleanup Completion**:
   - Reboot the system
   - Verify network connectivity
   - Check available disk space
   - Test basic system functions

2. **Reinstalling Development Environment**:
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install basic tools
   sudo apt install -y curl wget git
   
   # Install Docker (if needed)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Install kubectl (if needed)
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/
   ```

## 📊 Expected Results

After successful cleanup:
- **Disk Space**: Significant free space recovered
- **Memory**: All containers/processes stopped
- **Network**: Reset to default configuration
- **Services**: Only essential system services running
- **Files**: Only core system files remain
- **Packages**: Only essential system packages installed

## ⚡ Quick Reference

### Essential Commands

```bash
# Create backup (MANDATORY)
./scripts/backup-before-cleanup.sh

# Preview cleanup (safe)
./scripts/cleanup.sh --dry-run

# Full cleanup (destructive)
./scripts/cleanup.sh

# Emergency reboot
sudo reboot

# Check system status
df -h                    # Disk usage
docker ps               # Docker containers (should be empty)
kubectl get nodes       # Kubernetes (should fail)
systemctl --failed      # Failed services
```

### Safety Checklist

- [ ] ✅ Backup created and verified
- [ ] ✅ Important data copied to external storage
- [ ] ✅ Dry run completed and reviewed
- [ ] ✅ Ready to lose ALL current data
- [ ] ✅ Have recovery plan if needed
- [ ] ✅ System reboot planned after cleanup

---

## ⚠️ FINAL WARNING

**This script will completely erase your development environment and reset your machine to a clean state. Use only when you want to start completely fresh. Make sure you have proper backups and are prepared to lose all current data and configurations.**

**When in doubt, DON'T RUN IT!**