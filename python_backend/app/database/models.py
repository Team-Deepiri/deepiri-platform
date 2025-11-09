"""
Database Models
SQLAlchemy models for data persistence (if using SQL)
Alternative to MongoDB models
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, JSON, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func
from datetime import datetime

Base = declarative_base()


class TaskModel(Base):
    """Task database model."""
    __tablename__ = "tasks"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    task_type = Column(String(50))
    status = Column(String(20), default="pending")
    estimated_duration = Column(Integer)
    actual_duration = Column(Integer)
    classification = Column(JSON)
    metadata = Column(JSON)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class ChallengeModel(Base):
    """Challenge database model."""
    __tablename__ = "challenges"
    
    id = Column(String, primary_key=True)
    task_id = Column(String, index=True)
    user_id = Column(String, nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    challenge_type = Column(String(50))
    difficulty = Column(String(20))
    difficulty_score = Column(Integer)
    points_reward = Column(Integer)
    configuration = Column(JSON)
    status = Column(String(20), default="pending")
    started_at = Column(DateTime)
    completed_at = Column(DateTime)
    created_at = Column(DateTime, default=func.now())


class UserPerformanceModel(Base):
    """User performance tracking model."""
    __tablename__ = "user_performance"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    challenge_id = Column(String, index=True)
    performance_score = Column(Float)
    engagement_score = Column(Float)
    completion_time = Column(Integer)
    attempts = Column(Integer, default=1)
    completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=func.now())


class GamificationModel(Base):
    """Gamification data model."""
    __tablename__ = "gamification"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, unique=True, index=True)
    total_points = Column(Integer, default=0)
    level = Column(Integer, default=1)
    xp = Column(Integer, default=0)
    streak = Column(Integer, default=0)
    badges = Column(JSON, default=list)
    achievements = Column(JSON, default=list)
    last_active = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

