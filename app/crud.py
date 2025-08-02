# CRUD operations for Student Tracker application
from app.database import student_collection
from app.models import Student
from uuid import uuid4

async def create_student(name: str):
    student_id = str(uuid4())
    student = Student(id=student_id, name=name)
    await student_collection.insert_one(student.dict())
    return student

async def get_student(student_id: str):
    return await student_collection.find_one({"id": student_id})

async def update_progress(student_id: str, week: str):
    await student_collection.update_one(
        {"id": student_id},
        {"$set": {f"progress.{week}": True}}
    )
    return await get_student(student_id)

async def get_all_students():
    cursor = student_collection.find({})
    students = []
    async for student in cursor:
        students.append(Student(**student))
    return students

async def count_students():
    return await student_collection.count_documents({})

async def get_student_progress(student_id: str):
    student = await get_student(student_id)
    if student:
        return {
            "student_name": student["name"],
            "progress": student.get("progress", {})
        }
    return {}

async def update_student_progress(student_id: str, week: str, status: str):
    status_bool = status.lower() == "true"
    await student_collection.update_one(
        {"id": student_id},
        {"$set": {f"progress.{week}": status_bool}}
    )
    return await get_student(student_id)