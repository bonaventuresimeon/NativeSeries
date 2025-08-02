#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="student-tracker"
PRODUCTION_HOST="18.206.89.183"
PRODUCTION_PORT="30011"
PRODUCTION_URL="http://${PRODUCTION_HOST}:${PRODUCTION_PORT}"

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

print_status "🚀 Deploying Student Tracker to Production"
print_status "Production URL: ${PRODUCTION_URL}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker daemon is running
if ! sudo docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Build the Docker image
print_status "Building Docker image..."
sudo docker build -t ${APP_NAME}:latest .

# Check if the image was built successfully
if [ $? -eq 0 ]; then
    print_status "✅ Docker image built successfully"
else
    print_error "❌ Failed to build Docker image"
    exit 1
fi

# Run the application container
print_status "Starting application container..."
sudo docker run -d \
    --name ${APP_NAME} \
    --restart unless-stopped \
    -p ${PRODUCTION_PORT}:8000 \
    -e HOST=0.0.0.0 \
    -e PORT=8000 \
    ${APP_NAME}:latest

# Check if container started successfully
if [ $? -eq 0 ]; then
    print_status "✅ Application container started successfully"
else
    print_error "❌ Failed to start application container"
    exit 1
fi

# Wait a moment for the application to start
print_status "Waiting for application to start..."
sleep 10

# Test the application
print_status "Testing application health..."
if curl -f "${PRODUCTION_URL}/health" > /dev/null 2>&1; then
    print_status "✅ Application is healthy and responding"
else
    print_warning "⚠️  Health check failed, but container is running"
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
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: docker logs -f ${APP_NAME}"
echo "   Stop app: docker stop ${APP_NAME}"
echo "   Restart app: docker restart ${APP_NAME}"
echo "   Remove app: docker rm -f ${APP_NAME}"
echo ""
print_status "🌐 Your Student Tracker application is now live at: ${PRODUCTION_URL}"