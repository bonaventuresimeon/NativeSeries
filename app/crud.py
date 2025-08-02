# CRUD operations for Student Tracker application
from app.database import get_db_pool
from app.models import Student
from typing import List, Optional, Dict, Any
import uuid

async def create_student(name: str, email: Optional[str] = None) -> Student:
    """Create a new student."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        student_id = str(uuid.uuid4())
        query = """
            INSERT INTO students (id, name, email)
            VALUES ($1, $2, $3)
            RETURNING id, name, email, created_at
        """
        row = await conn.fetchrow(query, student_id, name, email)
        return Student(
            id=row['id'],
            name=row['name'],
            email=row['email'],
            created_at=row['created_at']
        )

async def get_student(student_id: str) -> Optional[Student]:
    """Get a student by ID."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = """
            SELECT s.id, s.name, s.email, s.created_at,
                   json_object_agg(sp.week, sp.status) as progress
            FROM students s
            LEFT JOIN student_progress sp ON s.id = sp.student_id
            WHERE s.id = $1
            GROUP BY s.id, s.name, s.email, s.created_at
        """
        row = await conn.fetchrow(query, student_id)
        if row:
            return Student(
                id=row['id'],
                name=row['name'],
                email=row['email'],
                created_at=row['created_at'],
                progress=row['progress'] or {}
            )
        return None

async def get_student_by_name(name: str) -> Optional[Student]:
    """Get a student by name."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = """
            SELECT s.id, s.name, s.email, s.created_at,
                   json_object_agg(sp.week, sp.status) as progress
            FROM students s
            LEFT JOIN student_progress sp ON s.id = sp.student_id
            WHERE s.name = $1
            GROUP BY s.id, s.name, s.email, s.created_at
        """
        row = await conn.fetchrow(query, name)
        if row:
            return Student(
                id=row['id'],
                name=row['name'],
                email=row['email'],
                created_at=row['created_at'],
                progress=row['progress'] or {}
            )
        return None

async def get_all_students() -> List[Student]:
    """Get all students."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = """
            SELECT s.id, s.name, s.email, s.created_at,
                   json_object_agg(sp.week, sp.status) as progress
            FROM students s
            LEFT JOIN student_progress sp ON s.id = sp.student_id
            GROUP BY s.id, s.name, s.email, s.created_at
            ORDER BY s.created_at DESC
        """
        rows = await conn.fetch(query)
        students = []
        for row in rows:
            students.append(Student(
                id=row['id'],
                name=row['name'],
                email=row['email'],
                created_at=row['created_at'],
                progress=row['progress'] or {}
            ))
        return students

async def update_student_progress(student_id: str, week: str, status: bool, notes: Optional[str] = None) -> Optional[Student]:
    """Update student progress for a specific week."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        # Upsert progress
        query = """
            INSERT INTO student_progress (student_id, week, status, notes)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (student_id, week)
            DO UPDATE SET status = $3, notes = $4, updated_at = NOW()
        """
        await conn.execute(query, student_id, week, status, notes)
        
        # Return updated student
        return await get_student(student_id)

async def delete_student(student_id: str) -> bool:
    """Delete a student."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = "DELETE FROM students WHERE id = $1"
        result = await conn.execute(query, student_id)
        return result == "DELETE 1"

async def count_students() -> int:
    """Count total number of students."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = "SELECT COUNT(*) FROM students"
        result = await conn.fetchval(query)
        return result

async def get_student_progress(student_id: str) -> Dict[str, Any]:
    """Get detailed progress for a student."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        query = """
            SELECT s.name, sp.week, sp.status, sp.notes, sp.updated_at
            FROM students s
            LEFT JOIN student_progress sp ON s.id = sp.student_id
            WHERE s.id = $1
            ORDER BY sp.week
        """
        rows = await conn.fetch(query, student_id)
        
        if not rows:
            return {}
        
        progress_data = {
            "student_name": rows[0]['name'],
            "progress": {}
        }
        
        for row in rows:
            if row['week']:
                progress_data["progress"][row['week']] = {
                    "status": row['status'],
                    "notes": row['notes'],
                    "updated_at": row['updated_at']
                }
        
        return progress_data