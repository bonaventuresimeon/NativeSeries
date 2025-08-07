#!/bin/bash

# NativeSeries - Simple Build Script for Netlify
# This script ensures the application builds correctly

set -e

echo "🚀 Starting NativeSeries build..."

# Check if we're in the right directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found"
    exit 1
fi

# Create public directory if it doesn't exist
mkdir -p public

# Copy static files if they don't exist
if [ ! -f "public/index.html" ]; then
    echo "📄 Creating index.html..."
    cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Student Tracker</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .status { padding: 20px; background: #f0f0f0; border-radius: 5px; }
        .success { background: #d4edda; color: #155724; }
        .error { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎓 NativeSeries</h1>
            <p>Student Tracking Application</p>
        </div>
        
        <div class="status success">
            <h2>✅ Application Status</h2>
            <p><strong>Status:</strong> Running</p>
            <p><strong>Environment:</strong> Netlify</p>
            <p><strong>API:</strong> <a href="/api/students">/api/students</a></p>
            <p><strong>Health:</strong> <a href="/health">/health</a></p>
            <p><strong>Docs:</strong> <a href="/docs">/docs</a></p>
        </div>
        
        <div style="margin-top: 30px;">
            <h3>Quick Links:</h3>
            <ul>
                <li><a href="/register.html">Register Student</a></li>
                <li><a href="/students.html">View Students</a></li>
                <li><a href="/progress.html">Update Progress</a></li>
                <li><a href="/admin.html">Admin Panel</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
fi

# Check if netlify functions directory exists
if [ ! -d "netlify/functions" ]; then
    echo "📁 Creating netlify/functions directory..."
    mkdir -p netlify/functions
fi

# Create a simple health check function if it doesn't exist
if [ ! -f "netlify/functions/health.py" ]; then
    echo "🏥 Creating health check function..."
    cat > netlify/functions/health.py << 'EOF'
import json
from datetime import datetime, timezone

def handler(event, context):
    """Simple health check function"""
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps({
            'status': 'healthy',
            'message': 'NativeSeries is running on Netlify',
            'environment': 'netlify',
            'timestamp': str(datetime.now(timezone.utc)),
            'version': '1.0.0'
        })
    }
EOF
fi

echo "✅ Build completed successfully!"
echo "📦 Static files are ready in public/"
echo "🔧 Functions are ready in netlify/functions/"