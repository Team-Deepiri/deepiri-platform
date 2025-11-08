"""
Challenge Generation Service
Converts tasks into mini-games/challenges using AI and RL-based adaptation
"""
from typing import Dict, List, Optional, Any
import json
import openai
from ..settings import settings
from ..logging_config import get_logger
from .task_classifier import get_task_classifier

logger = get_logger("pyagent.challenge_generator")


class ChallengeGenerator:
    """Generates gamified challenges from tasks."""
    
    CHALLENGE_TYPES = [
        'quiz',              # Question-based challenges
        'puzzle',            # Puzzle-solving challenges
        'coding_challenge',  # Programming challenges
        'timed_completion', # Time-based completion
        'streak',           # Streak maintenance
        'multiplayer',      # Competitive challenges
        'creative'          # Creative expression challenges
    ]
    
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        self.task_classifier = get_task_classifier()
    
    async def generate_challenge(
        self, 
        task: Dict,
        user_history: Optional[Dict] = None,
        difficulty_preference: Optional[str] = None
    ) -> Dict:
        """
        Generate a gamified challenge from a task.
        
        Args:
            task: Task dict with title, description, type, etc.
            user_history: User's past performance data for adaptation
            difficulty_preference: User's preferred difficulty
            
        Returns:
            Challenge dict with type, configuration, rewards, etc.
        """
        # First classify the task
        classification = await self.task_classifier.classify_task(
            task.get('title', ''),
            task.get('description')
        )
        
        # Determine challenge type based on task type
        challenge_type = self._map_task_to_challenge_type(
            classification.get('type'),
            task.get('type')
        )
        
        # Adapt difficulty based on user history
        difficulty = self._adapt_difficulty(
            classification,
            user_history,
            difficulty_preference
        )
        
        # Generate challenge configuration
        if self.client:
            challenge_config = await self._generate_with_ai(
                task, classification, challenge_type, difficulty
            )
        else:
            challenge_config = self._generate_default(
                task, classification, challenge_type, difficulty
            )
        
        # Add metadata
        challenge_config['taskClassification'] = classification
        challenge_config['userAdaptation'] = {
            'difficulty_adjusted': difficulty != classification.get('complexity'),
            'based_on_history': user_history is not None
        }
        
        return challenge_config
    
    def _map_task_to_challenge_type(self, task_type: str, fallback_type: Optional[str]) -> str:
        """Map task type to appropriate challenge type."""
        mapping = {
            'study': 'quiz',
            'code': 'coding_challenge',
            'creative': 'puzzle',
            'manual': 'timed_completion',
            'meeting': 'timed_completion',
            'research': 'quiz',
            'admin': 'timed_completion'
        }
        return mapping.get(task_type, mapping.get(fallback_type, 'timed_completion'))
    
    def _adapt_difficulty(self, classification: Dict, user_history: Optional[Dict], preference: Optional[str]) -> str:
        """Adapt challenge difficulty based on user performance."""
        if preference:
            return preference
        
        if not user_history:
            return classification.get('complexity', 'medium')
        
        # Simple adaptation: if user performs well, increase difficulty
        avg_performance = user_history.get('average_performance', 0.5)
        current_difficulty = classification.get('complexity', 'medium')
        
        difficulty_levels = ['easy', 'medium', 'hard', 'very_hard']
        try:
            current_idx = difficulty_levels.index(current_difficulty)
        except ValueError:
            current_idx = 1  # medium
        
        # Adjust based on performance
        if avg_performance > 0.8 and current_idx < len(difficulty_levels) - 1:
            return difficulty_levels[current_idx + 1]
        elif avg_performance < 0.4 and current_idx > 0:
            return difficulty_levels[current_idx - 1]
        
        return current_difficulty
    
    async def _generate_with_ai(
        self, 
        task: Dict, 
        classification: Dict,
        challenge_type: str,
        difficulty: str
    ) -> Dict:
        """Generate challenge using AI."""
        try:
            system_prompt = """You are Deepiri AI Challenge Generator. Convert tasks into engaging, gamified challenges.

Generate challenges that:
1. Make tasks fun and motivating
2. Have appropriate difficulty
3. Include clear instructions
4. Have reasonable time limits
5. Reward completion with points

Return JSON with:
- type: challenge type
- title: engaging challenge title
- description: clear instructions
- difficulty: 'easy', 'medium', 'hard', 'very_hard'
- difficultyScore: 1-10
- pointsReward: base points (100-1000)
- configuration: challenge-specific settings
  - timeLimit: minutes (if applicable)
  - questions: array of questions (for quiz)
  - hints: array of hints
  - milestones: checkpoints for progress
"""
            
            user_prompt = f"""Task: {task.get('title', 'Untitled Task')}
Description: {task.get('description', 'No description')}
Task Type: {classification.get('type')}
Complexity: {classification.get('complexity')}
Estimated Duration: {classification.get('estimated_duration', 30)} minutes

Generate a {challenge_type} challenge with {difficulty} difficulty. Make it engaging!"""
            
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
            
            import asyncio
            completion = await asyncio.to_thread(
                self.client.chat.completions.create,
                model=settings.OPENAI_MODEL,
                messages=messages,
                temperature=0.7,
                max_tokens=2000,
                response_format={"type": "json_object"}
            )
            
            response_content = completion.choices[0].message.content
            challenge = json.loads(response_content)
            
            # Validate and set defaults
            challenge.setdefault('type', challenge_type)
            challenge.setdefault('title', f"Challenge: {task.get('title', 'Task')}")
            challenge.setdefault('difficulty', difficulty)
            challenge.setdefault('difficultyScore', self._difficulty_to_score(difficulty))
            challenge.setdefault('pointsReward', self._calculate_points(difficulty, classification))
            challenge.setdefault('configuration', {})
            
            return challenge
            
        except Exception as e:
            logger.error("AI challenge generation error", error=str(e))
            return self._generate_default(task, classification, challenge_type, difficulty)
    
    def _generate_default(
        self,
        task: Dict,
        classification: Dict,
        challenge_type: str,
        difficulty: str
    ) -> Dict:
        """Generate default challenge when AI is unavailable."""
        estimated_duration = classification.get('estimated_duration', 30)
        
        return {
            'type': challenge_type,
            'title': f"Complete: {task.get('title', 'Task')}",
            'description': f"Complete this {classification.get('type')} task within {estimated_duration} minutes!",
            'difficulty': difficulty,
            'difficultyScore': self._difficulty_to_score(difficulty),
            'pointsReward': self._calculate_points(difficulty, classification),
            'configuration': {
                'timeLimit': estimated_duration,
                'milestones': self._generate_milestones(estimated_duration)
            }
        }
    
    def _difficulty_to_score(self, difficulty: str) -> int:
        """Convert difficulty level to score (1-10)."""
        mapping = {
            'easy': 3,
            'medium': 5,
            'hard': 7,
            'very_hard': 9
        }
        return mapping.get(difficulty, 5)
    
    def _calculate_points(self, difficulty: str, classification: Dict) -> int:
        """Calculate points reward based on difficulty and task complexity."""
        base_points = {
            'easy': 100,
            'medium': 250,
            'hard': 500,
            'very_hard': 1000
        }
        base = base_points.get(difficulty, 250)
        
        # Adjust based on estimated duration
        duration = classification.get('estimated_duration', 30)
        if duration > 60:
            base = int(base * 1.5)
        elif duration < 15:
            base = int(base * 0.7)
        
        return base
    
    def _generate_milestones(self, total_minutes: int) -> List[Dict]:
        """Generate progress milestones for a challenge."""
        milestones = []
        if total_minutes > 30:
            milestones.append({
                'name': 'Quarter Complete',
                'progress': 0.25,
                'points': 25
            })
            milestones.append({
                'name': 'Halfway There',
                'progress': 0.5,
                'points': 50
            })
            milestones.append({
                'name': 'Almost Done',
                'progress': 0.75,
                'points': 75
            })
        return milestones


# Singleton instance
_challenge_generator = None

def get_challenge_generator() -> ChallengeGenerator:
    """Get singleton ChallengeGenerator instance."""
    global _challenge_generator
    if _challenge_generator is None:
        _challenge_generator = ChallengeGenerator()
    return _challenge_generator

