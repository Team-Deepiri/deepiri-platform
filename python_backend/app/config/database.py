"""
Database Configuration
Connection management for MongoDB and SQL databases
"""
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import MongoClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from ..settings import settings
from ..logging_config import get_logger

logger = get_logger("config.database")

_mongo_client = None
_sql_engine = None
_sql_session = None


def get_mongo_client():
    """Get MongoDB client singleton."""
    global _mongo_client
    if _mongo_client is None:
        try:
            mongo_uri = settings.MONGO_URI if hasattr(settings, 'MONGO_URI') else "mongodb://localhost:27017"
            _mongo_client = AsyncIOMotorClient(mongo_uri)
            logger.info("MongoDB client initialized")
        except Exception as e:
            logger.error("MongoDB connection failed", error=str(e))
    return _mongo_client


def get_sql_engine():
    """Get SQLAlchemy engine."""
    global _sql_engine
    if _sql_engine is None:
        sql_uri = getattr(settings, 'SQL_URI', 'sqlite:///deepiri.db')
        _sql_engine = create_engine(sql_uri, echo=False)
        logger.info("SQL engine initialized")
    return _sql_engine


def get_sql_session():
    """Get SQLAlchemy session."""
    global _sql_session
    if _sql_session is None:
        engine = get_sql_engine()
        _sql_session = sessionmaker(bind=engine)
    return _sql_session()

