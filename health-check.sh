#!/bin/bash

# =============================================================================
# 🏥 NATIVESERIES - COMPREHENSIVE HEALTH CHECK SCRIPT
# =============================================================================
# This script provides a complete health check for the NativeSeries application
# including Docker Compose, Kubernetes, ArgoCD, and network infrastructure.
#
# Features:
# - Docker Compose service health
# - Kubernetes deployment status
# - ArgoCD application health
# - Network connectivity tests
# - Database connectivity
# - Application endpoints
# - Resource usage monitoring
# - Performance metrics
#
# Usage: sudo ./health-check.sh
# =============================================================================

set -e

echo "🏥 Starting NativeSeries comprehensive health check..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1"
}

print_metric() {
    echo -e "${CYAN}[METRIC]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a service is responding
check_service() {
    local url=$1
    local name=$2
    local timeout=${3:-10}
    
    if curl -s --max-time $timeout "$url" >/dev/null 2>&1; then
        print_status "✅ $name is healthy ($url)"
        return 0
    else
        print_error "❌ $name is not responding ($url)"
        return 1
    fi
}

# Function to check Docker daemon
check_docker() {
    print_section "🐳 Docker Health Check"
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    print_status "✅ Docker daemon is running"
    print_status "Docker version: $(docker --version)"
    
    return 0
}

# Function to check Kubernetes deployment
check_kubernetes() {
    print_section "☸️ Kubernetes Health Check"
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed"
        return 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Kubernetes cluster is not accessible"
        return 1
    fi
    
    print_status "Checking Kubernetes cluster status..."
    kubectl cluster-info
    
    print_status "Checking nodes..."
    kubectl get nodes
    
    print_status "Checking NativeSeries deployment..."
    
    # Check if deployment exists
    if kubectl get deployment nativeseries 2>/dev/null; then
        print_status "✅ NativeSeries deployment exists"
        
        # Check deployment status
        local ready_replicas=$(kubectl get deployment nativeseries -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment nativeseries -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            print_status "✅ Deployment is ready ($ready_replicas/$desired_replicas replicas)"
        else
            print_error "❌ Deployment is not ready ($ready_replicas/$desired_replicas replicas)"
        fi
        
        # Check pods
        print_status "Checking pods..."
        kubectl get pods -l app=nativeseries
        
        # Check pod status
        local pod_status=$(kubectl get pods -l app=nativeseries -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$pod_status" = "Running" ]; then
            print_status "✅ Pod is running"
        else
            print_error "❌ Pod status: $pod_status"
        fi
        
        # Check services
        print_status "Checking services..."
        kubectl get svc -l app=nativeseries
        
        # Check recent pod logs
        print_status "Checking recent pod logs..."
        kubectl logs -l app=nativeseries --tail=10 2>/dev/null || print_warning "No logs available"
        
    else
        print_error "❌ NativeSeries deployment not found"
        return 1
    fi
    
    return 0
}

# Function to check ArgoCD
check_argocd() {
    print_section "🔄 ArgoCD Health Check"
    
    if ! command_exists kubectl; then
        print_error "kubectl is not available"
        return 1
    fi
    
    # Check if ArgoCD namespace exists
    if kubectl get namespace argocd >/dev/null 2>&1; then
        print_status "✅ ArgoCD namespace exists"
        
        # Check ArgoCD server
        if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
            print_status "✅ ArgoCD server deployment exists"
            
            # Check ArgoCD server status
            local argocd_ready=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            if [ "$argocd_ready" != "0" ]; then
                print_status "✅ ArgoCD server is ready"
            else
                print_error "❌ ArgoCD server is not ready"
            fi
        else
            print_error "❌ ArgoCD server deployment not found"
        fi
        
        # Check NativeSeries application
        if kubectl get application nativeseries -n argocd >/dev/null 2>&1; then
            print_status "✅ NativeSeries ArgoCD application exists"
            
            # Check application health
            local app_health=$(kubectl get application nativeseries -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            local app_sync=$(kubectl get application nativeseries -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            
            if [ "$app_health" = "Healthy" ]; then
                print_status "✅ Application health: $app_health"
            else
                print_warning "⚠️ Application health: $app_health"
            fi
            
            if [ "$app_sync" = "Synced" ]; then
                print_status "✅ Application sync: $app_sync"
            else
                print_warning "⚠️ Application sync: $app_sync"
            fi
        else
            print_error "❌ NativeSeries ArgoCD application not found"
        fi
        
    else
        print_error "❌ ArgoCD namespace not found"
        return 1
    fi
    
    return 0
}

# Function to check network connectivity
check_network() {
    print_section "🌐 Network Connectivity Check"
    
    local external_hosts=("google.com" "github.com" "docker.io")
    local local_ports=("8011" "30012" "30080" "80" "3000" "9090" "8080")
    
    print_status "Checking external connectivity..."
    local external_healthy=0
    
    for host in "${external_hosts[@]}"; do
        if ping -c 1 "$host" >/dev/null 2>&1; then
            print_status "✅ $host is reachable"
            ((external_healthy++))
        else
            print_error "❌ $host is not reachable"
        fi
    done
    
    print_metric "External Connectivity: $external_healthy/${#external_hosts[@]} hosts reachable"
    
    print_status "Checking local port accessibility..."
    local local_healthy=0
    
    for port in "${local_ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            print_status "✅ Port $port is listening"
            ((local_healthy++))
        else
            print_warning "⚠️ Port $port is not listening"
        fi
    done
    
    print_metric "Local Ports: $local_healthy/${#local_ports[@]} ports listening"
    
    return $((external_healthy == ${#external_hosts[@]} && local_healthy >= 3 ? 0 : 1))
}

# Function to check application endpoints
check_endpoints() {
    print_section "🎯 Application Endpoints Check"
    
    local endpoints=(
        "http://localhost:8011/health|Docker Compose Health"
        "http://localhost:8011/docs|Docker Compose API Docs"
        "http://localhost:8011/metrics|Docker Compose Metrics"
        "http://localhost:30012/health|Kubernetes Health"
        "http://localhost:30012/docs|Kubernetes API Docs"
        "http://localhost:30012/metrics|Kubernetes Metrics"
        "http://localhost:80|Nginx Proxy"
        "http://localhost:3000|Grafana"
        "http://localhost:9090|Prometheus"
        "http://localhost:8080|Adminer"
    )
    
    local healthy_endpoints=0
    
    for endpoint in "${endpoints[@]}"; do
        IFS='|' read -r url name <<< "$endpoint"
        if check_service "$url" "$name" 5; then
            ((healthy_endpoints++))
        fi
    done
    
    print_metric "Application Endpoints: $healthy_endpoints/${#endpoints[@]} endpoints healthy"
    
    return $((healthy_endpoints >= 5 ? 0 : 1))
}

# Function to check database connectivity
check_database() {
    print_section "🗄️ Database Connectivity Check"
    
    # Check PostgreSQL
    if docker exec $(docker ps -q -f name=postgres) pg_isready -U student_user >/dev/null 2>&1; then
        print_status "✅ PostgreSQL is ready"
        
        # Check if we can connect and query
        if docker exec $(docker ps -q -f name=postgres) psql -U student_user -d student_db -c "SELECT 1;" >/dev/null 2>&1; then
            print_status "✅ PostgreSQL connection successful"
        else
            print_error "❌ PostgreSQL connection failed"
        fi
    else
        print_error "❌ PostgreSQL is not ready"
    fi
    
    # Check Redis
    if docker exec $(docker ps -q -f name=redis) redis-cli ping >/dev/null 2>&1; then
        print_status "✅ Redis is responding"
    else
        print_error "❌ Redis is not responding"
    fi
}

# Function to check resource usage
check_resources() {
    print_section "📊 Resource Usage Check"
    
    # Check disk usage
    print_status "Disk usage:"
    df -h | grep -E "(Filesystem|/dev/)"
    
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
    
    # Check memory usage
    print_status "Memory usage:"
    free -h
    
    # Check CPU usage
    print_status "CPU usage:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | awk '{print "CPU Usage: " $1 "%"}'
    
    # Check Docker resource usage
    if command_exists docker; then
        print_status "Docker resource usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
        # Check Docker disk usage
        print_status "Docker disk usage:"
        docker system df
    fi
    
    # Check Kubernetes resource usage
    if command_exists kubectl; then
        print_status "Kubernetes resource usage:"
        kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
        kubectl top pods 2>/dev/null || print_warning "Pod metrics not available"
    fi
}

# Function to check system services
check_system_services() {
    print_section "🔧 System Services Check"
    
    local services=("docker" "kubelet" "containerd")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_status "✅ $service is running"
        else
            print_warning "⚠️ $service is not running"
        fi
    done
}

# Function to generate health report
generate_health_report() {
    print_section "📋 Health Report Summary"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    local uptime=$(uptime -p)
    
    echo ""
    echo "🏥 NATIVESERIES HEALTH REPORT"
    echo "================================"
    echo "📅 Generated: $timestamp"
    echo "🖥️ Hostname: $hostname"
    echo "⏱️ Uptime: $uptime"
    echo ""
    
    # Summary of all checks
    echo "📊 HEALTH SUMMARY:"
    echo "=================="
    
    # Docker Compose status
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        echo "✅ Docker Compose: Running"
    else
        echo "❌ Docker Compose: Not running"
    fi
    
    # Kubernetes status
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Kubernetes: Accessible"
    else
        echo "❌ Kubernetes: Not accessible"
    fi
    
    # ArgoCD status
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo "✅ ArgoCD: Installed"
    else
        echo "❌ ArgoCD: Not installed"
    fi
    
    # Application endpoints
    local healthy_endpoints=0
    local total_endpoints=0
    
    for endpoint in "http://localhost:8011/health" "http://localhost:30012/health" "http://localhost:80"; do
        ((total_endpoints++))
        if curl -s --max-time 5 "$endpoint" >/dev/null 2>&1; then
            ((healthy_endpoints++))
        fi
    done
    
    echo "✅ Application Endpoints: $healthy_endpoints/$total_endpoints healthy"
    
    echo ""
    echo "🔗 ACCESS URLs:"
    echo "==============="
    echo "🐳 Docker Compose: http://18.206.89.183:8011"
    echo "☸️ Kubernetes: http://18.206.89.183:30012"
    echo "🔄 ArgoCD: http://18.206.89.183:30080"
    echo "📖 API Docs: http://18.206.89.183:8011/docs"
    echo "🩺 Health Check: http://18.206.89.183:8011/health"
    echo ""
}

# Function to run all health checks
run_health_checks() {
    print_step "Starting comprehensive health check..."
    
    local overall_health=0
    
    # Run all health checks
    check_docker && ((overall_health++))
    check_kubernetes && ((overall_health++))
    check_argocd && ((overall_health++))
    check_network && ((overall_health++))
    check_endpoints && ((overall_health++))
    check_database && ((overall_health++))
    check_resources
    check_system_services
    
    # Generate final report
    generate_health_report
    
    # Overall health assessment
    local total_checks=6
    local health_percentage=$((overall_health * 100 / total_checks))
    
    echo "🎯 OVERALL HEALTH ASSESSMENT:"
    echo "============================="
    echo "📊 Health Score: $overall_health/$total_checks ($health_percentage%)"
    
    if [ $health_percentage -ge 80 ]; then
        print_status "🎉 System is healthy!"
        echo "✅ All critical services are operational"
    elif [ $health_percentage -ge 60 ]; then
        print_warning "⚠️ System has minor issues"
        echo "⚠️ Some services may need attention"
    else
        print_error "❌ System has critical issues"
        echo "❌ Immediate attention required"
    fi
    
    echo ""
    echo "🔧 TROUBLESHOOTING COMMANDS:"
    echo "============================"
    echo "docker compose ps                    # Check Docker Compose status"
    echo "docker compose logs -f               # View Docker Compose logs"
    echo "kubectl get pods                     # Check Kubernetes pods"
    echo "kubectl logs -f deployment/nativeseries  # View Kubernetes logs"
    echo "kubectl get application nativeseries -n argocd  # Check ArgoCD app"
    echo "curl http://localhost:8011/health    # Test Docker Compose health"
    echo "curl http://localhost:30012/health   # Test Kubernetes health"
    echo ""
    
    return $((overall_health >= 4 ? 0 : 1))
}

# Main execution
main() {
    echo "🏥 NativeSeries Comprehensive Health Check"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_warning "This script may need sudo privileges for some checks"
    fi
    
    # Run health checks
    if run_health_checks; then
        print_status "Health check completed successfully"
        exit 0
    else
        print_error "Health check found issues"
        exit 1
    fi
}

# Run main function
main "$@"