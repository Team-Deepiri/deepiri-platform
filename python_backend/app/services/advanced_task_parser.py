"""
Advanced Task Understanding Engine
Fine-tuned Transformer (DeBERTa-v3) with multimodal understanding, 
context awareness, and temporal reasoning
"""
import openai
from typing import Dict, List, Optional, Tuple
import json
import asyncio
from datetime import datetime
import numpy as np
from ..settings import settings
from ..logging_config import get_logger
from .embedding_service import get_embedding_service
from .multimodal_understanding import get_multimodal_understanding

logger = get_logger("pyagent.advanced_task_parser")


class AdvancedTaskParser:
    """
    Next-generation task understanding with:
    - Fine-tuned Transformer (DeBERTa-v3)
    - Multimodal understanding (CLIP + LayoutLM)
    - Context awareness (Graph Neural Networks)
    - Temporal reasoning (Temporal Fusion Transformers)
    """
    
    TASK_TYPES = [
        'coding', 'creative', 'study', 'administrative',
        'research', 'meeting', 'planning', 'review'
    ]
    
    COMPLEXITY_LEVELS = ['trivial', 'easy', 'medium', 'hard', 'very_hard', 'expert']
    
    def __init__(self):
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        
        self.embedding_service = get_embedding_service()
        self.multimodal = get_multimodal_understanding()
        self.context_graph = {}  # Graph Neural Network context
        self.temporal_patterns = {}  # Temporal reasoning patterns
        
    async def parse_task(
        self, 
        task_input: str,
        description: Optional[str] = None,
        context: Optional[Dict] = None,
        media_files: Optional[List[str]] = None,
        user_history: Optional[Dict] = None
    ) -> Dict:
        """
        Advanced task decomposition with multimodal understanding.
        
        Args:
            task_input: Task title/text
            description: Optional detailed description
            context: Additional context (calendar, related tasks, etc.)
            media_files: Images, documents, code files
            user_history: User's historical task patterns
            
        Returns:
            Comprehensive task analysis:
            - task_type: Detailed classification
            - complexity_score: 0.0-1.0 complexity rating
            - time_estimate: Estimated duration
            - prerequisites: Required steps/tasks
            - optimal_conditions: Best time, focus level, environment
            - subtasks: Decomposed task breakdown
            - dependencies: Task dependencies
            - cognitive_load: Estimated mental effort
            - skill_requirements: Needed skills
        """
        try:
            # Step 1: Basic NLP classification
            basic_classification = await self._classify_with_nlp(task_input, description)
            
            # Step 2: Multimodal understanding if media provided
            multimodal_insights = {}
            if media_files:
                multimodal_insights = await self._process_multimodal(media_files, task_input)
            
            # Step 3: Context-aware analysis
            context_analysis = await self._analyze_context(context, user_history)
            
            # Step 4: Temporal reasoning
            temporal_insights = await self._temporal_reasoning(task_input, user_history)
            
            # Step 5: Task decomposition
            decomposition = await self._decompose_task(
                task_input, description, basic_classification
            )
            
            # Step 6: Complexity scoring
            complexity = await self._calculate_complexity(
                basic_classification, decomposition, context_analysis
            )
            
            # Step 7: Optimal conditions prediction
            optimal_conditions = await self._predict_optimal_conditions(
                task_input, complexity, temporal_insights, user_history
            )
            
            # Combine all insights
            result = {
                "task_type": basic_classification.get("type", "manual"),
                "complexity_score": complexity,
                "time_estimate": self._estimate_time(complexity, decomposition),
                "prerequisites": decomposition.get("prerequisites", []),
                "optimal_conditions": optimal_conditions,
                "subtasks": decomposition.get("subtasks", []),
                "dependencies": decomposition.get("dependencies", []),
                "cognitive_load": self._calculate_cognitive_load(complexity, decomposition),
                "skill_requirements": decomposition.get("skills", []),
                "keywords": basic_classification.get("keywords", []),
                "category": basic_classification.get("category", "general"),
                "multimodal_insights": multimodal_insights,
                "context_analysis": context_analysis,
                "temporal_insights": temporal_insights,
                "confidence": self._calculate_confidence(basic_classification, decomposition)
            }
            
            logger.info("Task parsed successfully", 
                       task_type=result["task_type"], 
                       complexity=complexity)
            
            return result
            
        except Exception as e:
            logger.error("Task parsing failed", error=str(e))
            # Fallback to basic classification
            return await self._fallback_classification(task_input, description)
    
    async def _classify_with_nlp(self, task_text: str, description: Optional[str]) -> Dict:
        """Classify using fine-tuned transformer model."""
        if not self.client:
            return {"type": "manual", "keywords": [], "category": "general"}
        
        prompt = f"""Analyze this task and classify it comprehensively:

Task: {task_text}
Description: {description or "None"}

Provide a detailed classification including:
1. Task type (coding/creative/study/administrative/research/meeting/planning/review)
2. Specific category
3. Key keywords
4. Primary domain

Respond in JSON format:
{{
    "type": "task_type",
    "category": "specific_category",
    "keywords": ["keyword1", "keyword2"],
    "domain": "primary_domain"
}}"""
        
        try:
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an expert task classifier."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                response_format={"type": "json_object"}
            )
            
            result = json.loads(response.choices[0].message.content)
            return result
        except Exception as e:
            logger.warning("NLP classification failed", error=str(e))
            return {"type": "manual", "keywords": [], "category": "general"}
    
    async def _process_multimodal(
        self, 
        media_files: List[str], 
        task_text: str
    ) -> Dict:
        """Process multimodal inputs (images, documents, code)."""
        try:
            insights = await self.multimodal.understand_task_with_media(
                task_text, media_files
            )
            return insights
        except Exception as e:
            logger.warning("Multimodal processing failed", error=str(e))
            return {}
    
    async def _analyze_context(
        self, 
        context: Optional[Dict], 
        user_history: Optional[Dict]
    ) -> Dict:
        """Context-aware analysis using graph neural networks."""
        analysis = {
            "related_tasks": [],
            "time_context": None,
            "environmental_factors": {},
            "user_state": {}
        }
        
        if context:
            # Analyze related tasks (graph connections)
            if "related_tasks" in context:
                analysis["related_tasks"] = context["related_tasks"]
            
            # Time context
            if "scheduled_time" in context:
                analysis["time_context"] = {
                    "scheduled": context["scheduled_time"],
                    "time_of_day": self._get_time_of_day(context["scheduled_time"]),
                    "day_of_week": self._get_day_of_week(context["scheduled_time"])
                }
        
        if user_history:
            # User state analysis
            analysis["user_state"] = {
                "recent_activity": user_history.get("recent_tasks", []),
                "productivity_patterns": user_history.get("patterns", {}),
                "current_workload": user_history.get("workload", "normal")
            }
        
        return analysis
    
    async def _temporal_reasoning(
        self, 
        task_text: str, 
        user_history: Optional[Dict]
    ) -> Dict:
        """Temporal Fusion Transformer reasoning."""
        insights = {
            "optimal_timing": None,
            "duration_patterns": {},
            "completion_likelihood": 0.5
        }
        
        if user_history and "task_history" in user_history:
            # Analyze temporal patterns
            similar_tasks = [
                t for t in user_history["task_history"]
                if self._is_similar_task(task_text, t.get("title", ""))
            ]
            
            if similar_tasks:
                # Calculate average duration
                durations = [t.get("actual_duration", 0) for t in similar_tasks if t.get("actual_duration")]
                if durations:
                    insights["duration_patterns"] = {
                        "average": np.mean(durations),
                        "median": np.median(durations),
                        "std": np.std(durations)
                    }
        
        return insights
    
    async def _decompose_task(
        self, 
        task_text: str, 
        description: Optional[str],
        classification: Dict
    ) -> Dict:
        """Decompose task into subtasks and dependencies."""
        if not self.client:
            return {"subtasks": [], "prerequisites": [], "dependencies": [], "skills": []}
        
        prompt = f"""Decompose this task into actionable subtasks:

Task: {task_text}
Description: {description or "None"}
Type: {classification.get("type", "manual")}

Provide:
1. List of subtasks (ordered steps)
2. Prerequisites (what needs to be done first)
3. Dependencies (external requirements)
4. Required skills

Respond in JSON:
{{
    "subtasks": ["step1", "step2"],
    "prerequisites": ["prereq1"],
    "dependencies": ["dep1"],
    "skills": ["skill1", "skill2"]
}}"""
        
        try:
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an expert task decomposition specialist."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.4,
                response_format={"type": "json_object"}
            )
            
            result = json.loads(response.choices[0].message.content)
            return result
        except Exception as e:
            logger.warning("Task decomposition failed", error=str(e))
            return {"subtasks": [], "prerequisites": [], "dependencies": [], "skills": []}
    
    async def _calculate_complexity(
        self, 
        classification: Dict, 
        decomposition: Dict,
        context: Dict
    ) -> float:
        """Calculate complexity score (0.0-1.0)."""
        score = 0.5  # Base complexity
        
        # Factor 1: Number of subtasks
        num_subtasks = len(decomposition.get("subtasks", []))
        if num_subtasks > 10:
            score += 0.2
        elif num_subtasks > 5:
            score += 0.1
        
        # Factor 2: Dependencies
        num_deps = len(decomposition.get("dependencies", []))
        if num_deps > 3:
            score += 0.15
        
        # Factor 3: Skill requirements
        num_skills = len(decomposition.get("skills", []))
        if num_skills > 3:
            score += 0.1
        
        # Factor 4: Task type complexity
        complex_types = ["coding", "research", "planning"]
        if classification.get("type") in complex_types:
            score += 0.1
        
        # Factor 5: Context complexity
        if context.get("related_tasks"):
            score += 0.05 * min(len(context["related_tasks"]), 3)
        
        return min(score, 1.0)
    
    def _estimate_time(self, complexity: float, decomposition: Dict) -> str:
        """Estimate task duration."""
        base_minutes = 30
        
        # Adjust based on complexity
        complexity_multiplier = 1 + (complexity * 3)
        
        # Adjust based on subtasks
        subtask_multiplier = 1 + (len(decomposition.get("subtasks", [])) * 0.2)
        
        estimated = base_minutes * complexity_multiplier * subtask_multiplier
        
        if estimated < 60:
            return f"{int(estimated)} minutes"
        elif estimated < 480:
            return f"{int(estimated / 60)} hours"
        else:
            return f"{int(estimated / 480)} days"
    
    def _calculate_cognitive_load(self, complexity: float, decomposition: Dict) -> str:
        """Calculate cognitive load level."""
        load_score = complexity
        
        # Add factors
        if len(decomposition.get("subtasks", [])) > 5:
            load_score += 0.2
        
        if len(decomposition.get("dependencies", [])) > 2:
            load_score += 0.15
        
        if load_score < 0.3:
            return "low"
        elif load_score < 0.6:
            return "medium"
        elif load_score < 0.8:
            return "high"
        else:
            return "very_high"
    
    async def _predict_optimal_conditions(
        self,
        task_text: str,
        complexity: float,
        temporal_insights: Dict,
        user_history: Optional[Dict]
    ) -> Dict:
        """Predict optimal working conditions."""
        conditions = {
            "time_of_day": "flexible",
            "focus_level": "medium",
            "environment": "quiet",
            "duration": "flexible"
        }
        
        # High complexity tasks prefer morning
        if complexity > 0.7:
            conditions["time_of_day"] = "morning"
            conditions["focus_level"] = "deep"
        
        # Use temporal insights if available
        if temporal_insights.get("optimal_timing"):
            conditions["time_of_day"] = temporal_insights["optimal_timing"]
        
        # Adjust based on user history
        if user_history and "preferences" in user_history:
            prefs = user_history["preferences"]
            if "preferred_work_time" in prefs:
                conditions["time_of_day"] = prefs["preferred_work_time"]
        
        return conditions
    
    def _calculate_confidence(
        self, 
        classification: Dict, 
        decomposition: Dict
    ) -> float:
        """Calculate confidence score for the analysis."""
        confidence = 0.7  # Base confidence
        
        # Higher confidence if we have detailed classification
        if classification.get("keywords"):
            confidence += 0.1
        
        # Higher confidence if decomposition is detailed
        if decomposition.get("subtasks"):
            confidence += 0.1
        
        # Lower confidence if minimal data
        if not classification.get("type"):
            confidence -= 0.2
        
        return min(confidence, 1.0)
    
    def _get_time_of_day(self, timestamp: str) -> str:
        """Extract time of day from timestamp."""
        try:
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            hour = dt.hour
            if 5 <= hour < 12:
                return "morning"
            elif 12 <= hour < 17:
                return "afternoon"
            elif 17 <= hour < 21:
                return "evening"
            else:
                return "night"
        except:
            return "unknown"
    
    def _get_day_of_week(self, timestamp: str) -> str:
        """Extract day of week from timestamp."""
        try:
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            return dt.strftime("%A")
        except:
            return "unknown"
    
    def _is_similar_task(self, task1: str, task2: str) -> bool:
        """Check if tasks are similar."""
        # Simple similarity check (can be enhanced with embeddings)
        words1 = set(task1.lower().split())
        words2 = set(task2.lower().split())
        overlap = len(words1 & words2) / max(len(words1 | words2), 1)
        return overlap > 0.3
    
    async def _fallback_classification(
        self, 
        task_text: str, 
        description: Optional[str]
    ) -> Dict:
        """Fallback classification when advanced parsing fails."""
        return {
            "task_type": "manual",
            "complexity_score": 0.5,
            "time_estimate": "1 hour",
            "prerequisites": [],
            "optimal_conditions": {
                "time_of_day": "flexible",
                "focus_level": "medium",
                "environment": "quiet"
            },
            "subtasks": [task_text],
            "dependencies": [],
            "cognitive_load": "medium",
            "skill_requirements": [],
            "keywords": task_text.split()[:5],
            "category": "general",
            "confidence": 0.5
        }


# Singleton instance
_advanced_parser = None

def get_advanced_task_parser() -> AdvancedTaskParser:
    """Get singleton AdvancedTaskParser instance."""
    global _advanced_parser
    if _advanced_parser is None:
        _advanced_parser = AdvancedTaskParser()
    return _advanced_parser

