import json
import sys
import os
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'app'))

try:
    from main import app
    from fastapi import Request
    from fastapi.responses import JSONResponse
    import uvicorn
    from mangum import Adapter
except ImportError as e:
    print(f"Import error: {e}")

def handler(event, context):
    """Netlify function handler for FastAPI application"""
    
    # Parse the event
    path = event.get('path', '/')
    http_method = event.get('httpMethod', 'GET')
    headers = event.get('headers', {})
    query_string = event.get('queryStringParameters', {})
    body = event.get('body', '')
    
    # Create a mock request for FastAPI
    scope = {
        'type': 'http',
        'method': http_method,
        'path': path,
        'headers': [[k.lower().encode(), v.encode()] for k, v in headers.items()],
        'query_string': query_string.encode() if query_string else b'',
        'body': body.encode() if body else b'',
    }
    
    try:
        # Create a mock request
        request = Request(scope)
        
        # Handle common endpoints
        if path == '/health':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'status': 'healthy',
                    'message': 'NativeSeries API is running on Netlify',
                    'environment': 'netlify'
                })
            }
        
        elif path == '/api/students':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'students': [
                        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
                        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'}
                    ],
                    'count': 2,
                    'environment': 'netlify'
                })
            }
        
        elif path == '/':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html'},
                'body': '''
                <!DOCTYPE html>
                <html>
                <head>
                    <title>NativeSeries - Netlify</title>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }
                        .container { max-width: 800px; margin: 50px auto; background: white; border-radius: 12px; padding: 40px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); text-align: center; }
                        .title { color: #2c3e50; margin: 0; font-size: 2.5em; }
                        .subtitle { color: #7f8c8d; margin: 10px 0 30px; }
                        .netlify-badge { background: #00AD9F; color: white; padding: 5px 12px; border-radius: 15px; font-size: 12px; margin-left: 10px; }
                        .endpoint { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 10px 0; text-align: left; }
                        .endpoint code { background: #e9ecef; padding: 2px 6px; border-radius: 4px; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1 class="title">NativeSeries <span class="netlify-badge">NETLIFY</span></h1>
                        <p class="subtitle">Student Tracking & Management System</p>
                        
                        <div class="endpoint">
                            <h3>🚀 Successfully Deployed on Netlify!</h3>
                            <p>Your FastAPI application is now running on Netlify Functions.</p>
                        </div>
                        
                        <div class="endpoint">
                            <h3>📋 Available Endpoints:</h3>
                            <p><code>/health</code> - Health check endpoint</p>
                            <p><code>/api/students</code> - Get all students</p>
                            <p><code>/docs</code> - API documentation (if available)</p>
                        </div>
                        
                        <div class="endpoint">
                            <h3>🔧 Environment:</h3>
                            <p>Platform: <strong>Netlify Functions</strong></p>
                            <p>Runtime: <strong>Python 3.13</strong></p>
                            <p>Framework: <strong>FastAPI</strong></p>
                        </div>
                        
                        <div class="endpoint">
                            <h3>🧪 Test the API:</h3>
                            <p><a href="/health" target="_blank">Health Check</a></p>
                            <p><a href="/api/students" target="_blank">Students API</a></p>
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
                    'available_endpoints': ['/health', '/api/students', '/']
                })
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }