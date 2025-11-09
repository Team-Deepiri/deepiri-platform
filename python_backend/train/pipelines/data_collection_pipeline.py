"""
Data Collection Pipeline
Collect training data from local models and API usage
"""
import json
import asyncio
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime
import sqlite3
from ..logging_config import get_logger

logger = get_logger("train.data_collection")


class DataCollectionPipeline:
    """Collect training data from various sources."""
    
    def __init__(self, db_path: str = "data/collection.db"):
        self.db_path = db_path
        self._init_database()
    
    def _init_database(self):
        """Initialize data collection database."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS task_classifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_text TEXT NOT NULL,
                description TEXT,
                predicted_type TEXT,
                predicted_complexity TEXT,
                predicted_duration INTEGER,
                actual_type TEXT,
                actual_complexity TEXT,
                actual_duration INTEGER,
                user_feedback REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS challenge_generations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT,
                task_text TEXT NOT NULL,
                generated_challenge TEXT,
                challenge_type TEXT,
                difficulty TEXT,
                points_reward INTEGER,
                user_engagement REAL,
                completion_rate REAL,
                performance_score REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS user_interactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT,
                action_type TEXT,
                context TEXT,
                model_used TEXT,
                response_time_ms REAL,
                success BOOLEAN,
                feedback REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        conn.close()
        logger.info("Data collection database initialized")
    
    def collect_classification(
        self,
        task_text: str,
        description: Optional[str],
        prediction: Dict,
        actual: Optional[Dict] = None,
        feedback: Optional[float] = None
    ):
        """Collect task classification data."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO task_classifications 
            (task_text, description, predicted_type, predicted_complexity, predicted_duration,
             actual_type, actual_complexity, actual_duration, user_feedback)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            task_text,
            description,
            prediction.get('type'),
            prediction.get('complexity'),
            prediction.get('estimated_duration'),
            actual.get('type') if actual else None,
            actual.get('complexity') if actual else None,
            actual.get('estimated_duration') if actual else None,
            feedback
        ))
        
        conn.commit()
        conn.close()
        logger.debug("Classification data collected")
    
    def collect_challenge_generation(
        self,
        task_text: str,
        challenge: Dict,
        user_engagement: Optional[float] = None,
        completion_rate: Optional[float] = None,
        performance_score: Optional[float] = None
    ):
        """Collect challenge generation data."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO challenge_generations
            (task_text, generated_challenge, challenge_type, difficulty, points_reward,
             user_engagement, completion_rate, performance_score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            task_text,
            json.dumps(challenge),
            challenge.get('type'),
            challenge.get('difficulty'),
            challenge.get('pointsReward'),
            user_engagement,
            completion_rate,
            performance_score
        ))
        
        conn.commit()
        conn.close()
        logger.debug("Challenge generation data collected")
    
    def collect_interaction(
        self,
        user_id: str,
        action_type: str,
        context: Dict,
        model_used: str,
        response_time_ms: float,
        success: bool,
        feedback: Optional[float] = None
    ):
        """Collect user interaction data."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO user_interactions
            (user_id, action_type, context, model_used, response_time_ms, success, feedback)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            user_id,
            action_type,
            json.dumps(context),
            model_used,
            response_time_ms,
            success,
            feedback
        ))
        
        conn.commit()
        conn.close()
        logger.debug("Interaction data collected")
    
    def export_for_training(self, output_path: str, data_type: str = "classification"):
        """Export collected data for training."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if data_type == "classification":
            cursor.execute("""
                SELECT task_text, description, predicted_type, predicted_complexity,
                       actual_type, actual_complexity, user_feedback
                FROM task_classifications
                WHERE actual_type IS NOT NULL OR user_feedback IS NOT NULL
            """)
            
            with open(output_path, 'w') as f:
                for row in cursor.fetchall():
                    data = {
                        "text": row[0] + (" " + row[1] if row[1] else ""),
                        "label": row[4] if row[4] else row[2],
                        "metadata": {
                            "complexity": row[5] if row[5] else row[3],
                            "feedback": row[6]
                        }
                    }
                    f.write(json.dumps(data) + '\n')
        
        elif data_type == "challenge":
            cursor.execute("""
                SELECT task_text, generated_challenge, challenge_type, difficulty,
                       user_engagement, completion_rate, performance_score
                FROM challenge_generations
                WHERE user_engagement IS NOT NULL
            """)
            
            with open(output_path, 'w') as f:
                for row in cursor.fetchall():
                    challenge = json.loads(row[1])
                    data = {
                        "input": row[0],
                        "output": challenge.get('description', ''),
                        "metadata": {
                            "type": row[2],
                            "difficulty": row[3],
                            "engagement": row[4],
                            "completion_rate": row[5],
                            "performance": row[6]
                        }
                    }
                    f.write(json.dumps(data) + '\n')
        
        conn.close()
        logger.info("Data exported for training", path=output_path, type=data_type)


_data_collector = None

def get_data_collector() -> DataCollectionPipeline:
    """Get singleton data collector."""
    global _data_collector
    if _data_collector is None:
        _data_collector = DataCollectionPipeline()
    return _data_collector

