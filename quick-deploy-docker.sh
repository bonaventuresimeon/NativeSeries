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
PRODUCTION_PORT="30011"

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

print_status "🚀 Quick Docker Deployment"
print_status "This will deploy the application using Docker (no Kubernetes required)"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "❌ Docker is not installed"
    print_info "Installing Docker..."
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
    print_status "✅ Docker installed. Please logout and login again, then run this script."
    exit 1
fi

# Check if Docker is running
if ! sudo docker info &> /dev/null; then
    print_error "❌ Docker is not running"
    print_info "Starting Docker..."
    sudo systemctl start docker
    sleep 5
fi

print_status "✅ Docker is available and running"

# Stop and remove existing container
print_status "🔄 Stopping existing container..."
sudo docker stop ${APP_NAME} || true
sudo docker rm ${APP_NAME} || true

# Check if we have a local image
if ! sudo docker images | grep -q "${APP_NAME}"; then
    print_status "📦 Building Docker image..."
    sudo docker build -t ${APP_NAME}:latest .
    
    if [ $? -eq 0 ]; then
        print_status "✅ Docker image built successfully"
    else
        print_error "❌ Failed to build Docker image"
        exit 1
    fi
else
    print_status "✅ Docker image already exists"
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

# Health check with retry
print_status "🔍 Performing health check..."
retry_count=0
max_retries=10

while [ $retry_count -lt $max_retries ]; do
    if curl -f "http://localhost:${PRODUCTION_PORT}/health" > /dev/null 2>&1; then
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
if curl -f "http://localhost:${PRODUCTION_PORT}/health" > /dev/null 2>&1; then
    print_status "✅ Health endpoint working"
else
    print_error "❌ Health endpoint failed"
fi

# Test API documentation
if curl -f "http://localhost:${PRODUCTION_PORT}/docs" > /dev/null 2>&1; then
    print_status "✅ API documentation accessible"
else
    print_error "❌ API documentation failed"
fi

# Test students interface
if curl -f "http://localhost:${PRODUCTION_PORT}/students/" > /dev/null 2>&1; then
    print_status "✅ Students interface working"
else
    print_error "❌ Students interface failed"
fi

# Test metrics endpoint
if curl -f "http://localhost:${PRODUCTION_PORT}/metrics" > /dev/null 2>&1; then
    print_status "✅ Metrics endpoint working"
else
    print_error "❌ Metrics endpoint failed"
fi

# Get EC2 public IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

# Show deployment information
echo ""
print_status "🎉 Deployment Complete!"
echo ""
echo "📋 Deployment Information:"
echo "   Application: ${APP_NAME}"
echo "   Local URL: http://localhost:${PRODUCTION_PORT}"
echo "   Public URL: http://${EC2_IP}:${PRODUCTION_PORT}"
echo "   API Documentation: http://localhost:${PRODUCTION_PORT}/docs"
echo "   Health Check: http://localhost:${PRODUCTION_PORT}/health"
echo "   Metrics: http://localhost:${PRODUCTION_PORT}/metrics"
echo "   Students Interface: http://localhost:${PRODUCTION_PORT}/students/"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: sudo docker logs -f ${APP_NAME}"
echo "   Stop app: sudo docker stop ${APP_NAME}"
echo "   Restart app: sudo docker restart ${APP_NAME}"
echo "   Remove app: sudo docker rm -f ${APP_NAME}"
echo "   View container: sudo docker ps"
echo "   View images: sudo docker images"
echo ""
print_status "🌐 Your Student Tracker application is now live!"

# Show container status
echo ""
print_status "📊 Container Status:"
sudo docker ps --filter "name=${APP_NAME}"

# Show recent logs
echo ""
print_status "📋 Recent Logs:"
sudo docker logs ${APP_NAME} --tail 10

echo ""
print_status "✅ Quick Docker deployment completed successfully!"
print_info "The application is now running and accessible!"