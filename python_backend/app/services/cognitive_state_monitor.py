"""
Cognitive State Monitoring Service
Tracks user cognitive state in real-time
"""
import asyncio
from typing import Dict, Optional, List
from dataclasses import dataclass
from datetime import datetime, timedelta
from collections import deque
import numpy as np
from ..logging_config import get_logger

logger = get_logger("pyagent.cognitive_state")


@dataclass
class CognitiveState:
    """User cognitive state representation."""
    attention_level: float  # 0.0-1.0
    focus_state: str  # 'deep', 'moderate', 'distracted', 'fatigued'
    energy_level: float  # 0.0-1.0
    stress_level: float  # 0.0-1.0
    flow_state: bool
    timestamp: datetime


class CognitiveStateMonitor:
    """
    Monitors user cognitive state using:
    - Webcam-based attention tracking (optional)
    - Keystroke dynamics
    - Mouse movement patterns
    - Application usage context
    - Physiological signals (wearables)
    """
    
    def __init__(self):
        self.user_states = {}  # userId -> deque of CognitiveState
        self.keystroke_history = {}  # userId -> deque of keystroke data
        self.mouse_history = {}  # userId -> deque of mouse data
        self.app_context = {}  # userId -> current app context
        self.max_history = 100
        
    async def record_keystroke(
        self,
        userId: str,
        key: str,
        timestamp: float,
        file: Optional[str] = None,
        line: Optional[int] = None
    ):
        """Record keystroke for analysis."""
        if userId not in self.keystroke_history:
            self.keystroke_history[userId] = deque(maxlen=self.max_history)
        
        self.keystroke_history[userId].append({
            'key': key,
            'timestamp': timestamp,
            'file': file,
            'line': line
        })
        
        # Update cognitive state based on keystroke patterns
        await self._analyze_keystroke_patterns(userId)
    
    async def record_mouse_movement(
        self,
        userId: str,
        x: float,
        y: float,
        timestamp: float,
        movement_type: str = 'move'
    ):
        """Record mouse movement for analysis."""
        if userId not in self.mouse_history:
            self.mouse_history[userId] = deque(maxlen=self.max_history)
        
        self.mouse_history[userId].append({
            'x': x,
            'y': y,
            'timestamp': timestamp,
            'type': movement_type
        })
        
        # Update cognitive state based on mouse patterns
        await self._analyze_mouse_patterns(userId)
    
    async def update_app_context(
        self,
        userId: str,
        app_name: str,
        activity_type: str,
        metadata: Optional[Dict] = None
    ):
        """Update application usage context."""
        self.app_context[userId] = {
            'app_name': app_name,
            'activity_type': activity_type,
            'metadata': metadata or {},
            'timestamp': datetime.utcnow()
        }
        
        await self._analyze_app_context(userId)
    
    async def get_cognitive_state(self, userId: str) -> Optional[CognitiveState]:
        """Get current cognitive state for user."""
        if userId not in self.user_states or len(self.user_states[userId]) == 0:
            return self._default_state()
        
        return self.user_states[userId][-1]
    
    async def detect_flow_state(self, userId: str) -> bool:
        """Detect if user is in flow state."""
        state = await self.get_cognitive_state(userId)
        if not state:
            return False
        
        # Flow state indicators:
        # - High attention
        # - High energy
        # - Low stress
        # - Consistent activity
        return (
            state.attention_level > 0.8 and
            state.energy_level > 0.7 and
            state.stress_level < 0.3 and
            state.focus_state == 'deep'
        )
    
    async def predict_burnout_risk(self, userId: str) -> float:
        """Predict burnout risk (0.0-1.0)."""
        state = await self.get_cognitive_state(userId)
        if not state:
            return 0.0
        
        # Burnout indicators:
        # - Low energy
        # - High stress
        # - Declining attention
        # - Fatigue state
        
        risk_factors = []
        
        if state.energy_level < 0.3:
            risk_factors.append(0.3)
        
        if state.stress_level > 0.7:
            risk_factors.append(0.3)
        
        if state.focus_state == 'fatigued':
            risk_factors.append(0.2)
        
        # Check for declining trend
        if len(self.user_states.get(userId, [])) >= 5:
            recent_states = list(self.user_states[userId])[-5:]
            attention_trend = recent_states[-1].attention_level - recent_states[0].attention_level
            if attention_trend < -0.2:
                risk_factors.append(0.2)
        
        return min(sum(risk_factors), 1.0)
    
    async def suggest_interventions(self, userId: str) -> List[str]:
        """Suggest interventions based on cognitive state."""
        state = await this.get_cognitive_state(userId)
        if not state:
            return []
        
        interventions = []
        
        if state.energy_level < 0.3:
            interventions.append("Take a break - energy is low")
            interventions.append("Consider a short walk or stretch")
        
        if state.stress_level > 0.7:
            interventions.append("High stress detected - try deep breathing")
            interventions.append("Consider reducing task complexity")
        
        if state.focus_state == 'distracted':
            interventions.append("Focus is scattered - try pomodoro technique")
            interventions.append("Close distracting applications")
        
        if state.attention_level < 0.5:
            interventions.append("Attention is low - consider switching tasks")
        
        if await self.predict_burnout_risk(userId) > 0.7:
            interventions.append("Burnout risk detected - take extended break")
            interventions.append("Consider reducing workload")
        
        return interventions
    
    async def _analyze_keystroke_patterns(self, userId: str):
        """Analyze keystroke patterns to infer cognitive state."""
        if userId not in self.keystroke_history:
            return
        
        history = list(self.keystroke_history[userId])
        if len(history) < 10:
            return
        
        # Calculate typing speed
        recent = history[-10:]
        time_span = recent[-1]['timestamp'] - recent[0]['timestamp']
        keystrokes_per_second = len(recent) / max(time_span, 1)
        
        # Calculate consistency (variance in inter-keystroke intervals)
        intervals = []
        for i in range(1, len(recent)):
            intervals.append(recent[i]['timestamp'] - recent[i-1]['timestamp'])
        
        if intervals:
            consistency = 1.0 / (1.0 + np.std(intervals))
        else:
            consistency = 0.5
        
        # Update cognitive state
        state = await self.get_cognitive_state(userId)
        if state:
            # High speed + high consistency = good focus
            if keystrokes_per_second > 3 and consistency > 0.7:
                state.attention_level = min(state.attention_level + 0.1, 1.0)
                state.focus_state = 'deep'
            elif keystrokes_per_second < 1 or consistency < 0.3:
                state.attention_level = max(state.attention_level - 0.1, 0.0)
                state.focus_state = 'distracted'
    
    async def _analyze_mouse_patterns(self, userId: str):
        """Analyze mouse movement patterns."""
        if userId not in self.mouse_history:
            return
        
        history = list(self.mouse_history[userId])
        if len(history) < 10:
            return
        
        # Calculate movement speed and precision
        recent = history[-10:]
        total_distance = 0
        for i in range(1, len(recent)):
            dx = recent[i]['x'] - recent[i-1]['x']
            dy = recent[i]['y'] - recent[i-1]['y']
            total_distance += np.sqrt(dx*dx + dy*dy)
        
        time_span = recent[-1]['timestamp'] - recent[0]['timestamp']
        movement_speed = total_distance / max(time_span, 1)
        
        # High speed + erratic = distracted
        # Low speed + precise = focused
        state = await self.get_cognitive_state(userId)
        if state:
            if movement_speed > 1000:  # pixels per second
                state.attention_level = max(state.attention_level - 0.05, 0.0)
            elif movement_speed < 100:
                state.attention_level = min(state.attention_level + 0.05, 1.0)
    
    async def _analyze_app_context(self, userId: str):
        """Analyze application context."""
        if userId not in self.app_context:
            return
        
        context = self.app_context[userId]
        state = await self.get_cognitive_state(userId)
        
        if state:
            # Coding apps = higher focus potential
            if context['activity_type'] == 'coding':
                state.focus_state = 'deep'
                state.attention_level = min(state.attention_level + 0.1, 1.0)
            # Social apps = potential distraction
            elif context['activity_type'] == 'social':
                state.focus_state = 'distracted'
                state.attention_level = max(state.attention_level - 0.1, 0.0)
    
    def _default_state(self) -> CognitiveState:
        """Return default cognitive state."""
        return CognitiveState(
            attention_level=0.5,
            focus_state='moderate',
            energy_level=0.7,
            stress_level=0.3,
            flow_state=False,
            timestamp=datetime.utcnow()
        )
    
    async def _update_state(self, userId: str, state: CognitiveState):
        """Update user's cognitive state."""
        if userId not in self.user_states:
            self.user_states[userId] = deque(maxlen=self.max_history)
        
        self.user_states[userId].append(state)


# Singleton instance
_monitor = None

def get_cognitive_state_monitor() -> CognitiveStateMonitor:
    """Get singleton CognitiveStateMonitor instance."""
    global _monitor
    if _monitor is None:
        _monitor = CognitiveStateMonitor()
    return _monitor

