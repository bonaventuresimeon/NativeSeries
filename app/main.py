from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
import os

app = FastAPI(
    title="Student Tracker API",
    description="A comprehensive student tracking application",
    version="1.0.0"
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
else:
    # Fallback - create a minimal templates object
    templates = None

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "service": "student-tracker",
            "version": "1.0.0"
        }
    )

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    if not templates:
        return JSONResponse({"message": "Student Tracker API", "status": "running"})
    
    try:
        from app.crud import count_students  # ✅ delayed import
        total = await count_students()
    except Exception as e:
        total = 0
        
    return templates.TemplateResponse("index.html", {"request": request, "total": total})


@app.get("/register", response_class=HTMLResponse)
async def register_form(request: Request):
    if not templates:
        return JSONResponse({"message": "Use POST /register with name parameter"})
    return templates.TemplateResponse("register.html", {"request": request})


@app.post("/register", response_class=HTMLResponse)
async def register_submit(request: Request, name: str = Form(...)):
    try:
        from app.crud import create_student  # ✅ delayed import
        student = await create_student(name)
        message = f"Welcome, {student.name}!"
        
        if not templates:
            return JSONResponse({"message": message, "student_id": str(student.id) if hasattr(student, 'id') else None})
            
        return templates.TemplateResponse("register.html", {
            "request": request,
            "message": message
        })
    except Exception as e:
        if not templates:
            return JSONResponse({"error": str(e)}, status_code=500)
        return templates.TemplateResponse("register.html", {
            "request": request,
            "error": f"Registration failed: {str(e)}"
        })


@app.get("/progress", response_class=HTMLResponse)
async def progress_form(request: Request):
    if not templates:
        return JSONResponse({"message": "Use POST /progress with name parameter"})
    return templates.TemplateResponse("progress.html", {"request": request})


@app.post("/progress", response_class=HTMLResponse)
async def progress_submit(request: Request, name: str = Form(...)):
    try:
        from app.crud import get_student_progress  # ✅ delayed import
        student = await get_student_progress(name)
        progress = []
        if student and "progress" in student:
            for week, status in student["progress"].items():
                progress.append({"week": week, "status": status})
                
        if not templates:
            return JSONResponse({"name": name, "progress": progress})
            
        return templates.TemplateResponse("progress.html", {
            "request": request,
            "progress": progress,
            "name": name
        })
    except Exception as e:
        if not templates:
            return JSONResponse({"error": str(e)}, status_code=500)
        return templates.TemplateResponse("progress.html", {
            "request": request,
            "error": f"Failed to get progress: {str(e)}"
        })


@app.get("/update", response_class=HTMLResponse)
async def update_form(request: Request):
    if not templates:
        return JSONResponse({"message": "Use POST /update with name, week, and status parameters"})
    return templates.TemplateResponse("update.html", {"request": request})


@app.post("/update", response_class=HTMLResponse)
async def update_submit(
    request: Request,
    name: str = Form(...),
    week: str = Form(...),
    status: str = Form(...)
):
    try:
        from app.crud import update_student_progress  # ✅ delayed import
        await update_student_progress(name, week, status)
        message = "Progress updated successfully!"
        
        if not templates:
            return JSONResponse({"message": message, "name": name, "week": week, "status": status})
            
        return templates.TemplateResponse("update.html", {
            "request": request,
            "message": message
        })
    except Exception as e:
        if not templates:
            return JSONResponse({"error": str(e)}, status_code=500)
        return templates.TemplateResponse("update.html", {
            "request": request,
            "error": f"Update failed: {str(e)}"
        })


@app.get("/admin", response_class=HTMLResponse)
async def admin_panel(request: Request):
    try:
        from app.crud import get_all_students  # ✅ delayed import
        students = await get_all_students()
        
        if not templates:
            return JSONResponse({"students": students})
            
        return templates.TemplateResponse("admin.html", {
            "request": request,
            "students": students
        })
    except Exception as e:
        if not templates:
            return JSONResponse({"error": str(e)}, status_code=500)
        return templates.TemplateResponse("admin.html", {
            "request": request,
            "error": f"Failed to load admin panel: {str(e)}"
        })

# API endpoints for direct access
@app.get("/api/students")
async def list_students():
    """API endpoint to list all students"""
    try:
        from app.crud import get_all_students
        students = await get_all_students()
        return {"students": students}
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

@app.post("/api/register")
async def api_register(name: str):
    """API endpoint to register a student"""
    try:
        from app.crud import create_student
        student = await create_student(name)
        return {"message": f"Student {name} registered successfully", "student": student}
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
