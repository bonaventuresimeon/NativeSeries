from fastapi import FastAPI, Request, Form, HTTPException, Depends
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
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
APP_DESCRIPTION = """
A comprehensive student tracking application built with FastAPI.

## Features

* **Student Management**: Create, read, update, and delete student records
* **Health Monitoring**: Built-in health checks for Kubernetes deployments
* **Performance Metrics**: Application performance monitoring
* **Modern UI**: Responsive web interface
* **API Documentation**: Auto-generated OpenAPI/Swagger documentation
* **Production Ready**: Containerized with Docker and Kubernetes support

## Authentication

This API supports multiple authentication methods for secure access.
"""

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
        {"url": "http://localhost:8000", "description": "Development server"},
        {"url": "http://18.208.149.195:8011", "description": "Production server"},
    ]
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["*"]  # Configure appropriately for production
)

# Configure templates directory - handle both local and container paths
template_paths = ["templates", "../templates", "/app/templates"]
template_dir = None
for path in template_paths:
    if os.path.exists(path):
        template_dir = path
        break

if template_dir:
    templates = Jinja2Templates(directory=template_dir)
    logger.info(f"Templates loaded from: {template_dir}")
else:
    templates = None
    logger.warning("No template directory found")

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
    "uptime_seconds": 0
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
    
    # Log slow requests
    if process_time > 1.0:
        logger.warning(f"Slow request: {request.method} {request.url} took {process_time:.2f}s")
    
    return response

@app.get("/health", tags=["System"])
async def health_check():
    """
    Health check endpoint for Kubernetes probes and monitoring.
    
    Returns application health status, version, and basic metrics.
    """
    try:
        # Update uptime
        app_state["uptime_seconds"] = (datetime.utcnow() - app_state["start_time"]).total_seconds()
        app_state["last_health_check"] = datetime.utcnow().isoformat()
        
        # Try to test database connectivity if available
        db_status = "not_configured"
        try:
            from app.crud import count_students
            await count_students()
            db_status = "connected"
        except Exception as e:
            logger.debug(f"Database not available: {e}")
            db_status = "unavailable"
        
        health_data = {
            "status": "healthy",
            "service": "student-tracker",
            "version": APP_VERSION,
            "timestamp": app_state["last_health_check"],
            "uptime_seconds": app_state["uptime_seconds"],
            "request_count": app_state["request_count"],
            "database_status": db_status,
            "environment": os.getenv("APP_ENV", "development")
        }
        
        logger.debug("Health check successful")
        return JSONResponse(status_code=200, content=health_data)
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "student-tracker",
                "version": APP_VERSION,
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )

@app.get("/metrics", tags=["System"])
async def get_metrics():
    """
    Prometheus-compatible metrics endpoint.
    
    Returns application metrics in a format suitable for monitoring systems.
    """
    uptime = (datetime.utcnow() - app_state["start_time"]).total_seconds()
    
    metrics = {
        "app_info": {
            "name": APP_NAME,
            "version": APP_VERSION,
            "uptime_seconds": uptime,
            "start_time": app_state["start_time"].isoformat()
        },
        "http_requests_total": app_state["request_count"],
        "app_uptime_seconds": uptime,
        "app_version_info": {"version": APP_VERSION}
    }
    
    return JSONResponse(content=metrics)

@app.get("/", response_class=HTMLResponse, tags=["Web Interface"])
async def home(request: Request):
    """
    Main web interface for the Student Tracker application.
    
    Displays the dashboard with student statistics and navigation.
    """
    if not templates:
        return JSONResponse({
            "message": "Student Tracker API",
            "status": "running",
            "version": APP_VERSION,
            "docs": "/docs",
            "health": "/health"
        })
    
    try:
        from app.crud import count_students
        total = await count_students()
    except Exception as e:
        logger.warning(f"Could not get student count: {e}")
        total = 0
    
    context = {
        "request": request,
        "total": total,
        "app_name": APP_NAME,
        "app_version": APP_VERSION,
        "uptime_seconds": int((datetime.utcnow() - app_state["start_time"]).total_seconds())
    }
    
    return templates.TemplateResponse("index.html", context)

@app.get("/about", response_class=HTMLResponse, tags=["Web Interface"])
async def about(request: Request):
    """About page with application information."""
    if not templates:
        return JSONResponse({
            "app": APP_NAME,
            "version": APP_VERSION,
            "description": "A comprehensive student tracking application",
            "repository": "https://github.com/bonaventuresimeon/NativeSeries"
        })
    
    context = {
        "request": request,
        "app_name": APP_NAME,
        "app_version": APP_VERSION,
        "description": APP_DESCRIPTION
    }
    
    return templates.TemplateResponse("about.html", context)

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
        if not templates:
            return JSONResponse({"students": [], "message": "Students module not available"})
        
        try:
            from app.crud import get_all_students
            students_data = await get_all_students()
        except Exception as e:
            logger.error(f"Error fetching students: {e}")
            students_data = []
        
        context = {
            "request": request,
            "students": students_data,
            "app_name": APP_NAME
        }
        
        return templates.TemplateResponse("students.html", context)

@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    """Custom 404 error handler."""
    if request.url.path.startswith("/api/"):
        return JSONResponse(
            status_code=404,
            content={"error": "Not Found", "message": "The requested endpoint was not found"}
        )
    
    if templates:
        return templates.TemplateResponse(
            "404.html",
            {"request": request, "app_name": APP_NAME},
            status_code=404
        )
    
    return JSONResponse(
        status_code=404,
        content={"error": "Not Found", "message": "Page not found"}
    )

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc: Exception):
    """Custom 500 error handler."""
    logger.error(f"Internal server error: {exc}")
    
    if request.url.path.startswith("/api/"):
        return JSONResponse(
            status_code=500,
            content={"error": "Internal Server Error", "message": "An unexpected error occurred"}
        )
    
    if templates:
        return templates.TemplateResponse(
            "500.html",
            {"request": request, "app_name": APP_NAME},
            status_code=500
        )
    
    return JSONResponse(
        status_code=500,
        content={"error": "Internal Server Error", "message": "An unexpected error occurred"}
    )

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Application startup event."""
    logger.info(f"Starting {APP_NAME} v{APP_VERSION}")
    logger.info(f"Environment: {os.getenv('APP_ENV', 'development')}")
    logger.info(f"Templates: {'Available' if templates else 'Not available'}")
    
    # Initialize database if available
    try:
        from app.database import init_db
        await init_db()
        logger.info("Database initialized successfully")
    except ImportError:
        logger.info("Database module not available, running in minimal mode")
    except Exception as e:
        logger.warning(f"Database initialization failed: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event."""
    uptime = (datetime.utcnow() - app_state["start_time"]).total_seconds()
    logger.info(f"Shutting down {APP_NAME} after {uptime:.2f} seconds")
    logger.info(f"Total requests processed: {app_state['request_count']}")

if __name__ == "__main__":
    # Development server configuration
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
        access_log=True
    )
