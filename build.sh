#!/bin/bash

# NativeSeries - Enhanced Build Script for Netlify
# This script ensures the application builds correctly with database display

set -e

echo "🚀 Starting NativeSeries build..."

# Check if we're in the right directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found"
    exit 1
fi

# Create public directory if it doesn't exist
mkdir -p public

# Create enhanced index.html
echo "📄 Creating enhanced index.html..."
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Student Tracker</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center; 
            padding: 40px 20px;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .content {
            padding: 40px;
        }
        .status { 
            padding: 20px; 
            background: #f8f9fa; 
            border-radius: 10px; 
            margin-bottom: 30px;
            border-left: 4px solid #28a745;
        }
        .success { background: #d4edda; color: #155724; border-left-color: #28a745; }
        .error { background: #f8d7da; color: #721c24; border-left-color: #dc3545; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
            border: 1px solid #e9ecef;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.15);
        }
        .card h3 {
            margin-top: 0;
            color: #495057;
        }
        .card a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }
        .card a:hover {
            text-decoration: underline;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background 0.3s ease;
        }
        .btn:hover {
            background: #5a6fd8;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎓 NativeSeries</h1>
            <p>Advanced Student Tracking & Database Management System</p>
        </div>
        
        <div class="content">
            <div class="status success">
                <h2>✅ Application Status</h2>
                <p><strong>Status:</strong> Running on Netlify</p>
                <p><strong>Environment:</strong> Production</p>
                <p><strong>Database:</strong> In-Memory Storage (Netlify Functions)</p>
                <p><strong>API:</strong> Fully Functional</p>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h3>📊 Database Management</h3>
                    <p>View and manage your student database</p>
                    <a href="/database.html" class="btn">View Database</a>
                </div>
                
                <div class="card">
                    <h3>👥 Student Management</h3>
                    <p>Add, edit, and manage student records</p>
                    <a href="/students.html" class="btn">Manage Students</a>
                </div>
                
                <div class="card">
                    <h3>📈 Progress Tracking</h3>
                    <p>Track student progress and performance</p>
                    <a href="/progress.html" class="btn">Track Progress</a>
                </div>
                
                <div class="card">
                    <h3>🔧 API Endpoints</h3>
                    <p>Access the REST API directly</p>
                    <a href="/api.html" class="btn">API Docs</a>
                </div>
                
                <div class="card">
                    <h3>🏥 Health Check</h3>
                    <p>Check application health status</p>
                    <a href="/health" class="btn">Health Status</a>
                </div>
                
                <div class="card">
                    <h3>📋 Admin Panel</h3>
                    <p>Administrative functions and settings</p>
                    <a href="/admin.html" class="btn">Admin Panel</a>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# Create database display page
echo "📊 Creating database.html..."
cat > public/database.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Database Viewer</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: #f8f9fa;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background: white;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .content {
            padding: 20px;
        }
        .back-btn {
            color: white;
            text-decoration: none;
            padding: 8px 16px;
            border: 1px solid white;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        .back-btn:hover {
            background: white;
            color: #667eea;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .table-container {
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #667eea;
            color: white;
            font-weight: 500;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .refresh-btn {
            background: #28a745;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin-bottom: 20px;
        }
        .refresh-btn:hover {
            background: #218838;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 NativeSeries Database</h1>
            <a href="/" class="back-btn">← Back to Home</a>
        </div>
        
        <div class="content">
            <button class="refresh-btn" onclick="loadDatabase()">🔄 Refresh Data</button>
            
            <div class="stats" id="stats">
                <div class="stat-card">
                    <div class="stat-number" id="total-students">-</div>
                    <div>Total Students</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="total-courses">-</div>
                    <div>Total Courses</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="total-progress">-</div>
                    <div>Progress Records</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="db-size">-</div>
                    <div>Database Size</div>
                </div>
            </div>
            
            <div id="loading" class="loading">
                <h3>Loading database...</h3>
                <p>Please wait while we fetch the latest data.</p>
            </div>
            
            <div id="error" class="error" style="display: none;"></div>
            
            <div class="table-container">
                <h3>📋 Student Records</h3>
                <table id="students-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Course</th>
                            <th>Created</th>
                            <th>Updated</th>
                        </tr>
                    </thead>
                    <tbody id="students-body">
                    </tbody>
                </table>
            </div>
            
            <div class="table-container" style="margin-top: 40px;">
                <h3>📚 Course Information</h3>
                <table id="courses-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Course Name</th>
                            <th>Description</th>
                            <th>Students</th>
                        </tr>
                    </thead>
                    <tbody id="courses-body">
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        async function loadDatabase() {
            const loading = document.getElementById('loading');
            const error = document.getElementById('error');
            const stats = document.getElementById('stats');
            
            loading.style.display = 'block';
            error.style.display = 'none';
            stats.style.display = 'none';
            
            try {
                // Load students
                const studentsResponse = await fetch('/.netlify/functions/api/students');
                const studentsData = await studentsResponse.json();
                
                // Load courses
                const coursesResponse = await fetch('/.netlify/functions/api/courses');
                const coursesData = await coursesResponse.json();
                
                // Load progress
                const progressResponse = await fetch('/.netlify/functions/api/progress');
                const progressData = await progressResponse.json();
                
                // Update stats
                document.getElementById('total-students').textContent = studentsData.count || 0;
                document.getElementById('total-courses').textContent = coursesData.count || 0;
                document.getElementById('total-progress').textContent = progressData.count || 0;
                document.getElementById('db-size').textContent = 'In-Memory';
                
                // Update students table
                const studentsBody = document.getElementById('students-body');
                studentsBody.innerHTML = '';
                
                if (studentsData.students && studentsData.students.length > 0) {
                    studentsData.students.forEach(student => {
                        const row = document.createElement('tr');
                        row.innerHTML = `
                            <td>${student.id || '-'}</td>
                            <td>${student.name || '-'}</td>
                            <td>${student.email || '-'}</td>
                            <td>${student.course || '-'}</td>
                            <td>${student.created_at || '-'}</td>
                            <td>${student.updated_at || '-'}</td>
                        `;
                        studentsBody.appendChild(row);
                    });
                } else {
                    studentsBody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No students found</td></tr>';
                }
                
                // Update courses table
                const coursesBody = document.getElementById('courses-body');
                coursesBody.innerHTML = '';
                
                if (coursesData.courses && coursesData.courses.length > 0) {
                    coursesData.courses.forEach(course => {
                        const row = document.createElement('tr');
                        row.innerHTML = `
                            <td>${course.id || '-'}</td>
                            <td>${course.name || '-'}</td>
                            <td>${course.description || '-'}</td>
                            <td>${course.students_count || 0}</td>
                        `;
                        coursesBody.appendChild(row);
                    });
                } else {
                    coursesBody.innerHTML = '<tr><td colspan="4" style="text-align: center;">No courses found</td></tr>';
                }
                
                loading.style.display = 'none';
                stats.style.display = 'grid';
                
            } catch (err) {
                loading.style.display = 'none';
                error.style.display = 'block';
                error.textContent = `Error loading database: ${err.message}`;
            }
        }
        
        // Load data on page load
        document.addEventListener('DOMContentLoaded', loadDatabase);
    </script>
</body>
</html>
EOF

# Create API documentation page
echo "📚 Creating api.html..."
cat > public/api.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - API Documentation</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: #f8f9fa;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .content {
            padding: 20px;
        }
        .back-btn {
            color: white;
            text-decoration: none;
            padding: 8px 16px;
            border: 1px solid white;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        .back-btn:hover {
            background: white;
            color: #667eea;
        }
        .endpoint {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            border-left: 4px solid #667eea;
        }
        .method {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 0.9em;
            margin-right: 10px;
        }
        .get { background: #28a745; color: white; }
        .post { background: #007bff; color: white; }
        .put { background: #ffc107; color: black; }
        .delete { background: #dc3545; color: white; }
        .url {
            font-family: monospace;
            background: #e9ecef;
            padding: 8px 12px;
            border-radius: 4px;
            margin: 10px 0;
            display: block;
        }
        .description {
            color: #666;
            margin: 10px 0;
        }
        .test-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            margin-top: 10px;
        }
        .test-btn:hover {
            background: #5a6fd8;
        }
        .response {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            padding: 15px;
            margin-top: 10px;
            font-family: monospace;
            white-space: pre-wrap;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📚 NativeSeries API Documentation</h1>
            <a href="/" class="back-btn">← Back to Home</a>
        </div>
        
        <div class="content">
            <div class="endpoint">
                <span class="method get">GET</span>
                <strong>Health Check</strong>
                <div class="url">/.netlify/functions/health</div>
                <div class="description">Check the health status of the application</div>
                <button class="test-btn" onclick="testEndpoint('/.netlify/functions/health', 'health-response')">Test Endpoint</button>
                <div id="health-response" class="response"></div>
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span>
                <strong>Get All Students</strong>
                <div class="url">/.netlify/functions/api/students</div>
                <div class="description">Retrieve all student records from the database</div>
                <button class="test-btn" onclick="testEndpoint('/.netlify/functions/api/students', 'students-response')">Test Endpoint</button>
                <div id="students-response" class="response"></div>
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span>
                <strong>Get All Courses</strong>
                <div class="url">/.netlify/functions/api/courses</div>
                <div class="description">Retrieve all course information</div>
                <button class="test-btn" onclick="testEndpoint('/.netlify/functions/api/courses', 'courses-response')">Test Endpoint</button>
                <div id="courses-response" class="response"></div>
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span>
                <strong>Get All Progress</strong>
                <div class="url">/.netlify/functions/api/progress</div>
                <div class="description">Retrieve all progress records</div>
                <button class="test-btn" onclick="testEndpoint('/.netlify/functions/api/progress', 'progress-response')">Test Endpoint</button>
                <div id="progress-response" class="response"></div>
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span>
                <strong>Database Statistics</strong>
                <div class="url">/.netlify/functions/api/stats</div>
                <div class="description">Get database statistics and metadata</div>
                <button class="test-btn" onclick="testEndpoint('/.netlify/functions/api/stats', 'stats-response')">Test Endpoint</button>
                <div id="stats-response" class="response"></div>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span>
                <strong>Add Student</strong>
                <div class="url">/.netlify/functions/api/students</div>
                <div class="description">Add a new student record (requires JSON body)</div>
                <button class="test-btn" onclick="testPostEndpoint('/.netlify/functions/api/students', 'add-student-response')">Test Endpoint</button>
                <div id="add-student-response" class="response"></div>
            </div>
        </div>
    </div>

    <script>
        async function testEndpoint(url, responseId) {
            const responseDiv = document.getElementById(responseId);
            responseDiv.style.display = 'block';
            responseDiv.textContent = 'Loading...';
            
            try {
                const response = await fetch(url);
                const data = await response.json();
                responseDiv.textContent = JSON.stringify(data, null, 2);
            } catch (error) {
                responseDiv.textContent = `Error: ${error.message}`;
            }
        }
        
        async function testPostEndpoint(url, responseId) {
            const responseDiv = document.getElementById(responseId);
            responseDiv.style.display = 'block';
            responseDiv.textContent = 'Loading...';
            
            try {
                const testData = {
                    name: "Test Student",
                    email: "test@example.com",
                    course: "Test Course"
                };
                
                const response = await fetch(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(testData)
                });
                
                const data = await response.json();
                responseDiv.textContent = JSON.stringify(data, null, 2);
            } catch (error) {
                responseDiv.textContent = `Error: ${error.message}`;
            }
        }
    </script>
</body>
</html>
EOF

# Create other essential pages
echo "📄 Creating additional pages..."

# Students management page
cat > public/students.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Student Management</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; }
        .content { padding: 20px; }
        .back-btn { color: white; text-decoration: none; padding: 8px 16px; border: 1px solid white; border-radius: 5px; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: 500; }
        input, select { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        .btn { background: #667eea; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        .btn:hover { background: #5a6fd8; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>👥 Student Management</h1>
            <a href="/" class="back-btn">← Back to Home</a>
        </div>
        <div class="content">
            <h2>Add New Student</h2>
            <form id="student-form">
                <div class="form-group">
                    <label>Name:</label>
                    <input type="text" id="name" required>
                </div>
                <div class="form-group">
                    <label>Email:</label>
                    <input type="email" id="email" required>
                </div>
                <div class="form-group">
                    <label>Course:</label>
                    <input type="text" id="course" required>
                </div>
                <button type="submit" class="btn">Add Student</button>
            </form>
        </div>
    </div>
</body>
</html>
EOF

# Progress tracking page
cat > public/progress.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Progress Tracking</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; }
        .content { padding: 20px; }
        .back-btn { color: white; text-decoration: none; padding: 8px 16px; border: 1px solid white; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📈 Progress Tracking</h1>
            <a href="/" class="back-btn">← Back to Home</a>
        </div>
        <div class="content">
            <h2>Student Progress Overview</h2>
            <p>Track student performance and progress metrics.</p>
            <p><a href="/database.html">View detailed progress in the database</a></p>
        </div>
    </div>
</body>
</html>
EOF

# Admin panel page
cat > public/admin.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NativeSeries - Admin Panel</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; }
        .content { padding: 20px; }
        .back-btn { color: white; text-decoration: none; padding: 8px 16px; border: 1px solid white; border-radius: 5px; }
        .admin-section { margin-bottom: 30px; padding: 20px; background: #f8f9fa; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Admin Panel</h1>
            <a href="/" class="back-btn">← Back to Home</a>
        </div>
        <div class="content">
            <div class="admin-section">
                <h2>Database Management</h2>
                <p><a href="/database.html">View Database</a></p>
                <p><a href="/api.html">API Documentation</a></p>
            </div>
            <div class="admin-section">
                <h2>System Status</h2>
                <p><a href="/health">Health Check</a></p>
                <p>Environment: Netlify Functions</p>
                <p>Database: In-Memory Storage</p>
            </div>
        </div>
    </div>
</body>
</html>
EOF

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
            'version': '1.0.0',
            'database': 'in-memory',
            'functions': 'active'
        })
    }
EOF
fi

echo "✅ Enhanced build completed successfully!"
echo "📦 Static files are ready in public/"
echo "🔧 Functions are ready in netlify/functions/"
echo "📊 Database display pages created!"
echo "🌐 Ready for Netlify deployment!"