#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"
EC2_USER="ec2-user"

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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_status "🚀 Starting EC2 deployment for ec2-user"
print_status "Production URL: ${PRODUCTION_URL}"

# Check if running as ec2-user
if [ "$(whoami)" != "ec2-user" ]; then
    print_warning "⚠️  This script is designed to run as ec2-user"
    print_info "Current user: $(whoami)"
    print_info "You may need to run: sudo su - ec2-user"
fi

# Update system packages
print_status "📦 Updating system packages..."
sudo yum update -y

# Install required packages
print_status "📦 Installing required packages..."
sudo yum install -y \
    docker \
    git \
    curl \
    wget \
    unzip \
    python3 \
    python3-pip

# Start and enable Docker
print_status "🐳 Setting up Docker..."
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
print_status "📦 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Verify Docker installation
print_status "🔍 Verifying Docker installation..."
if ! sudo docker info &> /dev/null; then
    print_error "❌ Docker is not running. Please start Docker manually."
    print_info "Run: sudo systemctl start docker"
    exit 1
fi

print_status "✅ Docker is running"

# Stop and remove existing container
print_status "🔄 Stopping existing container..."
sudo docker stop ${APP_NAME} || true
sudo docker rm ${APP_NAME} || true

# Build Docker image
print_status "🔨 Building Docker image..."
sudo docker build -t ${APP_NAME}:latest .

# Check if the image was built successfully
if [ $? -eq 0 ]; then
    print_status "✅ Docker image built successfully"
else
    print_error "❌ Failed to build Docker image"
    exit 1
fi

# Run the application container
print_status "🚀 Starting application container..."
sudo docker run -d \
    --name ${APP_NAME} \
    --restart unless-stopped \
    -p ${PRODUCTION_PORT}:8000 \
    -e HOST=0.0.0.0 \
    -e PORT=8000 \
    -e ENVIRONMENT=production \
    -e MONGO_URI=mongodb://localhost:27017 \
    -e DATABASE_NAME=student_project_tracker \
    -e COLLECTION_NAME=students \
    ${APP_NAME}:latest

# Check if container started successfully
if [ $? -eq 0 ]; then
    print_status "✅ Application container started successfully"
else
    print_error "❌ Failed to start application container"
    exit 1
fi

# Wait for application to start
print_status "⏳ Waiting for application to start..."
sleep 30

# Health check
print_status "🔍 Performing health check..."
retry_count=0
max_retries=10

while [ $retry_count -lt $max_retries ]; do
    if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
        print_status "✅ Application is healthy and responding"
        break
    else
        retry_count=$((retry_count + 1))
        print_warning "⚠️  Health check attempt $retry_count/$max_retries failed"
        if [ $retry_count -lt $max_retries ]; then
            sleep 10
        else
            print_error "❌ Health check failed after $max_retries attempts"
            print_info "Container logs:"
            sudo docker logs ${APP_NAME} --tail 20
            exit 1
        fi
    fi
done

# Test all endpoints
print_status "🧪 Testing all endpoints..."

# Test health endpoint
if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
    print_status "✅ Health endpoint working"
else
    print_error "❌ Health endpoint failed"
fi

# Test API documentation
if curl -f "${PRODUCTION_URL}/docs" > /dev/null 2>&1; then
    print_status "✅ API documentation accessible"
else
    print_error "❌ API documentation failed"
fi

# Test students interface
if curl -f "${PRODUCTION_URL}/students/" > /dev/null 2>&1; then
    print_status "✅ Students interface working"
else
    print_error "❌ Students interface failed"
fi

# Test metrics endpoint
if curl -f "${PRODUCTION_URL}/metrics" > /dev/null 2>&1; then
    print_status "✅ Metrics endpoint working"
else
    print_error "❌ Metrics endpoint failed"
fi

# Show deployment information
echo ""
print_status "🎉 Deployment Complete!"
echo ""
echo "📋 Deployment Information:"
echo "   Application: ${APP_NAME}"
echo "   Production URL: ${PRODUCTION_URL}"
echo "   API Documentation: ${PRODUCTION_URL}/docs"
echo "   Health Check: ${PRODUCTION_URL}/health"
echo "   Metrics: ${PRODUCTION_URL}/metrics"
echo "   Students Interface: ${PRODUCTION_URL}/students/"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: sudo docker logs -f ${APP_NAME}"
echo "   Stop app: sudo docker stop ${APP_NAME}"
echo "   Restart app: sudo docker restart ${APP_NAME}"
echo "   Remove app: sudo docker rm -f ${APP_NAME}"
echo "   View container: sudo docker ps"
echo "   View images: sudo docker images"
echo ""
print_status "🌐 Your Student Tracker application is now live at: ${PRODUCTION_URL}"

# Show container status
echo ""
print_status "📊 Container Status:"
sudo docker ps --filter "name=${APP_NAME}"

# Show recent logs
echo ""
print_status "📋 Recent Logs:"
sudo docker logs ${APP_NAME} --tail 10

echo ""
print_status "✅ EC2 deployment completed successfully!"