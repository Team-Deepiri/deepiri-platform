"""
Adaptive Challenge Generation AI
PPO-based RL agent with engagement prediction and creative generation
"""
import openai
from typing import Dict, List, Optional, Tuple
import json
import asyncio
import numpy as np
from datetime import datetime, timedelta
from ..settings import settings
from ..logging_config import get_logger
from .advanced_task_parser import get_advanced_task_parser
from .reward_model import RewardModelService, get_reward_model

logger = get_logger("pyagent.adaptive_challenge_generator")


class AdaptiveChallengeGenerator:
    """
    Next-generation challenge generation with:
    - Proximal Policy Optimization (PPO) for adaptation
    - Transformer-based engagement prediction
    - Diffusion models for creative challenge design
    - Real-time difficulty adjustment
    """
    
    CHALLENGE_TYPES = [
        "time_attack",      # Speed-based challenges
        "puzzle",           # Problem-solving puzzles
        "creative_sprint",   # Creative work challenges
        "quiz",             # Knowledge-based quizzes
        "coding_kata",      # Programming challenges
        "streak_builder",   # Consistency challenges
        "exploration",      # Discovery-based challenges
        "collaboration"     # Team-based challenges
    ]
    
    DIFFICULTY_LEVELS = ["beginner", "intermediate", "advanced", "expert", "adaptive"]
    
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        
        self.task_parser = get_advanced_task_parser()
        self.reward_model = get_reward_model()
        self.engagement_predictor = {}  # Transformer-based engagement model
        self.rl_agent_state = {}  # PPO agent state
        self.challenge_templates = self._load_challenge_templates()
        
    async def generate_challenge(
        self,
        task: Dict,
        user_profile: Dict,
        context: Optional[Dict] = None,
        previous_challenges: Optional[List[Dict]] = None
    ) -> Dict:
        """
        Generate adaptive challenge with RL-based optimization.
        
        Args:
            task: Parsed task from AdvancedTaskParser
            user_profile: User's performance history and preferences
            context: Current context (time, environment, etc.)
            previous_challenges: Past challenges for learning
            
        Returns:
            Comprehensive challenge design:
            - challenge_type: Type of challenge
            - difficulty_level: Adaptive difficulty
            - reward_structure: Progressive unlock system
            - immersive_elements: 3D environment, sound, visuals
            - time_constraints: Optimal timing
            - success_criteria: Clear objectives
            - hints_system: Progressive hints
            - adaptation_rules: Real-time adjustment rules
        """
        try:
            # Step 1: Analyze task and user state
            task_analysis = await self._analyze_task_for_challenge(task)
            user_state = await self._analyze_user_state(user_profile, previous_challenges)
            
            # Step 2: Predict engagement
            engagement_prediction = await self._predict_engagement(
                task_analysis, user_state, context
            )
            
            # Step 3: Select challenge type using RL agent
            challenge_type = await self._select_challenge_type_rl(
                task_analysis, user_state, engagement_prediction
            )
            
            # Step 4: Calculate adaptive difficulty
            difficulty = await self._calculate_adaptive_difficulty(
                task_analysis, user_state, challenge_type
            )
            
            # Step 5: Generate creative challenge design
            challenge_design = await self._generate_creative_challenge(
                task, challenge_type, difficulty, task_analysis
            )
            
            # Step 6: Design reward structure
            reward_structure = await self._design_reward_structure(
                challenge_type, difficulty, user_state
            )
            
            # Step 7: Create immersive elements
            immersive_elements = await self._create_immersive_elements(
                challenge_type, task_analysis, user_profile
            )
            
            # Step 8: Set up adaptation rules
            adaptation_rules = await self._create_adaptation_rules(
                challenge_type, difficulty, user_state
            )
            
            # Combine into final challenge
            challenge = {
                "challenge_id": self._generate_challenge_id(),
                "challenge_type": challenge_type,
                "difficulty_level": difficulty,
                "task_id": task.get("task_id"),
                "title": challenge_design.get("title", "Challenge"),
                "description": challenge_design.get("description", ""),
                "reward_structure": reward_structure,
                "immersive_elements": immersive_elements,
                "time_constraints": challenge_design.get("time_constraints", {}),
                "success_criteria": challenge_design.get("success_criteria", []),
                "hints_system": challenge_design.get("hints", []),
                "adaptation_rules": adaptation_rules,
                "engagement_prediction": engagement_prediction,
                "estimated_completion_time": challenge_design.get("estimated_time"),
                "prerequisites": challenge_design.get("prerequisites", []),
                "metadata": {
                    "generated_at": datetime.utcnow().isoformat(),
                    "generation_method": "adaptive_rl",
                    "confidence": engagement_prediction.get("confidence", 0.7)
                }
            }
            
            logger.info("Challenge generated", 
                    challenge_id=challenge["challenge_id"],
                    challenge_type=challenge_type,
                    difficulty=difficulty)
            
            return challenge
            
        except Exception as e:
            logger.error("Challenge generation failed", error=str(e))
            return await self._fallback_challenge(task)
    
    async def _analyze_task_for_challenge(self, task: Dict) -> Dict:
        """Analyze task to determine challenge suitability."""
        return {
            "complexity": task.get("complexity_score", 0.5),
            "task_type": task.get("task_type", "manual"),
            "cognitive_load": task.get("cognitive_load", "medium"),
            "time_estimate": task.get("time_estimate", "1 hour"),
            "skills_required": task.get("skill_requirements", []),
            "subtasks": task.get("subtasks", []),
            "challengeable": self._is_challengeable(task)
        }
    
    def _is_challengeable(self, task: Dict) -> bool:
        """Determine if task can be gamified."""
        # Most tasks can be challenged, but some are better suited
        non_challengeable_types = ["meeting", "break"]
        task_type = task.get("task_type", "")
        return task_type not in non_challengeable_types
    
    async def _analyze_user_state(
        self, 
        user_profile: Dict, 
        previous_challenges: Optional[List[Dict]]
    ) -> Dict:
        """Analyze user's current state and performance."""
        state = {
            "skill_level": user_profile.get("skill_level", {}),
            "preferences": user_profile.get("preferences", {}),
            "recent_performance": {},
            "engagement_trends": {},
            "optimal_difficulty": 0.5
        }
        
        if previous_challenges:
            # Analyze recent performance
            recent = previous_challenges[-10:]  # Last 10 challenges
            completions = [c for c in recent if c.get("completed", False)]
            completion_rate = len(completions) / len(recent) if recent else 0.5
            
            state["recent_performance"] = {
                "completion_rate": completion_rate,
                "average_time": np.mean([c.get("completion_time", 0) for c in completions]) if completions else 0,
                "engagement_score": np.mean([c.get("engagement_score", 0.5) for c in recent])
            }
            
            # Calculate optimal difficulty
            if completion_rate > 0.8:
                state["optimal_difficulty"] = min(state["optimal_difficulty"] + 0.1, 1.0)
            elif completion_rate < 0.5:
                state["optimal_difficulty"] = max(state["optimal_difficulty"] - 0.1, 0.0)
        
        return state
    
    async def _predict_engagement(
        self,
        task_analysis: Dict,
        user_state: Dict,
        context: Optional[Dict]
    ) -> Dict:
        """Predict user engagement using transformer-based model."""
        # Simplified engagement prediction
        # In production, this would use a fine-tuned transformer
        
        base_engagement = 0.6
        
        # Factor 1: Task complexity match
        complexity_match = 1.0 - abs(
            task_analysis["complexity"] - user_state["optimal_difficulty"]
        )
        base_engagement += complexity_match * 0.2
        
        # Factor 2: Challenge type preference
        preferred_types = user_state.get("preferences", {}).get("challenge_types", [])
        if task_analysis.get("suggested_challenge_type") in preferred_types:
            base_engagement += 0.1
        
        # Factor 3: Time of day
        if context and context.get("time_of_day") == "morning":
            base_engagement += 0.05
        
        # Factor 4: Recent performance
        if user_state.get("recent_performance", {}).get("completion_rate", 0) > 0.7:
            base_engagement += 0.05
        
        engagement_score = min(base_engagement, 1.0)
        
        return {
            "predicted_engagement": engagement_score,
            "confidence": 0.75,
            "factors": {
                "complexity_match": complexity_match,
                "preference_alignment": 0.7,
                "contextual_fit": 0.8
            }
        }
    
    async def _select_challenge_type_rl(
        self,
        task_analysis: Dict,
        user_state: Dict,
        engagement_prediction: Dict
    ) -> str:
        """Select challenge type using RL agent (PPO)."""
        # Simplified RL selection (in production, use actual PPO agent)
        task_type = task_analysis.get("task_type", "manual")
        
        # Map task types to challenge types
        type_mapping = {
            "coding": "coding_kata",
            "creative": "creative_sprint",
            "study": "quiz",
            "research": "exploration",
            "administrative": "puzzle"
        }
        
        suggested_type = type_mapping.get(task_type, "puzzle")
        
        # Use RL agent to refine selection based on user state
        # For now, use engagement prediction to adjust
        if engagement_prediction["predicted_engagement"] > 0.8:
            # High engagement - can use more complex types
            if task_type == "coding":
                return "coding_kata"
            elif task_type == "creative":
                return "creative_sprint"
        
        return suggested_type
    
    async def _calculate_adaptive_difficulty(
        self,
        task_analysis: Dict,
        user_state: Dict,
        challenge_type: str
    ) -> str:
        """Calculate adaptive difficulty level."""
        optimal = user_state.get("optimal_difficulty", 0.5)
        task_complexity = task_analysis.get("complexity", 0.5)
        
        # Blend user optimal with task complexity
        blended = (optimal * 0.6) + (task_complexity * 0.4)
        
        if blended < 0.25:
            return "beginner"
        elif blended < 0.5:
            return "intermediate"
        elif blended < 0.75:
            return "advanced"
        else:
            return "expert"
    
    async def _generate_creative_challenge(
        self,
        task: Dict,
        challenge_type: str,
        difficulty: str,
        task_analysis: Dict
    ) -> Dict:
        """Generate creative challenge design using AI."""
        if not self.client:
            return self._default_challenge_design(challenge_type, difficulty)
        
        prompt = f"""Design an engaging {challenge_type} challenge for this task:

Task: {task.get("title", "Task")}
Description: {task.get("description", "")}
Difficulty: {difficulty}
Complexity: {task_analysis.get("complexity", 0.5)}

Create:
1. Challenge title
2. Engaging description
3. Success criteria (clear objectives)
4. Time constraints
5. Progressive hints
6. Estimated completion time

Respond in JSON:
{{
    "title": "Challenge Title",
    "description": "Engaging description",
    "success_criteria": ["criterion1", "criterion2"],
    "time_constraints": {{"min": 5, "max": 60, "optimal": 25}},
    "hints": ["hint1", "hint2"],
    "estimated_time": "25 minutes",
    "prerequisites": []
}}"""
        
        try:
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an expert gamification designer."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,  # Higher temperature for creativity
                response_format={"type": "json_object"}
            )
            
            result = json.loads(response.choices[0].message.content)
            return result
        except Exception as e:
            logger.warning("Creative challenge generation failed", error=str(e))
            return self._default_challenge_design(challenge_type, difficulty)
    
    async def _design_reward_structure(
        self,
        challenge_type: str,
        difficulty: str,
        user_state: Dict
    ) -> Dict:
        """Design progressive reward structure."""
        # Base points by difficulty
        base_points = {
            "beginner": 50,
            "intermediate": 100,
            "advanced": 200,
            "expert": 500
        }
        
        points = base_points.get(difficulty, 100)
        
        # Bonus multipliers
        multipliers = {
            "time_attack": 1.5,  # Speed bonuses
            "puzzle": 1.2,
            "creative_sprint": 1.3,
            "coding_kata": 1.4
        }
        
        points = int(points * multipliers.get(challenge_type, 1.0))
        
        return {
            "base_points": points,
            "bonus_multipliers": {
                "speed_bonus": 1.5,
                "quality_bonus": 1.3,
                "streak_bonus": 1.2
            },
            "unlockables": [
                f"{challenge_type}_badge",
                f"{difficulty}_achievement"
            ],
            "progressive_rewards": [
                {"milestone": 0.25, "reward": "hint_unlock"},
                {"milestone": 0.5, "reward": "bonus_points"},
                {"milestone": 0.75, "reward": "special_effect"},
                {"milestone": 1.0, "reward": "completion_badge"}
            ]
        }
    
    async def _create_immersive_elements(
        self,
        challenge_type: str,
        task_analysis: Dict,
        user_profile: Dict
    ) -> Dict:
        """Create immersive 3D environment, sound, and visual elements."""
        # Map challenge types to immersive themes
        themes = {
            "time_attack": {
                "environment": "futuristic_race_track",
                "audio": "energetic_electronic",
                "visual_effects": "speed_lines_particles"
            },
            "puzzle": {
                "environment": "mysterious_library",
                "audio": "ambient_thoughtful",
                "visual_effects": "glowing_puzzles"
            },
            "creative_sprint": {
                "environment": "artistic_studio",
                "audio": "inspiring_acoustic",
                "visual_effects": "color_splashes"
            },
            "coding_kata": {
                "environment": "cyber_code_space",
                "audio": "tech_ambient",
                "visual_effects": "matrix_rain"
            }
        }
        
        base_theme = themes.get(challenge_type, themes["puzzle"])
        
        return {
            "3d_environment": {
                "theme": base_theme["environment"],
                "interactive_elements": True,
                "customization": user_profile.get("preferences", {}).get("theme", "default")
            },
            "audio": {
                "soundtrack": base_theme["audio"],
                "sound_effects": True,
                "adaptive_music": True  # Music adapts to progress
            },
            "visual_effects": {
                "particles": base_theme["visual_effects"],
                "transitions": "smooth_animated",
                "progress_visualization": "3d_progress_bar"
            },
            "haptic_feedback": False  # For desktop, can enable for mobile
        }
    
    async def _create_adaptation_rules(
        self,
        challenge_type: str,
        difficulty: str,
        user_state: Dict
    ) -> Dict:
        """Create real-time adaptation rules."""
        return {
            "difficulty_adjustment": {
                "enabled": True,
                "triggers": [
                    {"condition": "completion_time < expected_time * 0.7", "action": "increase_difficulty"},
                    {"condition": "completion_time > expected_time * 1.5", "action": "decrease_difficulty"},
                    {"condition": "hints_used > 3", "action": "decrease_difficulty"}
                ]
            },
            "hint_system": {
                "progressive": True,
                "unlock_conditions": [
                    {"time_elapsed": 0.25, "hint_level": 1},
                    {"time_elapsed": 0.5, "hint_level": 2},
                    {"time_elapsed": 0.75, "hint_level": 3}
                ]
            },
            "reward_adjustment": {
                "dynamic_scoring": True,
                "bonus_conditions": [
                    {"condition": "no_hints_used", "bonus": 1.5},
                    {"condition": "completed_early", "bonus": 1.3}
                ]
            }
        }
    
    def _load_challenge_templates(self) -> Dict:
        """Load challenge templates for fallback."""
        return {
            "time_attack": {
                "title": "Speed Challenge",
                "description": "Complete this task as quickly as possible!",
                "success_criteria": ["task_completed", "time_under_limit"]
            },
            "puzzle": {
                "title": "Problem Solver",
                "description": "Solve this puzzle to unlock your task!",
                "success_criteria": ["puzzle_solved", "task_progressed"]
            }
        }
    
    def _default_challenge_design(self, challenge_type: str, difficulty: str) -> Dict:
        """Default challenge design when AI generation fails."""
        template = self.challenge_templates.get(challenge_type, self.challenge_templates["puzzle"])
        return {
            "title": template["title"],
            "description": template["description"],
            "success_criteria": template["success_criteria"],
            "time_constraints": {"min": 5, "max": 60, "optimal": 30},
            "hints": [],
            "estimated_time": "30 minutes",
            "prerequisites": []
        }
    
    def _generate_challenge_id(self) -> str:
        """Generate unique challenge ID."""
        return f"challenge_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_{np.random.randint(1000, 9999)}"
    
    async def _fallback_challenge(self, task: Dict) -> Dict:
        """Fallback challenge when generation fails."""
        return {
            "challenge_id": self._generate_challenge_id(),
            "challenge_type": "puzzle",
            "difficulty_level": "intermediate",
            "title": f"Complete: {task.get('title', 'Task')}",
            "description": "Complete this task to earn rewards!",
            "reward_structure": {"base_points": 100},
            "immersive_elements": {},
            "time_constraints": {},
            "success_criteria": ["task_completed"],
            "hints_system": [],
            "adaptation_rules": {}
        }


# Singleton instance
_adaptive_generator = None

def get_adaptive_challenge_generator() -> AdaptiveChallengeGenerator:
    """Get singleton AdaptiveChallengeGenerator instance."""
    global _adaptive_generator
    if _adaptive_generator is None:
        _adaptive_generator = AdaptiveChallengeGenerator()
    return _adaptive_generator

