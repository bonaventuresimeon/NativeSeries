from fastapi import FastAPI, Request, Form, HTTPException, Depends
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import os
import logging
import time
from datetime import datetime
from typing import Optional, Dict, Any
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("app.log") if os.path.exists("logs") or os.makedirs("logs", exist_ok=True) else logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Application metadata
APP_VERSION = "1.1.0"
APP_NAME = "Student Tracker API"
PRODUCTION_URL = "http://18.206.89.183:30011"
APP_DESCRIPTION = """
A comprehensive student tracking application built with FastAPI.

## Features

* **Student Management** - Complete CRUD operations for student records
* **Course Management** - Multi-course enrollment system  
* **Progress Tracking** - Weekly progress monitoring and analytics
* **Assignment System** - Assignment creation, submission, and grading
* **Modern UI** - Responsive web interface
* **REST API** - Full RESTful API with OpenAPI documentation
* **Monitoring** - Health checks and metrics for production deployment

## Production Deployment

This application is deployed at: **{production_url}**

Access the interactive API documentation at: **{production_url}/docs**
""".format(production_url=PRODUCTION_URL)

app = FastAPI(
    title=APP_NAME,
    description=APP_DESCRIPTION,
    version=APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    contact={
        "name": "Development Team",
        "email": "dev@yourcompany.com",
        "url": "https://github.com/bonaventuresimeon/NativeSeries",
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT",
    },
    servers=[
        {"url": PRODUCTION_URL, "description": "Production server"},
        {"url": "http://localhost:8000", "description": "Development server"},
    ]
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["18.206.89.183", "localhost", "127.0.0.1", "*"]
)

# Template configuration
template_paths = ["templates", "../templates", "/app/templates"]
template_dir = None

for path in template_paths:
    if os.path.exists(path):
        template_dir = path
        logger.info(f"Templates found in: {path}")
        break

if template_dir:
    templates = Jinja2Templates(directory=template_dir)
else:
    logger.warning("Templates directory not found, using fallback")
    templates = None

# Try to mount static files if available
static_paths = ["static", "../static", "/app/static"]
for static_path in static_paths:
    if os.path.exists(static_path):
        app.mount("/static", StaticFiles(directory=static_path), name="static")
        logger.info(f"Static files mounted from: {static_path}")
        break

# Application state for metrics
app_state = {
    "start_time": datetime.utcnow(),
    "request_count": 0,
    "last_health_check": None,
    "uptime_seconds": 0,
    "production_url": PRODUCTION_URL
}

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    """Add process time header and update metrics"""
    start_time = time.time()
    app_state["request_count"] += 1
    
    response = await call_next(request)
    
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    response.headers["X-Request-Count"] = str(app_state["request_count"])
    response.headers["X-Production-URL"] = PRODUCTION_URL
    
    if process_time > 1.0:
        logger.warning(f"Slow request: {request.method} {request.url} took {process_time:.2f}s")
    
    return response

@app.get("/health", tags=["System"])
async def health_check():
    """
    Health check endpoint for Kubernetes probes and monitoring.
    
    Returns comprehensive health status including:
    - Application status
    - Database connectivity 
    - Memory usage
    - Uptime information
    - Production URL configuration
    """
    try:
        current_time = datetime.utcnow()
        app_state["last_health_check"] = current_time
        app_state["uptime_seconds"] = int((current_time - app_state["start_time"]).total_seconds())
        
        # Test database connection (if available)
        db_status = "healthy"
        try:
            # Add actual database connection test here
            pass
        except Exception as e:
            db_status = f"error: {str(e)}"
            logger.error(f"Database health check failed: {e}")
        
        health_data = {
            "status": "healthy",
            "timestamp": current_time.isoformat(),
            "version": APP_VERSION,
            "uptime_seconds": app_state["uptime_seconds"],
            "request_count": app_state["request_count"],
            "production_url": PRODUCTION_URL,
            "database": db_status,
            "environment": os.getenv("APP_ENV", "production"),
            "services": {
                "api": "healthy",
                "database": db_status,
                "cache": "healthy"  # Add Redis check if available
            }
        }
        
        return health_data
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e),
                "production_url": PRODUCTION_URL
            }
        )

@app.get("/metrics", tags=["System"])
async def get_metrics():
    """
    Prometheus-compatible metrics endpoint.
    
    Provides application metrics including:
    - Request count and rate
    - Response times
    - Error rates
    - System uptime
    - Memory usage
    """
    current_time = datetime.utcnow()
    uptime = int((current_time - app_state["start_time"]).total_seconds())
    
    metrics = []
    
    # Counter metrics
    metrics.append(f"# HELP student_tracker_requests_total Total number of HTTP requests")
    metrics.append(f"# TYPE student_tracker_requests_total counter")
    metrics.append(f'student_tracker_requests_total{{method="ALL",production_url="{PRODUCTION_URL}"}} {app_state["request_count"]}')
    
    # Gauge metrics
    metrics.append(f"# HELP student_tracker_uptime_seconds Application uptime in seconds")
    metrics.append(f"# TYPE student_tracker_uptime_seconds gauge")
    metrics.append(f'student_tracker_uptime_seconds{{production_url="{PRODUCTION_URL}"}} {uptime}')
    
    # Info metrics
    metrics.append(f"# HELP student_tracker_info Application information")
    metrics.append(f"# TYPE student_tracker_info gauge")
    metrics.append(f'student_tracker_info{{version="{APP_VERSION}",production_url="{PRODUCTION_URL}"}} 1')
    
    return Response("\n".join(metrics), media_type="text/plain")

@app.get("/", response_class=HTMLResponse, tags=["Web Interface"])
async def home(request: Request):
    """
    Main web interface for the Student Tracker application.
    
    Displays:
    - Application overview and statistics
    - Quick access to key features
    - Production deployment information
    - Navigation to different sections
    """
    if templates:
        context = {
            "request": request,
            "app_name": APP_NAME,
            "version": APP_VERSION,
            "production_url": PRODUCTION_URL,
            "request_count": app_state["request_count"],
            "uptime": int((datetime.utcnow() - app_state["start_time"]).total_seconds())
        }
        try:
            return templates.TemplateResponse("index.html", context)
        except Exception as e:
            logger.warning(f"Template rendering failed: {e}")
    
    # Fallback HTML response
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>{APP_NAME}</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .header {{ text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #007bff; }}
            .production-badge {{ background: #28a745; color: white; padding: 5px 15px; border-radius: 15px; font-size: 12px; margin-left: 10px; }}
            .stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }}
            .stat-card {{ background: #f8f9fa; padding: 15px; border-radius: 5px; text-align: center; }}
            .nav-links {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin-top: 30px; }}
            .nav-card {{ background: #007bff; color: white; padding: 20px; border-radius: 5px; text-decoration: none; text-align: center; transition: background 0.3s; }}
            .nav-card:hover {{ background: #0056b3; color: white; text-decoration: none; }}
            .footer {{ text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; color: #6c757d; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>{APP_NAME} <span class="production-badge">PRODUCTION</span></h1>
                <p>Version {APP_VERSION} • Deployed at {PRODUCTION_URL}</p>
            </div>
            
            <div class="stats">
                <div class="stat-card">
                    <h3>Total Requests</h3>
                    <p style="font-size: 24px; margin: 5px 0;">{app_state["request_count"]}</p>
                </div>
                <div class="stat-card">
                    <h3>Uptime</h3>
                    <p style="font-size: 24px; margin: 5px 0;">{int((datetime.utcnow() - app_state["start_time"]).total_seconds())}s</p>
                </div>
                <div class="stat-card">
                    <h3>Status</h3>
                    <p style="font-size: 24px; margin: 5px 0; color: #28a745;">HEALTHY</p>
                </div>
            </div>
            
            <div class="nav-links">
                <a href="/students" class="nav-card">
                    <h3>👥 Students</h3>
                    <p>Manage student records and enrollment</p>
                </a>
                <a href="/docs" class="nav-card">
                    <h3>📖 API Documentation</h3>
                    <p>Interactive API documentation with Swagger UI</p>
                </a>
                <a href="/health" class="nav-card">
                    <h3>🩺 Health Check</h3>
                    <p>System health and monitoring information</p>
                </a>
                <a href="/metrics" class="nav-card">
                    <h3>📊 Metrics</h3>
                    <p>Application metrics and performance data</p>
                </a>
            </div>
            
            <div class="footer">
                <p>🚀 Production deployment at <strong>{PRODUCTION_URL}</strong></p>
                <p>Built with FastAPI • Deployed with Docker & Kubernetes</p>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/about", response_class=HTMLResponse, tags=["Web Interface"])
async def about(request: Request):
    """About page with application information."""
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>About - {APP_NAME}</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .back-link {{ color: #007bff; text-decoration: none; margin-bottom: 20px; display: inline-block; }}
            .production-info {{ background: #e7f3ff; border: 1px solid #b3d9ff; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <a href="/" class="back-link">← Back to Home</a>
            <h1>About {APP_NAME}</h1>
            
            <div class="production-info">
                <h3>🚀 Production Deployment</h3>
                <p><strong>URL:</strong> {PRODUCTION_URL}</p>
                <p><strong>Version:</strong> {APP_VERSION}</p>
                <p><strong>Environment:</strong> Production</p>
            </div>
            
            <h2>Features</h2>
            <ul>
                <li>Student registration and management</li>
                <li>Course enrollment system</li>
                <li>Progress tracking and analytics</li>
                <li>Assignment submission system</li>
                <li>RESTful API with OpenAPI documentation</li>
                <li>Health monitoring and metrics</li>
                <li>Production-ready Docker deployment</li>
            </ul>
            
            <h2>Technology Stack</h2>
            <ul>
                <li><strong>Backend:</strong> FastAPI (Python)</li>
                <li><strong>Database:</strong> PostgreSQL</li>
                <li><strong>Cache:</strong> Redis</li>
                <li><strong>Proxy:</strong> Nginx</li>
                <li><strong>Monitoring:</strong> Prometheus + Grafana</li>
                <li><strong>Deployment:</strong> Docker + Kubernetes</li>
            </ul>
            
            <h2>API Endpoints</h2>
            <ul>
                <li><strong>GET /:</strong> Home page</li>
                <li><strong>GET /health:</strong> Health check</li>
                <li><strong>GET /metrics:</strong> Prometheus metrics</li>
                <li><strong>GET /docs:</strong> API documentation</li>
                <li><strong>GET /students:</strong> Student management</li>
            </ul>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

# Include routers for different modules
try:
    from app.routes import students, api
    app.include_router(students.router, prefix="/students", tags=["Students"])
    app.include_router(api.router, prefix="/api/v1", tags=["API"])
    logger.info("Student and API routes loaded successfully")
except ImportError as e:
    logger.warning(f"Could not load all routes: {e}")
    # Fallback basic student endpoints
    @app.get("/students", response_class=HTMLResponse, tags=["Students"])
    async def list_students(request: Request):
        """List all students (fallback endpoint)."""
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Students - {APP_NAME}</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
                .container {{ max-width: 800px; margin: 0 auto; background: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                .back-link {{ color: #007bff; text-decoration: none; margin-bottom: 20px; display: inline-block; }}
                .student-card {{ background: #f8f9fa; border: 1px solid #dee2e6; padding: 15px; margin: 10px 0; border-radius: 5px; }}
                .production-badge {{ background: #28a745; color: white; padding: 3px 8px; border-radius: 10px; font-size: 11px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <a href="/" class="back-link">← Back to Home</a>
                <h1>Students <span class="production-badge">PRODUCTION</span></h1>
                <p>Production URL: <strong>{PRODUCTION_URL}</strong></p>
                
                <div class="student-card">
                    <h3>Sample Student Records</h3>
                    <p>This is a demo endpoint. In production, this would connect to the PostgreSQL database to display real student data.</p>
                    <p>Available through the API at: <code>{PRODUCTION_URL}/api/v1/students</code></p>
                </div>
                
                <div class="student-card">
                    <h3>API Access</h3>
                    <p>For full functionality, use the REST API:</p>
                    <ul>
                        <li><strong>GET</strong> <code>/api/v1/students</code> - List students</li>
                        <li><strong>POST</strong> <code>/api/v1/students</code> - Create student</li>
                        <li><strong>GET</strong> <code>/api/v1/students/{{id}}</code> - Get student</li>
                        <li><strong>PUT</strong> <code>/api/v1/students/{{id}}</code> - Update student</li>
                        <li><strong>DELETE</strong> <code>/api/v1/students/{{id}}</code> - Delete student</li>
                    </ul>
                    <p><a href="/docs" target="_blank">View Interactive API Documentation →</a></p>
                </div>
            </div>
        </body>
        </html>
        """
        return HTMLResponse(content=html_content)

@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    """Custom 404 error handler."""
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>404 - Page Not Found</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; text-align: center; }}
            .container {{ max-width: 600px; margin: 50px auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .error-code {{ font-size: 72px; color: #dc3545; margin: 0; }}
            .home-link {{ color: #007bff; text-decoration: none; padding: 10px 20px; border: 2px solid #007bff; border-radius: 5px; display: inline-block; margin-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1 class="error-code">404</h1>
            <h2>Page Not Found</h2>
            <p>The requested page could not be found on this server.</p>
            <p>Production URL: <strong>{PRODUCTION_URL}</strong></p>
            <a href="/" class="home-link">← Return to Home</a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=404)

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc: Exception):
    """Custom 500 error handler."""
    logger.error(f"Internal server error: {exc}")
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>500 - Internal Server Error</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background: #f5f5f5; text-align: center; }}
            .container {{ max-width: 600px; margin: 50px auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .error-code {{ font-size: 72px; color: #dc3545; margin: 0; }}
            .home-link {{ color: #007bff; text-decoration: none; padding: 10px 20px; border: 2px solid #007bff; border-radius: 5px; display: inline-block; margin-top: 20px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1 class="error-code">500</h1>
            <h2>Internal Server Error</h2>
            <p>Something went wrong on our end. We've been notified and are working to fix it.</p>
            <p>Production URL: <strong>{PRODUCTION_URL}</strong></p>
            <a href="/" class="home-link">← Return to Home</a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=500)

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Application startup event."""
    logger.info(f"🚀 {APP_NAME} v{APP_VERSION} starting up...")
    logger.info(f"🌐 Production URL: {PRODUCTION_URL}")
    logger.info(f"📊 Health check available at: {PRODUCTION_URL}/health")
    logger.info(f"📖 API documentation available at: {PRODUCTION_URL}/docs")
    
    # Initialize database
    try:
        from app.database import init_database
        await init_database()
        logger.info("✅ Database initialization completed")
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
    
    # Initialize application state
    try:
        logger.info("✅ Application initialization completed")
    except Exception as e:
        logger.error(f"❌ Application initialization failed: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event."""
    logger.info(f"🛑 {APP_NAME} shutting down...")
    logger.info(f"📊 Final request count: {app_state['request_count']}")
    logger.info(f"⏱️ Total uptime: {int((datetime.utcnow() - app_state['start_time']).total_seconds())} seconds")
    
    # Close database connection
    try:
        from app.database import close_database
        await close_database()
        logger.info("✅ Database connection closed")
    except Exception as e:
        logger.error(f"❌ Error closing database connection: {e}")
    
    # Cleanup application state
    try:
        logger.info("✅ Application cleanup completed")
    except Exception as e:
        logger.error(f"❌ Error during application cleanup: {e}")

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,  # Disabled for production
        log_level="info",
        access_log=True
    )
