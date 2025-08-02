import os
import asyncpg
from typing import Optional

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/studenttracker")

# Global database connection pool
db_pool: Optional[asyncpg.Pool] = None

async def get_db_pool() -> asyncpg.Pool:
    """Get or create database connection pool."""
    global db_pool
    if db_pool is None:
        db_pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=1,
            max_size=10,
            command_timeout=60
        )
    return db_pool

async def init_database():
    """Initialize database tables."""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        # Create students table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS students (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) UNIQUE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """)
        
        # Create progress table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS student_progress (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                student_id UUID REFERENCES students(id) ON DELETE CASCADE,
                week VARCHAR(50) NOT NULL,
                status BOOLEAN DEFAULT FALSE,
                notes TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                UNIQUE(student_id, week)
            )
        """)
        
        # Create courses table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS courses (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name VARCHAR(255) NOT NULL,
                description TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """)
        
        # Create student_courses table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS student_courses (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                student_id UUID REFERENCES students(id) ON DELETE CASCADE,
                course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
                enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                UNIQUE(student_id, course_id)
            )
        """)

async def close_database():
    """Close database connection pool."""
    global db_pool
    if db_pool:
        await db_pool.close()
        db_pool = None
