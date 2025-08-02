#!/bin/bash

# =============================================================================
# 🚀 QUICK FIX SCRIPT FOR EC2 DEPLOYMENT
# =============================================================================
# This script fixes the Docker Compose issue and deploys the application.
#
# Usage: sudo ./quick-fix.sh
# =============================================================================

set -e

echo "🚀 Quick Fix for EC2 Deployment"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_status "Step 1: Installing Docker Compose..."

# Install Docker Compose
if ! command_exists docker-compose; then
    print_status "Downloading Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed successfully!"
else
    print_status "Docker Compose is already installed"
fi

# Verify Docker Compose
docker-compose --version

print_status "Step 2: Deploying application with Docker Compose..."

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose down -v 2>/dev/null || true

# Remove old images
print_status "Removing old images..."
docker rmi simple-app:latest 2>/dev/null || true
docker rmi student-tracker:latest 2>/dev/null || true

# Clean up Docker system
print_status "Cleaning up Docker system..."
docker system prune -f 2>/dev/null || true

# Build and start services
print_status "Building and starting services..."
docker-compose up -d --build

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Check service status
print_status "Checking service status..."
docker-compose ps

# Test application
print_status "Testing application..."
sleep 10

if curl -s http://localhost:8011/health >/dev/null; then
    print_status "✅ Application is healthy!"
    curl -s http://localhost:8011/health | jq . 2>/dev/null || curl -s http://localhost:8011/health
else
    print_warning "Application not yet ready, checking logs..."
    docker-compose logs student-tracker --tail=10
fi

print_status "Step 3: Deployment Summary"

echo ""
print_status "🎉 Deployment completed!"
echo ""
echo "📋 Access Information:"
echo "   Application URL: http://18.206.89.183:8011"
echo "   API Documentation: http://18.206.89.183:8011/docs"
echo "   Health Check: http://18.206.89.183:8011/health"
echo "   Grafana: http://18.206.89.183:3000 (admin/admin123)"
echo "   Prometheus: http://18.206.89.183:9090"
echo "   Adminer: http://18.206.89.183:8080"
echo ""
echo "🔧 Useful Commands:"
echo "   docker-compose ps          # View service status"
echo "   docker-compose logs -f     # View logs"
echo "   docker-compose restart     # Restart services"
echo "   docker-compose down        # Stop services"
echo ""