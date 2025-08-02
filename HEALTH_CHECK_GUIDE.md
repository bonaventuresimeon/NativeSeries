# 🏥 NativeSeries - Comprehensive Health Check Guide

## 🎯 **Overview**

The `health-check.sh` script provides a complete health monitoring solution for your NativeSeries application infrastructure. It checks all components including Docker Compose, Kubernetes, ArgoCD, databases, networks, and system resources.

---

## 🚀 **Quick Start**

```bash
# Run comprehensive health check
sudo ./health-check.sh
```

**📊 The script will provide:**
- Real-time health status of all services
- Performance metrics and resource usage
- Network connectivity tests
- Database connectivity verification
- Comprehensive health report
- Troubleshooting recommendations

---

## 🔍 **What Gets Checked**

### **1. 🐳 Docker Compose Health**
- **Service Status**: All Docker Compose services running
- **Individual Services**: student-tracker, postgres, redis, nginx, prometheus, grafana, adminer
- **Service Logs**: Recent error detection
- **Health Metrics**: Service count and status

### **2. ☸️ Kubernetes Health**
- **Cluster Status**: Kubernetes cluster accessibility
- **Node Status**: All cluster nodes
- **Deployment Status**: NativeSeries deployment readiness
- **Pod Status**: Pod health and running state
- **Service Status**: Kubernetes services
- **Pod Logs**: Recent application logs

### **3. 🔄 ArgoCD Health**
- **Namespace**: ArgoCD namespace existence
- **Server Status**: ArgoCD server deployment
- **Application Health**: NativeSeries application status
- **Sync Status**: GitOps synchronization status

### **4. 🌐 Network Connectivity**
- **External Connectivity**: google.com, github.com, docker.io
- **Local Ports**: 8011, 30012, 30080, 80, 3000, 9090, 8080
- **Port Accessibility**: Listening port verification

### **5. 🎯 Application Endpoints**
- **Docker Compose**: Health, API docs, metrics
- **Kubernetes**: Health, API docs, metrics
- **Monitoring**: Grafana, Prometheus, Adminer
- **Proxy**: Nginx reverse proxy

### **6. 🗄️ Database Connectivity**
- **PostgreSQL**: Connection and query testing
- **Redis**: Ping response verification
- **Database Health**: Ready state and connectivity

### **7. 📊 Resource Usage**
- **Disk Usage**: Filesystem space monitoring
- **Memory Usage**: RAM utilization
- **CPU Usage**: Processor utilization
- **Docker Resources**: Container resource usage
- **Kubernetes Resources**: Pod and node metrics

### **8. 🔧 System Services**
- **Docker**: Docker daemon status
- **Kubelet**: Kubernetes node agent
- **Containerd**: Container runtime

---

## 📋 **Health Check Output**

### **Sample Output Structure:**

```
🏥 NativeSeries Comprehensive Health Check
==========================================

[STEP] Starting comprehensive health check...

[SECTION] 🐳 Docker Compose Health Check
[INFO] Checking Docker Compose services...
[INFO] Docker Compose services status:
[INFO] ✅ student-tracker is running
[INFO] ✅ postgres is running
[INFO] ✅ redis is running
[METRIC] Docker Compose Health: 7/7 services healthy

[SECTION] ☸️ Kubernetes Health Check
[INFO] Checking Kubernetes cluster status...
[INFO] ✅ NativeSeries deployment exists
[INFO] ✅ Deployment is ready (1/1 replicas)
[INFO] ✅ Pod is running

[SECTION] 🔄 ArgoCD Health Check
[INFO] ✅ ArgoCD namespace exists
[INFO] ✅ ArgoCD server is ready
[INFO] ✅ Application health: Healthy
[INFO] ✅ Application sync: Synced

[SECTION] 🌐 Network Connectivity Check
[INFO] ✅ google.com is reachable
[INFO] ✅ github.com is reachable
[INFO] ✅ docker.io is reachable
[METRIC] External Connectivity: 3/3 hosts reachable
[INFO] ✅ Port 8011 is listening
[INFO] ✅ Port 30012 is listening
[METRIC] Local Ports: 7/7 ports listening

[SECTION] 🎯 Application Endpoints Check
[INFO] ✅ Docker Compose Health is healthy (http://localhost:8011/health)
[INFO] ✅ Kubernetes Health is healthy (http://localhost:30012/health)
[METRIC] Application Endpoints: 10/10 endpoints healthy

[SECTION] 🗄️ Database Connectivity Check
[INFO] ✅ PostgreSQL is ready
[INFO] ✅ PostgreSQL connection successful
[INFO] ✅ Redis is responding

[SECTION] 📊 Resource Usage Check
[INFO] Disk usage:
[INFO] Memory usage:
[INFO] CPU usage:
[INFO] Docker resource usage:

🏥 NATIVESERIES HEALTH REPORT
================================
📅 Generated: 2025-08-02 12:30:45
🖥️ Hostname: ip-172-31-94-61
⏱️ Uptime: up 2 days, 3 hours, 45 minutes

📊 HEALTH SUMMARY:
==================
✅ Docker Compose: Running
✅ Kubernetes: Accessible
✅ ArgoCD: Installed
✅ Application Endpoints: 3/3 healthy

🔗 ACCESS URLs:
===============
🐳 Docker Compose: http://18.206.89.183:8011
☸️ Kubernetes: http://18.206.89.183:30012
🔄 ArgoCD: http://18.206.89.183:30080
📖 API Docs: http://18.206.89.183:8011/docs
🩺 Health Check: http://18.206.89.183:8011/health

🎯 OVERALL HEALTH ASSESSMENT:
=============================
📊 Health Score: 6/6 (100%)
🎉 System is healthy!
✅ All critical services are operational

🔧 TROUBLESHOOTING COMMANDS:
============================
docker compose ps                    # Check Docker Compose status
docker compose logs -f               # View Docker Compose logs
kubectl get pods                     # Check Kubernetes pods
kubectl logs -f deployment/nativeseries  # View Kubernetes logs
kubectl get application nativeseries -n argocd  # Check ArgoCD app
curl http://localhost:8011/health    # Test Docker Compose health
curl http://localhost:30012/health   # Test Kubernetes health
```

---

## 🎯 **Health Assessment Levels**

### **🟢 Healthy (80-100%)**
- All critical services operational
- No immediate action required
- System performing optimally

### **🟡 Warning (60-79%)**
- Minor issues detected
- Some services may need attention
- Monitor closely

### **🔴 Critical (0-59%)**
- Critical issues detected
- Immediate attention required
- System may be partially or fully down

---

## 🔧 **Troubleshooting Commands**

### **Docker Compose Issues:**
```bash
# Check service status
docker compose ps

# View service logs
docker compose logs -f

# Restart services
docker compose restart

# Check specific service
docker compose logs student-tracker
```

### **Kubernetes Issues:**
```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs -f deployment/nativeseries

# Check deployment status
kubectl describe deployment nativeseries

# Check service status
kubectl get svc
```

### **ArgoCD Issues:**
```bash
# Check ArgoCD application
kubectl get application nativeseries -n argocd

# Check ArgoCD server
kubectl get pods -n argocd

# View ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

### **Network Issues:**
```bash
# Test connectivity
curl http://localhost:8011/health
curl http://localhost:30012/health

# Check listening ports
netstat -tuln | grep -E "(8011|30012|30080)"

# Test external connectivity
ping google.com
```

### **Database Issues:**
```bash
# Check PostgreSQL
docker exec $(docker ps -q -f name=postgres) pg_isready -U student_user

# Check Redis
docker exec $(docker ps -q -f name=redis) redis-cli ping

# Test database connection
docker exec $(docker ps -q -f name=postgres) psql -U student_user -d student_db -c "SELECT 1;"
```

---

## 📊 **Monitoring Integration**

### **Prometheus Metrics:**
- Application metrics available at `/metrics` endpoints
- Docker Compose: http://18.206.89.183:8011/metrics
- Kubernetes: http://18.206.89.183:30012/metrics

### **Grafana Dashboards:**
- Access at: http://18.206.89.183:3000
- Credentials: admin/admin123
- Pre-configured dashboards for monitoring

### **Health Check Endpoints:**
- Docker Compose: http://18.206.89.183:8011/health
- Kubernetes: http://18.206.89.183:30012/health

---

## 🚀 **Automated Health Monitoring**

### **Scheduled Health Checks:**
```bash
# Add to crontab for hourly health checks
0 * * * * /path/to/health-check.sh >> /var/log/nativeseries-health.log 2>&1

# Add to crontab for daily health reports
0 9 * * * /path/to/health-check.sh | mail -s "NativeSeries Daily Health Report" admin@example.com
```

### **Health Check Alerts:**
```bash
# Example alert script
#!/bin/bash
if ! ./health-check.sh; then
    echo "NativeSeries health check failed!" | mail -s "ALERT: NativeSeries Health Issues" admin@example.com
fi
```

---

## 📈 **Performance Metrics**

### **Resource Thresholds:**
- **CPU Usage**: >80% triggers warning
- **Memory Usage**: >85% triggers warning
- **Disk Usage**: >90% triggers warning
- **Service Health**: <100% triggers investigation

### **Response Time Metrics:**
- **Health Endpoint**: <2 seconds
- **API Endpoints**: <5 seconds
- **Database Queries**: <1 second

---

## 🔒 **Security Considerations**

### **Access Control:**
- Health check script requires sudo privileges
- Sensitive information is not logged
- Network tests use safe endpoints

### **Data Privacy:**
- No personal data is collected
- Only system health metrics are gathered
- Logs can be safely shared for troubleshooting

---

## 📝 **Customization**

### **Adding Custom Checks:**
```bash
# Add custom health check function
check_custom_service() {
    print_section "🔧 Custom Service Check"
    
    # Your custom check logic here
    if your_custom_check; then
        print_status "✅ Custom service is healthy"
        return 0
    else
        print_error "❌ Custom service has issues"
        return 1
    fi
}

# Add to run_health_checks function
check_custom_service && ((overall_health++))
```

### **Modifying Thresholds:**
```bash
# Adjust health assessment thresholds
if [ $health_percentage -ge 90 ]; then  # Change from 80 to 90
    print_status "🎉 System is healthy!"
elif [ $health_percentage -ge 70 ]; then  # Change from 60 to 70
    print_warning "⚠️ System has minor issues"
else
    print_error "❌ System has critical issues"
fi
```

---

## 🎉 **Benefits**

1. **🔍 Comprehensive Monitoring**: All system components checked
2. **📊 Real-time Metrics**: Live performance data
3. **🚨 Early Warning**: Issues detected before they become critical
4. **🔧 Troubleshooting**: Built-in diagnostic commands
5. **📋 Detailed Reports**: Comprehensive health summaries
6. **🔄 Continuous Monitoring**: Can be automated for ongoing health checks
7. **🌐 Network Verification**: Connectivity and port accessibility
8. **🗄️ Database Health**: Database connectivity and performance

---

## 🚀 **Next Steps**

1. **Run Health Check**: `sudo ./health-check.sh`
2. **Review Results**: Check all sections for issues
3. **Address Issues**: Use troubleshooting commands
4. **Set Up Monitoring**: Configure automated health checks
5. **Customize**: Add custom checks as needed

**🎯 Your NativeSeries application health is now fully monitored!**

---

**📝 Health Check Guide**: August 2, 2025  
**📊 Status**: Comprehensive health monitoring ready  
**🎯 Next Steps**: Run health check and monitor system