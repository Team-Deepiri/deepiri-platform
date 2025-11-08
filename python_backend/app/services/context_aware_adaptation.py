"""
Context-Aware Adaptation Service
Unique feature: AI adapts challenges based on real-time context (time of day, energy levels, calendar, etc.)
"""
from typing import Dict, Optional, List
from datetime import datetime
import json
from ..logging_config import get_logger

logger = get_logger("pyagent.context_adaptation")


class ContextAwareAdapter:
    """Adapts challenges based on user context and environment."""
    
    def __init__(self):
        self.energy_patterns = {}
        self.time_preferences = {}
        self.context_history = []
    
    async def analyze_context(self, user_id: str, task: Dict, user_data: Optional[Dict] = None) -> Dict:
        """
        Analyze user context and adapt challenge accordingly.
        
        Context factors:
        - Time of day (morning, afternoon, evening)
        - Historical performance patterns
        - Current energy levels (if provided)
        - Calendar/schedule conflicts
        - Recent task completion patterns
        """
        current_hour = datetime.now().hour
        time_of_day = self._get_time_of_day(current_hour)
        
        context = {
            'time_of_day': time_of_day,
            'hour': current_hour,
            'day_of_week': datetime.now().strftime('%A'),
            'user_id': user_id
        }
        
        if user_data:
            context.update({
                'recent_performance': user_data.get('recent_performance', 0.5),
                'energy_level': user_data.get('energy_level'),
                'focus_score': user_data.get('focus_score'),
                'preferred_work_times': user_data.get('preferred_work_times', []),
                'task_history': user_data.get('task_history', [])
            })
        
        adaptation = self._generate_adaptation(context, task)
        
        logger.info("Context analyzed", user_id=user_id, time_of_day=time_of_day, adaptation=adaptation.get('type'))
        
        return {
            'context': context,
            'adaptation': adaptation,
            'recommendations': self._generate_recommendations(context, task)
        }
    
    def _get_time_of_day(self, hour: int) -> str:
        """Determine time of day category."""
        if 5 <= hour < 12:
            return 'morning'
        elif 12 <= hour < 17:
            return 'afternoon'
        elif 17 <= hour < 21:
            return 'evening'
        else:
            return 'night'
    
    def _generate_adaptation(self, context: Dict, task: Dict) -> Dict:
        """Generate adaptive recommendations based on context."""
        time_of_day = context.get('time_of_day')
        recent_performance = context.get('recent_performance', 0.5)
        
        adaptations = {
            'duration_adjustment': 1.0,
            'difficulty_adjustment': 1.0,
            'challenge_type_hint': None,
            'break_suggestions': [],
            'motivation_boost': False
        }
        
        if time_of_day == 'morning':
            if recent_performance < 0.4:
                adaptations['duration_adjustment'] = 0.7
                adaptations['challenge_type_hint'] = 'short_sprint'
                adaptations['motivation_boost'] = True
            else:
                adaptations['duration_adjustment'] = 1.2
                adaptations['challenge_type_hint'] = 'deep_work'
        
        elif time_of_day == 'afternoon':
            adaptations['break_suggestions'] = ['pomodoro_25_5']
            if recent_performance > 0.7:
                adaptations['difficulty_adjustment'] = 1.3
        
        elif time_of_day == 'evening':
            adaptations['duration_adjustment'] = 0.8
            adaptations['challenge_type_hint'] = 'light_task'
            adaptations['break_suggestions'] = ['frequent_breaks']
        
        else:
            adaptations['duration_adjustment'] = 0.6
            adaptations['challenge_type_hint'] = 'quick_win'
        
        energy_level = context.get('energy_level')
        if energy_level:
            if energy_level < 0.3:
                adaptations['duration_adjustment'] *= 0.5
                adaptations['motivation_boost'] = True
            elif energy_level > 0.8:
                adaptations['difficulty_adjustment'] *= 1.2
        
        return adaptations
    
    def _generate_recommendations(self, context: Dict, task: Dict) -> List[str]:
        """Generate personalized recommendations."""
        recommendations = []
        time_of_day = context.get('time_of_day')
        
        if time_of_day == 'morning':
            recommendations.append("Morning is your peak time - tackle the hardest challenge!")
            if context.get('recent_performance', 0.5) < 0.4:
                recommendations.append("Start with a quick 15-min warm-up challenge")
        
        elif time_of_day == 'afternoon':
            recommendations.append("Afternoon dip? Try a Pomodoro-style challenge")
            recommendations.append("Consider a 5-min break after 25 minutes")
        
        elif time_of_day == 'evening':
            recommendations.append("Evening mode: Focus on lighter, creative tasks")
            recommendations.append("Wind down with a puzzle-style challenge")
        
        focus_score = context.get('focus_score')
        if focus_score and focus_score < 0.5:
            recommendations.append("Low focus detected - try a shorter, more engaging challenge")
        
        return recommendations


def get_context_adapter() -> ContextAwareAdapter:
    """Get singleton ContextAwareAdapter instance."""
    global _context_adapter
    if '_context_adapter' not in globals():
        _context_adapter = ContextAwareAdapter()
    return _context_adapter

