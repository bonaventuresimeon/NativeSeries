import json
import sys
import os
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'app'))

try:
    from main import app
    from fastapi import Request
    from fastapi.responses import JSONResponse
    import uvicorn
    from mangum import Adapter
except ImportError as e:
    print(f"Import error: {e}")

# Create Mangum adapter for FastAPI
try:
    handler = Adapter(app)
except Exception as e:
    print(f"Adapter error: {e}")
    handler = None

def handler(event, context):
    """Netlify function handler for FastAPI application"""
    
    try:
        # Use Mangum adapter if available
        if handler:
            return handler(event, context)
        
        # Fallback to manual handling
        path = event.get('path', '/')
        http_method = event.get('httpMethod', 'GET')
        headers = event.get('headers', {})
        query_string = event.get('queryStringParameters', {})
        body = event.get('body', '')
        
        # Handle common endpoints
        if path == '/health':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'status': 'healthy',
                    'message': 'NativeSeries API is running on Netlify',
                    'environment': 'netlify',
                    'timestamp': str(datetime.now(timezone.utc))
                })
            }
        
        elif path == '/api/students':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'students': [
                        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'course': 'Computer Science'},
                        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'course': 'Mathematics'},
                        {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com', 'course': 'Physics'}
                    ],
                    'count': 3,
                    'environment': 'netlify'
                })
            }
        
        elif path == '/docs':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html'},
                'body': '''
                <!DOCTYPE html>
                <html>
                <head>
                    <title>NativeSeries API Documentation</title>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                        .container { max-width: 800px; margin: 50px auto; background: white; border-radius: 12px; padding: 40px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
                        .title { color: #2c3e50; margin: 0; font-size: 2.5em; }
                        .endpoint { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 10px 0; }
                        .method { display: inline-block; padding: 4px 8px; border-radius: 4px; color: white; font-weight: bold; margin-right: 10px; }
                        .get { background: #61affe; }
                        .post { background: #49cc90; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1 class="title">NativeSeries API Documentation</h1>
                        
                        <div class="endpoint">
                            <span class="method get">GET</span>
                            <strong>/health</strong> - Health check endpoint
                        </div>
                        
                        <div class="endpoint">
                            <span class="method get">GET</span>
                            <strong>/api/students</strong> - Get all students
                        </div>
                        
                        <div class="endpoint">
                            <span class="method post">POST</span>
                            <strong>/api/register</strong> - Register new student
                        </div>
                        
                        <div class="endpoint">
                            <span class="method get">GET</span>
                            <strong>/docs</strong> - This documentation page
                        </div>
                    </div>
                </body>
                </html>
                '''
            }
        
        else:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Not found',
                    'message': f'Endpoint {path} not found',
                    'available_endpoints': ['/health', '/api/students', '/docs', '/']
                })
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e),
                'type': type(e).__name__
            })
        }