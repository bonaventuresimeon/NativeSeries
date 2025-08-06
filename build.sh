#!/bin/bash

# Netlify build script for NativeSeries

echo "🚀 Building NativeSeries for Netlify..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
python -m pytest app/ -v

# Create public directory if it doesn't exist
mkdir -p public

# Copy static files
echo "📁 Setting up static files..."
cp -r templates/* public/ 2>/dev/null || echo "No templates to copy"

# Create a simple health check file
echo "🏥 Creating health check..."
cat > public/health.json << EOF
{
  "status": "healthy",
  "message": "NativeSeries API is running on Netlify",
  "environment": "netlify",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✅ Build completed successfully!"
echo "📁 Public directory contents:"
ls -la public/