"""
Input Validators
Validate and sanitize user inputs
"""
from typing import Any, Dict, List
import re
from ..logging_config import get_logger

logger = get_logger("utils.validators")


class InputValidator:
    """Input validation utilities."""
    
    @staticmethod
    def validate_task_title(title: str) -> tuple[bool, str]:
        """Validate task title."""
        if not title or not isinstance(title, str):
            return False, "Title must be a non-empty string"
        
        if len(title) < 3:
            return False, "Title must be at least 3 characters"
        
        if len(title) > 200:
            return False, "Title must be less than 200 characters"
        
        if re.search(r'[<>{}[\]\\]', title):
            return False, "Title contains invalid characters"
        
        return True, ""
    
    @staticmethod
    def validate_task_description(description: str) -> tuple[bool, str]:
        """Validate task description."""
        if description is None:
            return True, ""
        
        if not isinstance(description, str):
            return False, "Description must be a string"
        
        if len(description) > 5000:
            return False, "Description must be less than 5000 characters"
        
        return True, ""
    
    @staticmethod
    def validate_task_type(task_type: str) -> tuple[bool, str]:
        """Validate task type."""
        valid_types = ['study', 'code', 'creative', 'manual', 'meeting', 'research', 'admin']
        
        if task_type not in valid_types:
            return False, f"Task type must be one of: {', '.join(valid_types)}"
        
        return True, ""
    
    @staticmethod
    def sanitize_text(text: str) -> str:
        """Sanitize text input."""
        if not text:
            return ""
        
        text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.IGNORECASE | re.DOTALL)
        text = re.sub(r'<[^>]+>', '', text)
        text = text.strip()
        
        return text
    
    @staticmethod
    def validate_challenge_config(config: Dict[str, Any]) -> tuple[bool, str]:
        """Validate challenge configuration."""
        if not isinstance(config, dict):
            return False, "Configuration must be a dictionary"
        
        if 'timeLimit' in config:
            time_limit = config['timeLimit']
            if not isinstance(time_limit, int) or time_limit < 1 or time_limit > 480:
                return False, "Time limit must be between 1 and 480 minutes"
        
        if 'difficulty' in config:
            valid_difficulties = ['easy', 'medium', 'hard', 'very_hard']
            if config['difficulty'] not in valid_difficulties:
                return False, f"Difficulty must be one of: {', '.join(valid_difficulties)}"
        
        return True, ""


def validate_request(data: Dict[str, Any], required_fields: List[str]) -> tuple[bool, str]:
    """Validate request data has required fields."""
    missing = [field for field in required_fields if field not in data or data[field] is None]
    
    if missing:
        return False, f"Missing required fields: {', '.join(missing)}"
    
    return True, ""

