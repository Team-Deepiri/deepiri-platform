"""
Multi-Agent Collaboration System
Agent-based simulation for challenge design and coordination
"""
import asyncio
from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum
import openai
from ..settings import settings
from ..logging_config import get_logger

logger = get_logger("pyagent.multi_agent")


class AgentRole(Enum):
    TASK_DECOMPOSER = "task_decomposer"
    TIME_OPTIMIZER = "time_optimizer"
    CREATIVE_SPARKER = "creative_sparker"
    QUALITY_ASSURANCE = "quality_assurance"
    ENGAGEMENT_SPECIALIST = "engagement_specialist"


@dataclass
class AgentMessage:
    from_agent: str
    to_agent: Optional[str]  # None for broadcast
    content: str
    message_type: str
    timestamp: float


class Agent:
    """Base agent class."""
    
    def __init__(self, name: str, role: AgentRole, system_prompt: str):
        self.name = name
        self.role = role
        self.system_prompt = system_prompt
        self.memory = []
        self.client = None
        if settings.OPENAI_API_KEY:
            self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        """Process task and return result."""
        raise NotImplementedError
    
    async def communicate(self, message: AgentMessage) -> str:
        """Process incoming message."""
        self.memory.append(message)
        return f"{self.name} received: {message.content}"
    
    async def _call_llm(self, prompt: str) -> str:
        """Call LLM for agent reasoning."""
        if not self.client:
            return f"[{self.name}] Processed: {prompt[:50]}..."
        
        try:
            response = self.client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {"role": "system", "content": self.system_prompt},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error("LLM call failed", agent=self.name, error=str(e))
            return f"[{self.name}] Error processing"


class TaskDecomposerAgent(Agent):
    """Agent specialized in task decomposition."""
    
    def __init__(self):
        super().__init__(
            "TaskDecomposer",
            AgentRole.TASK_DECOMPOSER,
            "You are an expert at breaking down complex tasks into manageable subtasks."
        )
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        prompt = f"Decompose this task: {task.get('title', '')}\nDescription: {task.get('description', '')}"
        result = await self._call_llm(prompt)
        
        return {
            "agent": self.name,
            "subtasks": self._extract_subtasks(result),
            "recommendations": result
        }
    
    def _extract_subtasks(self, llm_response: str) -> List[str]:
        # Simple extraction (would be more sophisticated)
        lines = llm_response.split('\n')
        return [line.strip('- ').strip() for line in lines if line.strip().startswith('-')][:10]


class TimeOptimizerAgent(Agent):
    """Agent specialized in time optimization."""
    
    def __init__(self):
        super().__init__(
            "TimeOptimizer",
            AgentRole.TIME_OPTIMIZER,
            "You are an expert at optimizing schedules and time allocation."
        )
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        prompt = f"Optimize timing for task: {task.get('title', '')}\nCurrent context: {context}"
        result = await self._call_llm(prompt)
        
        return {
            "agent": self.name,
            "optimal_timing": self._extract_timing(result),
            "recommendations": result
        }
    
    def _extract_timing(self, llm_response: str) -> Dict:
        return {
            "estimated_duration": "30 minutes",
            "best_time_of_day": "morning",
            "break_suggestions": []
        }


class CreativeSparkerAgent(Agent):
    """Agent specialized in creative ideas."""
    
    def __init__(self):
        super().__init__(
            "CreativeSparker",
            AgentRole.CREATIVE_SPARKER,
            "You are a creative specialist who generates innovative ideas and approaches."
        )
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        prompt = f"Generate creative approaches for: {task.get('title', '')}"
        result = await self._call_llm(prompt)
        
        return {
            "agent": self.name,
            "creative_ideas": self._extract_ideas(result),
            "recommendations": result
        }
    
    def _extract_ideas(self, llm_response: str) -> List[str]:
        lines = llm_response.split('\n')
        return [line.strip() for line in lines if line.strip()][:5]


class QualityAssuranceAgent(Agent):
    """Agent specialized in quality assurance."""
    
    def __init__(self):
        super().__init__(
            "QualityAssurance",
            AgentRole.QUALITY_ASSURANCE,
            "You are a quality assurance specialist who reviews and validates solutions."
        )
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        prompt = f"Review and validate this task solution: {task}"
        result = await self._call_llm(prompt)
        
        return {
            "agent": self.name,
            "quality_score": self._extract_score(result),
            "issues": self._extract_issues(result),
            "recommendations": result
        }
    
    def _extract_score(self, llm_response: str) -> float:
        # Simple extraction
        if "excellent" in llm_response.lower():
            return 0.9
        elif "good" in llm_response.lower():
            return 0.7
        else:
            return 0.5
    
    def _extract_issues(self, llm_response: str) -> List[str]:
        return []


class EngagementSpecialistAgent(Agent):
    """Agent specialized in engagement optimization."""
    
    def __init__(self):
        super().__init__(
            "EngagementSpecialist",
            AgentRole.ENGAGEMENT_SPECIALIST,
            "You are an engagement specialist who optimizes user motivation and engagement."
        )
    
    async def process(self, task: Dict, context: Dict) -> Dict:
        prompt = f"Optimize engagement for task: {task.get('title', '')}"
        result = await self._call_llm(prompt)
        
        return {
            "agent": self.name,
            "engagement_strategies": self._extract_strategies(result),
            "predicted_engagement": 0.8,
            "recommendations": result
        }
    
    def _extract_strategies(self, llm_response: str) -> List[str]:
        lines = llm_response.split('\n')
        return [line.strip() for line in lines if line.strip()][:5]


class MultiAgentCoordinator:
    """
    Coordinates multiple AI agents for collaborative problem-solving.
    """
    
    def __init__(self):
        self.agents = {
            AgentRole.TASK_DECOMPOSER: TaskDecomposerAgent(),
            AgentRole.TIME_OPTIMIZER: TimeOptimizerAgent(),
            AgentRole.CREATIVE_SPARKER: CreativeSparkerAgent(),
            AgentRole.QUALITY_ASSURANCE: QualityAssuranceAgent(),
            AgentRole.ENGAGEMENT_SPECIALIST: EngagementSpecialistAgent()
        }
        self.message_queue = asyncio.Queue()
        self.consensus_threshold = 0.7
    
    async def collaborate_on_task(self, task: Dict, context: Dict) -> Dict:
        """
        Coordinate agents to collaboratively solve task.
        
        Returns:
            Consensus result from all agents
        """
        try:
            # Step 1: All agents process task in parallel
            agent_results = await asyncio.gather(*[
                agent.process(task, context)
                for agent in self.agents.values()
            ])
            
            # Step 2: Agents communicate and refine
            refined_results = await self._agent_communication(agent_results, task, context)
            
            # Step 3: Reach consensus
            consensus = await self._reach_consensus(refined_results, task)
            
            logger.info("Multi-agent collaboration completed", 
                       task_id=task.get('id'),
                       agents=len(self.agents),
                       consensus_score=consensus.get('consensus_score', 0))
            
            return consensus
            
        except Exception as e:
            logger.error("Multi-agent collaboration failed", error=str(e))
            return self._fallback_result(task)
    
    async def _agent_communication(
        self,
        initial_results: List[Dict],
        task: Dict,
        context: Dict
    ) -> List[Dict]:
        """Facilitate communication between agents."""
        refined = []
        
        for i, result in enumerate(initial_results):
            agent = list(self.agents.values())[i]
            
            # Create messages from other agents
            other_results = [r for j, r in enumerate(initial_results) if j != i]
            messages = [
                AgentMessage(
                    from_agent=other_result["agent"],
                    to_agent=agent.name,
                    content=str(other_result.get("recommendations", "")),
                    message_type="suggestion",
                    timestamp=asyncio.get_event_loop().time()
                )
                for other_result in other_results
            ]
            
            # Agent processes messages
            for message in messages:
                await agent.communicate(message)
            
            # Refine result based on other agents' input
            refined_result = {**result, "refined": True}
            refined.append(refined_result)
        
        return refined
    
    async def _reach_consensus(self, results: List[Dict], task: Dict) -> Dict:
        """Reach consensus from agent results."""
        # Combine recommendations
        all_recommendations = []
        for result in results:
            if "recommendations" in result:
                all_recommendations.append(result["recommendations"])
        
        # Extract common themes
        consensus_items = {}
        for result in results:
            agent_name = result.get("agent", "unknown")
            if "subtasks" in result:
                consensus_items["subtasks"] = result["subtasks"]
            if "optimal_timing" in result:
                consensus_items["timing"] = result["optimal_timing"]
            if "engagement_strategies" in result:
                consensus_items["engagement"] = result["engagement_strategies"]
            if "quality_score" in result:
                consensus_items["quality_score"] = result["quality_score"]
        
        # Calculate consensus score
        consensus_score = self._calculate_consensus_score(results)
        
        return {
            "consensus": consensus_items,
            "consensus_score": consensus_score,
            "agent_contributions": {r.get("agent"): r for r in results},
            "recommendations": "\n".join(all_recommendations)
        }
    
    def _calculate_consensus_score(self, results: List[Dict]) -> float:
        """Calculate how much agents agree."""
        # Simple consensus: average of quality scores if available
        scores = [r.get("quality_score", 0.5) for r in results if "quality_score" in r]
        if scores:
            return sum(scores) / len(scores)
        return 0.7  # Default moderate consensus
    
    def _fallback_result(self, task: Dict) -> Dict:
        """Fallback when collaboration fails."""
        return {
            "consensus": {
                "subtasks": [task.get("title", "Task")],
                "timing": {"estimated_duration": "1 hour"},
                "engagement": ["Complete the task"]
            },
            "consensus_score": 0.5,
            "agent_contributions": {},
            "recommendations": "Fallback recommendation"
        }


# Singleton instance
_coordinator = None

def get_multi_agent_coordinator() -> MultiAgentCoordinator:
    """Get singleton MultiAgentCoordinator instance."""
    global _coordinator
    if _coordinator is None:
        _coordinator = MultiAgentCoordinator()
    return _coordinator

