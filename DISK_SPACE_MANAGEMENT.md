# 💾 NativeSeries - Disk Space Management Guide

## 👨‍💻 **Author**

**Bonaventure Simeon**  
📧 Email: [contact@bonaventure.org.ng](mailto:contact@bonaventure.org.ng)  
📱 Phone: [+234 (812) 222 5406](tel:+2348122225406)

---

## 🎯 **Overview**

This guide provides comprehensive disk space management for the NativeSeries platform, including automatic cleanup, monitoring, and troubleshooting for disk space issues.

---

## 🚨 **Common Disk Space Issues**

### **1. Docker Storage Issues**
```
ERROR: failed to create cluster: command "docker run" failed with error: exit status 125
Command Output: docker: Error response from daemon: failed to copy files: write /var/lib/docker/volumes/...: no space left on device.
```

### **2. High Disk Usage**
- Disk usage >80% triggers warnings
- Disk usage >90% triggers critical alerts
- Insufficient space for new containers or images

### **3. Docker Build Failures**
- Insufficient space during image building
- Failed to copy files during container creation
- Volume mounting issues

---

## 🔧 **Automatic Disk Space Management**

### **Built-in Cleanup Features**

The NativeSeries platform includes automatic disk space management:

1. **Pre-deployment Check**: `check_disk_space()` function
2. **Automatic Cleanup**: Enhanced `cleanup_existing()` function
3. **Health Monitoring**: Disk space monitoring in health checks
4. **Warning System**: Alerts when disk usage is high

### **Disk Space Check Function**

```bash
# Function to check disk space
check_disk_space() {
    print_step "Checking disk space..."
    
    # Get available disk space
    local available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    local total_space=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
    local used_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    print_status "Disk space: ${available_space}G available out of ${total_space}G total (${used_percent}% used)"
    
    # Check if we have enough space (at least 5GB available)
    if [ "$available_space" -lt 5 ]; then
        print_warning "Low disk space detected (${available_space}G available)"
        print_status "Cleaning up Docker system to free space..."
        sudo docker system prune -af --volumes 2>/dev/null || true
        print_status "Disk space after cleanup:"
        df -h | grep -E "(Filesystem|/dev/)"
    else
        print_status "Sufficient disk space available"
    fi
}
```

---

## 📊 **Disk Space Monitoring**

### **Health Check Integration**

The health check script includes comprehensive disk space monitoring:

```bash
# Check disk space warnings
local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    print_warning "⚠️ High disk usage detected: ${disk_usage}%"
    print_status "Consider cleaning up Docker system: sudo docker system prune -af"
elif [ "$disk_usage" -gt 90 ]; then
    print_error "❌ Critical disk usage: ${disk_usage}%"
    print_status "Immediate cleanup required: sudo docker system prune -af --volumes"
else
    print_status "✅ Disk usage is healthy: ${disk_usage}%"
fi
```

### **Resource Thresholds**

| Metric | Warning Level | Critical Level | Action |
|--------|---------------|----------------|---------|
| **Disk Usage** | >80% | >90% | Automatic cleanup |
| **Available Space** | <10GB | <5GB | Immediate cleanup |
| **Docker Space** | >70% | >85% | Docker system prune |

---

## 🛠️ **Manual Disk Space Management**

### **Quick Disk Space Check**

```bash
# Check current disk usage
df -h

# Check Docker disk usage
docker system df

# Check available space
df -h / | awk 'NR==2 {print "Available: " $4 ", Used: " $5}'
```

### **Docker System Cleanup**

```bash
# Remove all unused containers, networks, images
sudo docker system prune -af

# Remove all unused containers, networks, images, and volumes
sudo docker system prune -af --volumes

# Remove specific resources
sudo docker container prune -f    # Remove stopped containers
sudo docker image prune -af       # Remove unused images
sudo docker volume prune -f       # Remove unused volumes
sudo docker network prune -f      # Remove unused networks
```

### **Kubernetes Cleanup**

```bash
# Clean up Kubernetes resources
kubectl delete pods --field-selector=status.phase=Failed
kubectl delete pods --field-selector=status.phase=Succeeded

# Clean up old deployments
kubectl delete deployment --all --grace-period=0 --force

# Clean up old services
kubectl delete service --all --grace-period=0 --force
```

### **Log File Cleanup**

```bash
# Clean up log files
sudo find /var/log -name "*.log" -size +100M -delete
sudo journalctl --vacuum-time=7d

# Clean up temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
```

---

## 🚀 **Automated Cleanup Scripts**

### **Daily Cleanup Script**

```bash
#!/bin/bash
# daily-cleanup.sh

echo "🧹 Starting daily cleanup..."

# Check disk space
echo "📊 Checking disk space..."
df -h /

# Clean up Docker system
echo "🐳 Cleaning up Docker system..."
sudo docker system prune -af --volumes

# Clean up Kubernetes resources
echo "☸️ Cleaning up Kubernetes resources..."
kubectl delete pods --field-selector=status.phase=Failed 2>/dev/null || true
kubectl delete pods --field-selector=status.phase=Succeeded 2>/dev/null || true

# Clean up log files
echo "📝 Cleaning up log files..."
sudo find /var/log -name "*.log" -size +100M -delete 2>/dev/null || true

# Final disk space check
echo "📊 Final disk space check..."
df -h /

echo "✅ Daily cleanup completed!"
```

### **Emergency Cleanup Script**

```bash
#!/bin/bash
# emergency-cleanup.sh

echo "🚨 Emergency cleanup starting..."

# Stop all containers
echo "🛑 Stopping all containers..."
sudo docker stop $(sudo docker ps -q) 2>/dev/null || true

# Remove all containers
echo "🗑️ Removing all containers..."
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true

# Remove all images
echo "🗑️ Removing all images..."
sudo docker rmi $(sudo docker images -q) 2>/dev/null || true

# Clean up everything
echo "🧹 Complete system cleanup..."
sudo docker system prune -af --volumes

# Check disk space
echo "📊 Disk space after emergency cleanup..."
df -h /

echo "✅ Emergency cleanup completed!"
```

---

## 📈 **Monitoring and Alerts**

### **Automated Monitoring**

```bash
# Add to crontab for daily disk space monitoring
0 6 * * * /path/to/disk-space-monitor.sh

# Add to crontab for weekly cleanup
0 2 * * 0 /path/to/weekly-cleanup.sh
```

### **Disk Space Monitor Script**

```bash
#!/bin/bash
# disk-space-monitor.sh

# Get disk usage percentage
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

# Check thresholds
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "🚨 CRITICAL: Disk usage is ${DISK_USAGE}%" | mail -s "CRITICAL: High Disk Usage" admin@example.com
    /path/to/emergency-cleanup.sh
elif [ "$DISK_USAGE" -gt 80 ]; then
    echo "⚠️ WARNING: Disk usage is ${DISK_USAGE}%" | mail -s "WARNING: High Disk Usage" admin@example.com
    /path/to/daily-cleanup.sh
fi
```

---

## 🔍 **Troubleshooting Disk Space Issues**

### **Common Issues and Solutions**

#### **1. "No space left on device" Error**

**Symptoms:**
```
docker: Error response from daemon: failed to copy files: write /var/lib/docker/volumes/...: no space left on device.
```

**Solution:**
```bash
# Emergency cleanup
sudo docker system prune -af --volumes
sudo docker system df
```

#### **2. Kind Cluster Creation Fails**

**Symptoms:**
```
ERROR: failed to create cluster: command "docker run" failed with error: exit status 125
```

**Solution:**
```bash
# Clean up Docker and retry
sudo docker system prune -af --volumes
kind delete cluster --name nativeseries 2>/dev/null || true
kind create cluster --name nativeseries --config infra/kind/cluster-config.yaml
```

#### **3. High Disk Usage After Deployment**

**Symptoms:**
- Disk usage >80% after deployment
- Slow system performance
- Container startup failures

**Solution:**
```bash
# Run comprehensive cleanup
sudo ./cleanup.sh
sudo docker system prune -af --volumes
df -h
```

---

## 📊 **Best Practices**

### **1. Regular Monitoring**
- Check disk space daily
- Monitor Docker disk usage
- Set up automated alerts

### **2. Proactive Cleanup**
- Run cleanup scripts regularly
- Remove unused Docker resources
- Clean up log files

### **3. Resource Management**
- Set appropriate resource limits
- Use multi-stage Docker builds
- Optimize image sizes

### **4. Monitoring Setup**
- Configure disk space alerts
- Set up automated cleanup
- Monitor resource usage trends

---

## 🎯 **Quick Commands Reference**

### **Disk Space Check:**
```bash
df -h                    # Check disk usage
docker system df         # Check Docker disk usage
du -sh /*               # Check directory sizes
```

### **Cleanup Commands:**
```bash
sudo docker system prune -af              # Clean Docker system
sudo docker system prune -af --volumes    # Clean Docker system and volumes
sudo ./cleanup.sh                        # Run NativeSeries cleanup
```

### **Monitoring Commands:**
```bash
sudo ./health-check.sh                   # Run health check with disk monitoring
df -h / | awk 'NR==2 {print $5}'        # Get disk usage percentage
docker system df --format "table"        # Detailed Docker disk usage
```

---

## 🎉 **Benefits of Disk Space Management**

1. **🚀 Reliable Deployments**: Prevents deployment failures due to disk space
2. **📊 Better Performance**: Maintains optimal system performance
3. **🛡️ System Stability**: Prevents system crashes and failures
4. **🔧 Automated Maintenance**: Reduces manual intervention
5. **📈 Proactive Monitoring**: Catches issues before they become critical
6. **💾 Efficient Resource Usage**: Optimizes storage utilization

---

**📝 Disk Space Management Guide**: August 2, 2025  
**📊 Status**: Comprehensive disk space management implemented  
**🎯 Result**: Reliable deployments with automatic disk space management