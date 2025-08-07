import os
import logging
import json
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

class NetlifyDatabaseConfig:
    """Netlify-specific database configuration using environment variables, vault, and in-memory storage"""

    def __init__(self):
        # Environment variables for Netlify
        self.app_env = os.getenv("APP_ENV", "production")
        self.app_name = os.getenv("APP_NAME", "NativeSeries")
        self.app_version = os.getenv("APP_VERSION", "1.0.0")
        
        # Database configuration (using environment variables)
        self.database_url = os.getenv("DATABASE_URL", "memory://")
        self.database_name = os.getenv("DATABASE_NAME", "nativeseries")
        self.collection_name = os.getenv("COLLECTION_NAME", "students")
        
        # MongoDB configuration
        self.mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
        
        # Vault configuration
        self.vault_addr = os.getenv("VAULT_ADDR")
        self.vault_role_id = os.getenv("VAULT_ROLE_ID")
        self.vault_secret_id = os.getenv("VAULT_SECRET_ID")
        
        # Security configuration
        self.secret_key = os.getenv("SECRET_KEY", "your-secret-key-here")
        self.debug = os.getenv("DEBUG", "false").lower() == "true"
        
        # Logging configuration
        self.log_level = os.getenv("LOG_LEVEL", "INFO")
        
        logger.info(f"Netlify Database config initialized: {self.database_name}")
        logger.info(f"Environment: {self.app_env}")
        logger.info(f"Debug mode: {self.debug}")
        logger.info(f"Vault configured: {self.is_vault_configured()}")
        logger.info(f"External DB configured: {self.is_external_db_configured()}")

    def get_database_url(self) -> str:
        """Get database URL with fallback"""
        return self.database_url

    def is_memory_storage(self) -> bool:
        """Check if using in-memory storage"""
        return self.database_url.startswith("memory://") and not self.is_external_db_configured()

    def is_vault_configured(self) -> bool:
        """Check if Vault is properly configured"""
        return all([self.vault_addr, self.vault_role_id, self.vault_secret_id])

    def is_external_db_configured(self) -> bool:
        """Check if external database is configured"""
        return (self.mongo_uri and 
                not self.mongo_uri.startswith("mongodb://localhost") and
                not self.mongo_uri.startswith("memory://"))

    def get_secret_key(self) -> str:
        """Get secret key for security"""
        return self.secret_key

    async def get_vault_secrets(self) -> Optional[Dict[str, Any]]:
        """Get secrets from Vault if configured"""
        if not self.is_vault_configured():
            return None
        
        try:
            # Import hvac for Vault integration
            import hvac
            
            # Initialize Vault client
            client = hvac.Client(url=self.vault_addr)
            
            # Authenticate with AppRole
            auth_response = client.auth.approle.login(
                role_id=self.vault_role_id,
                secret_id=self.vault_secret_id
            )
            
            if auth_response['auth']:
                # Get secrets from Vault
                secret_response = client.secrets.kv.v2.read_secret_version(
                    path='nativeseries/database',
                    mount_point='secret'
                )
                
                if secret_response and 'data' in secret_response:
                    logger.info("✅ Successfully retrieved secrets from Vault")
                    return secret_response['data']['data']
            
            logger.warning("⚠️ Failed to retrieve secrets from Vault")
            return None
            
        except ImportError:
            logger.warning("⚠️ hvac not available, skipping Vault integration")
            return None
        except Exception as e:
            logger.error(f"❌ Vault error: {e}")
            return None


# Global database configuration
db_config = NetlifyDatabaseConfig()

# In-memory storage for Netlify Functions (fallback)
_in_memory_students = {
    "1": {
        "id": "1",
        "name": "John Doe",
        "email": "john@example.com",
        "course": "Computer Science",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
    },
    "2": {
        "id": "2",
        "name": "Jane Smith",
        "email": "jane@example.com",
        "course": "Mathematics",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
    },
    "3": {
        "id": "3",
        "name": "Bob Johnson",
        "email": "bob@example.com",
        "course": "Physics",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
    }
}

_in_memory_courses = {
    "1": {
        "id": "1",
        "name": "Computer Science",
        "description": "Introduction to Computer Science",
        "students_count": 1
    },
    "2": {
        "id": "2",
        "name": "Mathematics",
        "description": "Advanced Mathematics",
        "students_count": 1
    },
    "3": {
        "id": "3",
        "name": "Physics",
        "description": "Classical Physics",
        "students_count": 1
    }
}

_in_memory_progress = {
    "1": {
        "student_id": "1",
        "week": "1",
        "status": "completed",
        "notes": "Good progress",
        "updated_at": "2024-01-01T00:00:00Z"
    }
}

# External database connection
_external_client = None
_external_database = None
_external_collection = None


async def init_database():
    """Initialize database connection for Netlify"""
    global _external_client, _external_database, _external_collection
    
    try:
        # Try to connect to external database if configured
        if db_config.is_external_db_configured():
            try:
                import motor.motor_asyncio
                
                # Get secrets from Vault if available
                vault_secrets = await db_config.get_vault_secrets()
                if vault_secrets:
                    # Use Vault secrets for database connection
                    mongo_uri = vault_secrets.get('mongo_uri', db_config.mongo_uri)
                    database_name = vault_secrets.get('database_name', db_config.database_name)
                    collection_name = vault_secrets.get('collection_name', db_config.collection_name)
                else:
                    # Use environment variables
                    mongo_uri = db_config.mongo_uri
                    database_name = db_config.database_name
                    collection_name = db_config.collection_name
                
                # Connect to MongoDB
                _external_client = motor.motor_asyncio.AsyncIOMotorClient(mongo_uri)
                _external_database = _external_client[database_name]
                _external_collection = _external_database.get_collection(collection_name)
                
                # Test connection
                await _external_client.admin.command("ping")
                logger.info("✅ External MongoDB connection established successfully")
                logger.info(f"📊 Connected to database: {database_name}")
                return True
                
            except ImportError:
                logger.warning("⚠️ Motor not available, using in-memory storage")
            except Exception as e:
                logger.error(f"❌ External database connection failed: {e}")
                logger.info("🔄 Falling back to in-memory storage")
        
        # Use in-memory storage
        logger.info("✅ Netlify database initialized successfully")
        logger.info(f"📊 Using in-memory storage with {len(_in_memory_students)} students")
        return True
        
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        return False


async def close_database():
    """Close database connection"""
    global _external_client
    
    if _external_client:
        _external_client.close()
        logger.info("External database connection closed")
    else:
        logger.info("Database connection closed (in-memory storage)")


class NetlifyStudentCollection:
    """Netlify-specific student collection using external database or in-memory storage"""

    async def insert_one(self, document: Dict[str, Any]) -> Dict[str, Any]:
        """Insert a new student"""
        if _external_collection:
            # Use external database
            result = await _external_collection.insert_one(document)
            logger.info(f"✅ Student created in external DB: {result.inserted_id}")
            return {"inserted_id": str(result.inserted_id), "acknowledged": True}
        else:
            # Use in-memory storage
            student_id = str(len(_in_memory_students) + 1)
            document["id"] = student_id
            document["created_at"] = datetime.now(timezone.utc).isoformat()
            document["updated_at"] = datetime.now(timezone.utc).isoformat()
            
            _in_memory_students[student_id] = document
            logger.info(f"✅ Student created in memory: {student_id}")
            
            return {"inserted_id": student_id, "acknowledged": True}

    async def find_one(self, filter_dict: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Find a single student"""
        if _external_collection:
            # Use external database
            result = await _external_collection.find_one(filter_dict)
            return result
        else:
            # Use in-memory storage
            student_id = filter_dict.get("id")
            if student_id:
                return _in_memory_students.get(student_id)
            
            # Search by other fields
            for student in _in_memory_students.values():
                if all(student.get(k) == v for k, v in filter_dict.items()):
                    return student
            return None

    async def find(self, filter_dict: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Find multiple students"""
        if _external_collection:
            # Use external database
            cursor = _external_collection.find(filter_dict or {})
            results = await cursor.to_list(length=None)
            return results
        else:
            # Use in-memory storage
            if not filter_dict:
                return list(_in_memory_students.values())
            
            results = []
            for student in _in_memory_students.values():
                if all(student.get(k) == v for k, v in filter_dict.items()):
                    results.append(student)
            return results

    async def update_one(self, filter_dict: Dict[str, Any], update_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Update a single student"""
        if _external_collection:
            # Use external database
            result = await _external_collection.update_one(filter_dict, update_dict)
            logger.info(f"✅ Student updated in external DB: {result.modified_count}")
            return {"modified_count": result.modified_count, "acknowledged": True}
        else:
            # Use in-memory storage
            student_id = filter_dict.get("id")
            if student_id and student_id in _in_memory_students:
                _in_memory_students[student_id].update(update_dict.get("$set", {}))
                _in_memory_students[student_id]["updated_at"] = datetime.now(timezone.utc).isoformat()
                logger.info(f"✅ Student updated in memory: {student_id}")
                return {"modified_count": 1, "acknowledged": True}
            return {"modified_count": 0, "acknowledged": True}

    async def count_documents(self, filter_dict: Optional[Dict[str, Any]] = None) -> int:
        """Count documents"""
        if _external_collection:
            # Use external database
            return await _external_collection.count_documents(filter_dict or {})
        else:
            # Use in-memory storage
            if not filter_dict:
                return len(_in_memory_students)
            
            count = 0
            for student in _in_memory_students.values():
                if all(student.get(k) == v for k, v in filter_dict.items()):
                    count += 1
            return count

    async def delete_one(self, filter_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Delete a single student"""
        if _external_collection:
            # Use external database
            result = await _external_collection.delete_one(filter_dict)
            logger.info(f"✅ Student deleted from external DB: {result.deleted_count}")
            return {"deleted_count": result.deleted_count, "acknowledged": True}
        else:
            # Use in-memory storage
            student_id = filter_dict.get("id")
            if student_id and student_id in _in_memory_students:
                del _in_memory_students[student_id]
                logger.info(f"✅ Student deleted from memory: {student_id}")
                return {"deleted_count": 1, "acknowledged": True}
            return {"deleted_count": 0, "acknowledged": True}


def get_student_collection():
    """Get student collection for Netlify"""
    return NetlifyStudentCollection()


def get_database_stats() -> Dict[str, Any]:
    """Get database statistics"""
    storage_type = "external-mongodb" if _external_collection else "in-memory"
    
    stats = {
        "storage_type": storage_type,
        "environment": db_config.app_env,
        "vault_configured": db_config.is_vault_configured(),
        "external_db_configured": db_config.is_external_db_configured(),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    if _external_collection:
        # Get stats from external database
        try:
            stats.update({
                "database_name": db_config.database_name,
                "collection_name": db_config.collection_name,
                "connection_status": "connected"
            })
        except Exception as e:
            stats.update({
                "connection_status": f"error: {str(e)}"
            })
    else:
        # Get stats from in-memory storage
        stats.update({
            "total_students": len(_in_memory_students),
            "total_courses": len(_in_memory_courses),
            "total_progress_records": len(_in_memory_progress)
        })
    
    return stats


def get_vault_status() -> Dict[str, Any]:
    """Get Vault connection status"""
    return {
        "vault_configured": db_config.is_vault_configured(),
        "vault_addr": db_config.vault_addr,
        "vault_role_id": "***" if db_config.vault_role_id else None,
        "vault_secret_id": "***" if db_config.vault_secret_id else None,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


def export_data() -> Dict[str, Any]:
    """Export all data for backup"""
    if _external_collection:
        # Export from external database
        return {
            "storage_type": "external-mongodb",
            "database_name": db_config.database_name,
            "exported_at": datetime.now(timezone.utc).isoformat()
        }
    else:
        # Export from in-memory storage
        return {
            "students": _in_memory_students,
            "courses": _in_memory_courses,
            "progress": _in_memory_progress,
            "storage_type": "in-memory",
            "exported_at": datetime.now(timezone.utc).isoformat()
        }


def import_data(data: Dict[str, Any]) -> bool:
    """Import data from backup"""
    try:
        if data.get("storage_type") == "external-mongodb":
            logger.info("✅ External database backup detected")
            return True
        else:
            # Import to in-memory storage
            global _in_memory_students, _in_memory_courses, _in_memory_progress
            
            if "students" in data:
                _in_memory_students.update(data["students"])
            if "courses" in data:
                _in_memory_courses.update(data["courses"])
            if "progress" in data:
                _in_memory_progress.update(data["progress"])
            
            logger.info("✅ Data imported successfully to in-memory storage")
            return True
    except Exception as e:
        logger.error(f"❌ Data import failed: {e}")
        return False