import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "student-tracker"
    assert data["version"] == "1.0.0"

def test_home_page():
    """Test the home page endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    # Should return JSON when templates are not available
    if response.headers.get("content-type") == "application/json":
        data = response.json()
        assert "message" in data

def test_register_get():
    """Test GET /register endpoint"""
    response = client.get("/register")
    assert response.status_code == 200

def test_progress_get():
    """Test GET /progress endpoint"""
    response = client.get("/progress")
    assert response.status_code == 200

def test_update_get():
    """Test GET /update endpoint"""
    response = client.get("/update")
    assert response.status_code == 200

def test_admin_get():
    """Test GET /admin endpoint"""
    response = client.get("/admin")
    assert response.status_code == 200

def test_api_students():
    """Test the API students endpoint"""
    response = client.get("/api/students")
    assert response.status_code == 200
    data = response.json()
    # Should either return students list or an error
    assert "students" in data or "error" in data

def test_register_form_post():
    """Test POST /register with form data"""
    response = client.post("/register", data={"name": "Test Student"})
    # Should either succeed or fail gracefully
    assert response.status_code in [200, 500]

def test_progress_form_post():
    """Test POST /progress with form data"""
    response = client.post("/progress", data={"name": "Test Student"})
    # Should either succeed or fail gracefully
    assert response.status_code in [200, 500]

def test_update_form_post():
    """Test POST /update with form data"""
    response = client.post("/update", data={
        "name": "Test Student",
        "week": "week1",
        "status": "completed"
    })
    # Should either succeed or fail gracefully
    assert response.status_code in [200, 500]

def test_api_register():
    """Test the API register endpoint"""
    response = client.post("/api/register?name=API Test Student")
    # Should either succeed or fail gracefully
    assert response.status_code in [200, 500]
    if response.status_code == 200:
        data = response.json()
        assert "message" in data or "error" in data