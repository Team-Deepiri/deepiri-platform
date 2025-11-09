"""
Session Analysis Service
Analyze user sessions and generate insights
"""
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import json
from ..logging_config import get_logger

logger = get_logger("service.session")


class SessionAnalyzer:
    """Analyze user sessions for insights."""
    
    def analyze_session(self, session_data: Dict) -> Dict:
        """Analyze session and generate insights."""
        events = session_data.get('events', [])
        
        keystrokes = [e for e in events if e.get('type') == 'keystroke']
        file_changes = [e for e in events if e.get('type') == 'file_change']
        challenges = [e for e in events if e.get('type') == 'challenge_complete']
        
        insights = {
            'productivity_score': self._calculate_productivity(events),
            'focus_periods': self._identify_focus_periods(events),
            'challenge_performance': self._analyze_challenges(challenges),
            'code_quality_metrics': self._analyze_code_quality(file_changes),
            'recommendations': self._generate_recommendations(events)
        }
        
        return insights
    
    def _calculate_productivity(self, events: List[Dict]) -> float:
        """Calculate productivity score."""
        if not events:
            return 0.0
        
        keystrokes = len([e for e in events if e.get('type') == 'keystroke'])
        challenges_completed = len([e for e in events if e.get('type') == 'challenge_complete' and e.get('success', False)])
        files_saved = len([e for e in events if e.get('type') == 'file_change' and e.get('change_type') == 'save'])
        
        score = (keystrokes * 0.1 + challenges_completed * 50 + files_saved * 20) / 100.0
        return min(1.0, max(0.0, score))
    
    def _identify_focus_periods(self, events: List[Dict]) -> List[Dict]:
        """Identify periods of high focus."""
        focus_periods = []
        current_period_start = None
        keystroke_count = 0
        
        for event in events:
            if event.get('type') == 'keystroke':
                if current_period_start is None:
                    current_period_start = event.get('timestamp')
                keystroke_count += 1
                
                if keystroke_count > 100:
                    focus_periods.append({
                        'start': current_period_start,
                        'duration': 15,
                        'intensity': 'high'
                    })
                    current_period_start = None
                    keystroke_count = 0
            else:
                if keystroke_count > 0:
                    keystroke_count = 0
        
        return focus_periods
    
    def _analyze_challenges(self, challenges: List[Dict]) -> Dict:
        """Analyze challenge performance."""
        if not challenges:
            return {'completed': 0, 'success_rate': 0.0, 'avg_time': 0}
        
        completed = len([c for c in challenges if c.get('success', False)])
        success_rate = completed / len(challenges) if challenges else 0.0
        
        times = [c.get('completion_time', 0) for c in challenges if c.get('completion_time')]
        avg_time = sum(times) / len(times) if times else 0
        
        return {
            'completed': completed,
            'total': len(challenges),
            'success_rate': success_rate,
            'avg_time': avg_time
        }
    
    def _analyze_code_quality(self, file_changes: List[Dict]) -> Dict:
        """Analyze code quality metrics."""
        saves = [f for f in file_changes if f.get('change_type') == 'save']
        
        return {
            'files_saved': len(saves),
            'total_changes': len(file_changes),
            'edit_frequency': len(file_changes) / 60.0 if file_changes else 0
        }
    
    def _generate_recommendations(self, events: List[Dict]) -> List[str]:
        """Generate productivity recommendations."""
        recommendations = []
        
        keystrokes = len([e for e in events if e.get('type') == 'keystroke'])
        challenges = len([e for e in events if e.get('type') == 'challenge_complete'])
        
        if keystrokes > 1000 and challenges == 0:
            recommendations.append("Consider taking a break and starting a challenge")
        
        if challenges > 3:
            recommendations.append("Great work! You've completed multiple challenges today")
        
        focus_periods = self._identify_focus_periods(events)
        if len(focus_periods) < 2:
            recommendations.append("Try to maintain longer focus periods for better productivity")
        
        return recommendations


_session_analyzer = None

def get_session_analyzer() -> SessionAnalyzer:
    """Get singleton session analyzer."""
    global _session_analyzer
    if _session_analyzer is None:
        _session_analyzer = SessionAnalyzer()
    return _session_analyzer

