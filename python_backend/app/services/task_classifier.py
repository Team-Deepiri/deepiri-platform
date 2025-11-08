"""
Task Classification Service
NLP model to parse and classify tasks (e.g., "Write report", "Finish coding module", "Read chapter 5")
"""
from typing import Dict, List, Optional, Tuple
import json
import openai
from ..settings import settings
from ..logging_config import get_logger

logger = get_logger("pyagent.task_classifier")


class TaskClassifier:
    """Classifies tasks into categories and extracts metadata."""
    
    TASK_TYPES = [
        'study',      # Reading, learning, studying
        'code',       # Programming, coding tasks
        'creative',   # Writing, design, creative work
        'manual',     # General tasks, manual work
        'meeting',    # Meetings, calls
        'research',   # Research tasks
        'admin'       # Administrative tasks
    ]
    
    COMPLEXITY_LEVELS = ['easy', 'medium', 'hard', 'very_hard']
    
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
    
    async def classify_task(self, task_text: str, description: Optional[str] = None) -> Dict:
        """
        Classify a task and extract metadata.
        
        Args:
            task_text: The task title/text
            description: Optional task description
            
        Returns:
            Dict with classification results:
            - type: task type
            - complexity: complexity level
            - estimated_duration: estimated minutes
            - keywords: extracted keywords
            - category: specific category
        """
        if not self.client:
            logger.warning("OpenAI client not available, using default classification")
            return self._default_classification(task_text)
        
        try:
            system_prompt = """You are a task classification AI. Analyze tasks and classify them into categories.

Task Types:
- study: Reading, learning, studying, homework
- code: Programming, coding, software development
- creative: Writing, design, creative work, content creation
- manual: General tasks, manual work, chores
- meeting: Meetings, calls, appointments
- research: Research, investigation, analysis
- admin: Administrative tasks, organization

For each task, return JSON with:
- type: one of the task types above
- complexity: 'easy', 'medium', 'hard', or 'very_hard'
- estimated_duration: estimated minutes (integer)
- keywords: array of important keywords
- category: specific subcategory (e.g., 'homework', 'bug_fix', 'essay_writing')
- requires_focus: boolean (true if task needs deep focus)
- can_break_into_chunks: boolean (true if task can be split into smaller parts)
"""
            
            user_prompt = f"Task: {task_text}"
            if description:
                user_prompt += f"\nDescription: {description}"
            user_prompt += "\n\nClassify this task and return JSON only."
            
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
            
            import asyncio
            completion = await asyncio.to_thread(
                self.client.chat.completions.create,
                model=settings.OPENAI_MODEL,
                messages=messages,
                temperature=0.3,
                max_tokens=500,
                response_format={"type": "json_object"}
            )
            
            response_content = completion.choices[0].message.content
            classification = json.loads(response_content)
            
            # Validate and set defaults
            if classification.get('type') not in self.TASK_TYPES:
                classification['type'] = 'manual'
            if classification.get('complexity') not in self.COMPLEXITY_LEVELS:
                classification['complexity'] = 'medium'
            
            logger.info("Task classified", 
                       task=task_text[:50], 
                       type=classification.get('type'),
                       complexity=classification.get('complexity'))
            
            return classification
            
        except Exception as e:
            logger.error("Task classification error", error=str(e))
            return self._default_classification(task_text)
    
    def _default_classification(self, task_text: str) -> Dict:
        """Fallback classification when AI is unavailable."""
        task_lower = task_text.lower()
        
        # Simple keyword-based classification
        if any(kw in task_lower for kw in ['code', 'program', 'debug', 'fix', 'implement']):
            task_type = 'code'
        elif any(kw in task_lower for kw in ['read', 'study', 'learn', 'homework', 'chapter']):
            task_type = 'study'
        elif any(kw in task_lower for kw in ['write', 'design', 'create', 'draft']):
            task_type = 'creative'
        elif any(kw in task_lower for kw in ['meeting', 'call', 'appointment']):
            task_type = 'meeting'
        else:
            task_type = 'manual'
        
        return {
            'type': task_type,
            'complexity': 'medium',
            'estimated_duration': 30,
            'keywords': task_text.split()[:5],
            'category': 'general',
            'requires_focus': True,
            'can_break_into_chunks': True
        }
    
    async def batch_classify(self, tasks: List[Dict]) -> List[Dict]:
        """Classify multiple tasks."""
        results = []
        for task in tasks:
            classification = await self.classify_task(
                task.get('title', ''),
                task.get('description')
            )
            results.append({
                **task,
                'classification': classification
            })
        return results


# Singleton instance
_task_classifier = None

def get_task_classifier() -> TaskClassifier:
    """Get singleton TaskClassifier instance."""
    global _task_classifier
    if _task_classifier is None:
        _task_classifier = TaskClassifier()
    return _task_classifier

