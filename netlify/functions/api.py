import json
import sys
import os
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timezone

# Add the app directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'app'))

try:
    # Import Netlify-specific database
    from database_netlify import get_student_collection, get_database_stats, init_database
    from main import app
    from fastapi import Request
    from fastapi.responses import JSONResponse
    import uvicorn
    from mangum import Adapter
    
    # Initialize database for Netlify
    init_database()
    
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
            try:
                # Use the Netlify database
                collection = get_student_collection()
                students = await collection.find()
                stats = get_database_stats()
                
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'students': students,
                        'count': len(students),
                        'environment': 'netlify',
                        'database_stats': stats
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Database error',
                        'message': str(e),
                        'environment': 'netlify'
                    })
                }
        
        elif path == '/api/stats':
            try:
                stats = get_database_stats()
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'database_stats': stats,
                        'environment': 'netlify',
                        'timestamp': str(datetime.now(timezone.utc))
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Stats error',
                        'message': str(e),
                        'environment': 'netlify'
                    })
                }
        
        elif path == '/api/database':
            try:
                from database_netlify import get_database_stats, get_vault_status
                stats = get_database_stats()
                vault_status = get_vault_status()
                
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'database_info': stats,
                        'vault_status': vault_status,
                        'environment': 'netlify',
                        'timestamp': str(datetime.now(timezone.utc))
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Database info error',
                        'message': str(e),
                        'environment': 'netlify'
                    })
                }
        
        elif path == '/api/vault':
            try:
                from database_netlify import get_vault_status, db_config
                
                vault_status = get_vault_status()
                
                # Try to get secrets from vault if configured
                vault_secrets = None
                if db_config.is_vault_configured():
                    try:
                        vault_secrets = await db_config.get_vault_secrets()
                    except Exception as e:
                        vault_secrets = {"error": str(e)}
                
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'vault_status': vault_status,
                        'vault_secrets': vault_secrets,
                        'environment': 'netlify',
                        'timestamp': str(datetime.now(timezone.utc))
                    })
                }
            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': 'Vault error',
                        'message': str(e),
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
                            <strong>/api/stats</strong> - Get database statistics
                        </div>
                        
                        <div class="endpoint">
                            <span class="method get">GET</span>
                            <strong>/api/database</strong> - Get database and vault information
                        </div>
                        
                        <div class="endpoint">
                            <span class="method get">GET</span>
                            <strong>/api/vault</strong> - Get vault status and secrets
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
                    'available_endpoints': ['/health', '/api/students', '/api/stats', '/api/database', '/api/vault', '/docs', '/']
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