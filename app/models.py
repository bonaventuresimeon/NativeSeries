from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class Student(BaseModel):
    id: str
    name: str
    email: Optional[str] = None
    created_at: Optional[datetime] = None
    progress: Dict[str, Any] = {}

class StudentCreate(BaseModel):
    name: str
    email: Optional[str] = None

class StudentUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None

class ProgressUpdate(BaseModel):
    week: str
    status: bool
    notes: Optional[str] = None
