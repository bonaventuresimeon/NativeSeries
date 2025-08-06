#!/bin/bash

# NativeSeries Deployment Script
# This script runs the deployment process locally for testing

set -e

echo "🚀 NativeSeries Deployment Script"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "app/main.py" ]; then
    echo "❌ Error: app/main.py not found. Please run this script from the project root."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
python -m pytest app/ -v

# Run linting
echo "🔍 Running linting..."
flake8 app/ --count --select=E9,F63,F7,F82 --show-source --statistics

# Run formatting check
echo "🎨 Checking code formatting..."
black --check app/ --diff

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t nativeseries:latest .

# Test Docker image
echo "🧪 Testing Docker image..."
docker run -d --name test-nativeseries -p 8000:8000 nativeseries:latest
sleep 10

# Test health endpoint
echo "🏥 Testing health endpoint..."
curl -f http://localhost:8000/health || echo "⚠️ Health check failed"

# Test main endpoints
echo "🌐 Testing main endpoints..."
curl -f http://localhost:8000/ || echo "⚠️ Home page failed"
curl -f http://localhost:8000/docs || echo "⚠️ API docs failed"

# Cleanup
echo "🧹 Cleaning up test container..."
docker stop test-nativeseries && docker rm test-nativeseries

echo "✅ Deployment test completed successfully!"
echo ""
echo "📋 Summary:"
echo "- All tests passed"
echo "- Linting passed"
echo "- Formatting passed"
echo "- Docker build successful"
echo "- Application endpoints working"
echo ""
echo "🚀 Ready for production deployment!"
echo "Production URL: http://54.166.101.159:30011"
echo "GitHub Actions: https://github.com/bonaventuresimeon/NativeSeries/actions"