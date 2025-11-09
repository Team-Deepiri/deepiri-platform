"""
Motivational AI Service
Transformer-based message generation with personality adaptation
"""
import openai
from typing import Dict, List, Optional
from datetime import datetime
from ..settings import settings
from ..logging_config import get_logger

logger = get_logger("pyagent.motivational_ai")


class MotivationalAI:
    """
    Generates motivational messages with:
    - Personality-adapted communication
    - Context-aware timing
    - Growth mindset reinforcement
    - Failure recovery messaging
    """
    
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        
        self.personality_profiles = {
            'encouraging': {
                'tone': 'warm and supportive',
                'style': 'uses positive reinforcement',
                'examples': ['Great job!', 'You\'re doing amazing!', 'Keep it up!']
            },
            'analytical': {
                'tone': 'data-driven and precise',
                'style': 'focuses on metrics and progress',
                'examples': ['Your completion rate is 85%', 'You\'ve improved by 12%', 'Current streak: 7 days']
            },
            'playful': {
                'tone': 'fun and energetic',
                'style': 'uses gamification language',
                'examples': ['Level up!', 'Achievement unlocked!', 'You\'re on fire!']
            },
            'professional': {
                'tone': 'formal and respectful',
                'style': 'focuses on productivity and efficiency',
                'examples': ['Excellent progress', 'Well done', 'Outstanding performance']
            }
        }
    
    async def generate_motivational_message(
        self,
        context: Dict,
        message_type: str = 'encouragement',
        personality: str = 'encouraging'
    ) -> str:
        """
        Generate motivational message based on context.
        
        Args:
            context: User context (achievements, progress, state)
            message_type: Type of message (encouragement, milestone, recovery, etc.)
            personality: Personality profile to use
            
        Returns:
            Generated motivational message
        """
        try:
            if not self.client:
                return self._fallback_message(context, message_type)
            
            prompt = self._build_prompt(context, message_type, personality)
            
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {"role": "system", "content": self._get_system_prompt(personality)},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,
                max_tokens=150
            )
            
            message = response.choices[0].message.content.strip()
            logger.info("Motivational message generated", message_type=message_type, personality=personality)
            return message
            
        except Exception as e:
            logger.error("Error generating motivational message", error=str(e))
            return self._fallback_message(context, message_type)
    
    def _build_prompt(self, context: Dict, message_type: str, personality: str) -> str:
        """Build prompt for message generation."""
        base_prompt = f"Generate a {personality} motivational message for the following context:\n\n"
        
        if message_type == 'encouragement':
            base_prompt += f"User just completed: {context.get('achievement', 'a task')}\n"
            base_prompt += f"Current streak: {context.get('streak', 0)} days\n"
            base_prompt += f"Progress: {context.get('progress', 0)}%\n"
        
        elif message_type == 'milestone':
            base_prompt += f"User reached milestone: {context.get('milestone', 'achievement')}\n"
            base_prompt += f"Level: {context.get('level', 1)}\n"
            base_prompt += f"Total points: {context.get('total_points', 0)}\n"
        
        elif message_type == 'recovery':
            base_prompt += f"User failed a challenge but is trying again\n"
            base_prompt += f"Previous attempts: {context.get('attempts', 1)}\n"
            base_prompt += f"Encourage them to keep trying\n"
        
        elif message_type == 'growth':
            base_prompt += f"User improved their performance\n"
            base_prompt += f"Improvement: {context.get('improvement', 'significant')}\n"
            base_prompt += f"Focus on growth mindset\n"
        
        base_prompt += "\nGenerate a short, motivational message (1-2 sentences)."
        return base_prompt
    
    def _get_system_prompt(self, personality: str) -> str:
        """Get system prompt for personality."""
        profile = self.personality_profiles.get(personality, self.personality_profiles['encouraging'])
        
        return f"""You are a motivational AI assistant with a {profile['tone']} personality.
Your communication style {profile['style']}.
Keep messages concise (1-2 sentences), authentic, and focused on the user's progress and potential.
Use growth mindset principles: emphasize effort, learning, and improvement over fixed outcomes."""
    
    def _fallback_message(self, context: Dict, message_type: str) -> str:
        """Fallback message if AI generation fails."""
        fallbacks = {
            'encouragement': [
                "Great job! Keep up the excellent work!",
                "You're making fantastic progress!",
                "Every step forward counts. Well done!"
            ],
            'milestone': [
                "Congratulations on reaching this milestone!",
                "Amazing achievement! You're leveling up!",
                "Incredible progress! Keep pushing forward!"
            ],
            'recovery': [
                "Don't give up! Every attempt is a learning opportunity.",
                "You've got this! Try again with what you've learned.",
                "Failure is just feedback. You're growing stronger!"
            ],
            'growth': [
                "Your improvement shows your dedication!",
                "You're getting better every day!",
                "Progress over perfection. You're on the right track!"
            ]
        }
        
        messages = fallbacks.get(message_type, fallbacks['encouragement'])
        return messages[hash(str(context)) % len(messages)]
    
    async def generate_contextual_encouragement(
        self,
        userId: str,
        current_state: Dict,
        recent_activity: List[Dict]
    ) -> str:
        """Generate encouragement based on current context."""
        # Analyze context
        if current_state.get('streak', 0) > 7:
            message_type = 'milestone'
            context = {'milestone': f"{current_state['streak']} day streak"}
        elif recent_activity and recent_activity[-1].get('failed', False):
            message_type = 'recovery'
            context = {'attempts': len([a for a in recent_activity if a.get('failed')])}
        elif current_state.get('improvement', 0) > 0.1:
            message_type = 'growth'
            context = {'improvement': f"{current_state['improvement']*100:.1f}%"}
        else:
            message_type = 'encouragement'
            context = {
                'achievement': recent_activity[-1].get('type', 'task') if recent_activity else 'progress',
                'streak': current_state.get('streak', 0),
                'progress': current_state.get('progress', 0)
            }
        
        # Determine personality based on user preferences
        personality = current_state.get('preferred_personality', 'encouraging')
        
        return await self.generate_motivational_message(context, message_type, personality)
    
    async def generate_failure_recovery_message(
        self,
        challenge_type: str,
        attempt_number: int,
        user_skill_level: float
    ) -> str:
        """Generate message to help user recover from failure."""
        context = {
            'challenge_type': challenge_type,
            'attempts': attempt_number,
            'skill_level': user_skill_level
        }
        
        # Adjust message based on attempt number
        if attempt_number == 1:
            message_type = 'recovery'
            context['message'] = 'first_attempt'
        elif attempt_number <= 3:
            message_type = 'recovery'
            context['message'] = 'persistence'
        else:
            message_type = 'recovery'
            context['message'] = 'support'
        
        return await self.generate_motivational_message(context, message_type, 'encouraging')
    
    async def generate_milestone_message(
        self,
        milestone_type: str,
        milestone_data: Dict
    ) -> str:
        """Generate message for milestone achievement."""
        context = {
            'milestone': milestone_type,
            **milestone_data
        }
        
        return await self.generate_motivational_message(context, 'milestone', 'playful')


# Singleton instance
_motivational_ai = None

def get_motivational_ai() -> MotivationalAI:
    """Get singleton MotivationalAI instance."""
    global _motivational_ai
    if _motivational_ai is None:
        _motivational_ai = MotivationalAI()
    return _motivational_ai

