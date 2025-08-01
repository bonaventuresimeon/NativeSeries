#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

TARGET_IP="18.208.149.195"
TARGET_PORT="8011"
ARGOCD_PORT="30080"

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                Deployment Status Check                      ║"
echo "║              Target Server: ${TARGET_IP}:${TARGET_PORT}                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if a service is accessible
check_service() {
    local service_name=$1
    local url=$2
    local description=$3
    
    echo -e "${BLUE}🔍 Checking ${service_name}...${NC}"
    if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ${service_name} is accessible${NC}"
        echo -e "   📍 URL: $url"
        echo -e "   📝 $description"
    else
        echo -e "${RED}❌ ${service_name} is not accessible${NC}"
        echo -e "   📍 URL: $url"
    fi
    echo ""
}

# Function to check Docker Compose services
check_docker_compose() {
    echo -e "${PURPLE}🐳 Docker Compose Services Status:${NC}"
    if command -v docker-compose >/dev/null 2>&1; then
        if [ -f "docker-compose.yml" ]; then
            docker-compose ps
        else
            echo -e "${YELLOW}⚠️  docker-compose.yml not found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Docker Compose not installed${NC}"
    fi
    echo ""
}

# Function to check Kubernetes/ArgoCD services
check_kubernetes() {
    echo -e "${PURPLE}☸️  Kubernetes/ArgoCD Services Status:${NC}"
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl cluster-info >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
            echo -e "${BLUE}📊 Pods in app-prod namespace:${NC}"
            kubectl get pods -n app-prod 2>/dev/null || echo -e "${YELLOW}⚠️  app-prod namespace not found${NC}"
            echo ""
            echo -e "${BLUE}📊 ArgoCD applications:${NC}"
            kubectl get applications -n argocd 2>/dev/null || echo -e "${YELLOW}⚠️  ArgoCD namespace not found${NC}"
        else
            echo -e "${RED}❌ Kubernetes cluster is not accessible${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  kubectl not installed${NC}"
    fi
    echo ""
}

# Function to check system resources
check_system_resources() {
    echo -e "${PURPLE}💻 System Resources:${NC}"
    
    # CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${BLUE}🖥️  CPU Usage: ${cpu_usage}%${NC}"
    
    # Memory usage
    memory_info=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    echo -e "${BLUE}🧠 Memory Usage: ${memory_info}${NC}"
    
    # Disk usage
    disk_usage=$(df -h / | awk 'NR==2{print $5}')
    echo -e "${BLUE}💾 Disk Usage: ${disk_usage}${NC}"
    
    # Docker status
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker is running${NC}"
        else
            echo -e "${RED}❌ Docker is not running${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Docker not installed${NC}"
    fi
    echo ""
}

# Function to check network connectivity
check_network() {
    echo -e "${PURPLE}🌐 Network Connectivity:${NC}"
    
    # Check if target IP is reachable
    if ping -c 1 $TARGET_IP >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Target server ${TARGET_IP} is reachable${NC}"
    else
        echo -e "${RED}❌ Target server ${TARGET_IP} is not reachable${NC}"
    fi
    
    # Check port accessibility
    if nc -z $TARGET_IP $TARGET_PORT 2>/dev/null; then
        echo -e "${GREEN}✅ Port ${TARGET_PORT} is open${NC}"
    else
        echo -e "${RED}❌ Port ${TARGET_PORT} is closed${NC}"
    fi
    
    if nc -z $TARGET_IP $ARGOCD_PORT 2>/dev/null; then
        echo -e "${GREEN}✅ ArgoCD port ${ARGOCD_PORT} is open${NC}"
    else
        echo -e "${RED}❌ ArgoCD port ${ARGOCD_PORT} is closed${NC}"
    fi
    echo ""
}

# Main execution
echo -e "${BLUE}🚀 Starting deployment status check...${NC}"
echo ""

# Check system resources
check_system_resources

# Check network connectivity
check_network

# Check Docker Compose services
check_docker_compose

# Check Kubernetes/ArgoCD services
check_kubernetes

# Check application services
echo -e "${PURPLE}🌐 Application Services Status:${NC}"

# Main application
check_service "Student Tracker Application" "http://${TARGET_IP}:${TARGET_PORT}" "Main FastAPI application"

# Health check
check_service "Health Check" "http://${TARGET_IP}:${TARGET_PORT}/health" "Application health endpoint"

# API documentation
check_service "API Documentation" "http://${TARGET_IP}:${TARGET_PORT}/docs" "Interactive API documentation"

# Metrics
check_service "Metrics Endpoint" "http://${TARGET_IP}:${TARGET_PORT}/metrics" "Application metrics"

# ArgoCD
check_service "ArgoCD UI" "http://${TARGET_IP}:${ARGOCD_PORT}" "GitOps management interface"

# Grafana
check_service "Grafana" "http://${TARGET_IP}:3000" "Monitoring dashboards"

# Prometheus
check_service "Prometheus" "http://${TARGET_IP}:9090" "Metrics collection"

# Adminer
check_service "Adminer" "http://${TARGET_IP}:8080" "Database management interface"

echo -e "${PURPLE}📋 Summary:${NC}"
echo -e "${BLUE}🎯 Target Server: ${TARGET_IP}:${TARGET_PORT}${NC}"
echo -e "${BLUE}🔄 ArgoCD: ${TARGET_IP}:${ARGOCD_PORT}${NC}"
echo -e "${BLUE}📊 Monitoring: ${TARGET_IP}:3000 (Grafana), ${TARGET_IP}:9090 (Prometheus)${NC}"
echo -e "${BLUE}🗄️  Database: ${TARGET_IP}:8080 (Adminer)${NC}"
echo ""
echo -e "${GREEN}✅ Status check completed!${NC}"