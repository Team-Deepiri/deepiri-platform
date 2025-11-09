"""
Procedural Content Generation Service
Template-based challenge variants, Markov chains, genetic algorithms
"""
import random
import json
from typing import Dict, List, Optional
from collections import defaultdict
from ..logging_config import get_logger

logger = get_logger("pyagent.procedural_content")


class ProceduralContentGenerator:
    """
    Generates procedural content for challenges:
    - Template-based variants
    - Markov chains for narrative
    - Genetic algorithms for puzzle optimization
    - Style transfer for theming
    """
    
    def __init__(self):
        self.templates = self._load_templates()
        self.markov_chains = {}
        self.puzzle_pool = []
        self._initialize_markov_chains()
    
    def _load_templates(self) -> Dict:
        """Load challenge templates."""
        return {
            'coding_sprint': {
                'base': "Complete {target} in {time_limit} minutes",
                'variants': [
                    "Write {target} with {constraint}",
                    "Implement {target} using {technique}",
                    "Refactor {target} to {goal}",
                    "Debug {target} and fix {issue}"
                ],
                'parameters': ['target', 'time_limit', 'constraint', 'technique', 'goal', 'issue']
            },
            'puzzle': {
                'base': "Solve this puzzle: {puzzle_type}",
                'variants': [
                    "Complete the {puzzle_type} puzzle in {time_limit}",
                    "Find the solution to {puzzle_type}",
                    "Master {puzzle_type} challenge"
                ],
                'parameters': ['puzzle_type', 'time_limit']
            },
            'quiz': {
                'base': "Answer {question_count} questions about {topic}",
                'variants': [
                    "Test your knowledge of {topic}",
                    "Quiz: {topic} mastery",
                    "Challenge: {topic} expertise"
                ],
                'parameters': ['question_count', 'topic']
            },
            'creative_sprint': {
                'base': "Create {output_type} about {theme}",
                'variants': [
                    "Design {output_type} with {style}",
                    "Write {output_type} in {format}",
                    "Build {output_type} for {purpose}"
                ],
                'parameters': ['output_type', 'theme', 'style', 'format', 'purpose']
            }
        }
    
    def _initialize_markov_chains(self):
        """Initialize Markov chains for narrative generation."""
        # Sample narrative corpus
        narratives = [
            "You are a coding wizard on a quest to master productivity",
            "The challenge awaits your skills and determination",
            "Complete the mission and unlock new achievements",
            "Your journey to productivity excellence continues",
            "Every task completed brings you closer to mastery",
            "The path to success is paved with focused effort",
            "Unlock your potential through consistent practice"
        ]
        
        # Build Markov chain
        chain = defaultdict(list)
        for narrative in narratives:
            words = narrative.lower().split()
            for i in range(len(words) - 1):
                chain[words[i]].append(words[i + 1])
        
        self.markov_chains['narrative'] = chain
    
    def generate_challenge_variant(
        self,
        challenge_type: str,
        task_data: Dict,
        user_profile: Optional[Dict] = None
    ) -> Dict:
        """Generate challenge variant from template."""
        try:
            template = self.templates.get(challenge_type)
            if not template:
                template = self.templates['coding_sprint']  # Default
            
            # Select random variant
            variant_template = random.choice(template['variants'])
            
            # Fill in parameters
            filled_template = variant_template
            for param in template['parameters']:
                value = self._get_parameter_value(param, task_data, user_profile)
                filled_template = filled_template.replace(f"{{{param}}}", str(value))
            
            # Generate narrative
            narrative = self._generate_narrative(challenge_type)
            
            return {
                'title': filled_template,
                'description': narrative,
                'type': challenge_type,
                'template_used': variant_template,
                'parameters': self._extract_parameters(task_data, user_profile)
            }
            
        except Exception as e:
            logger.error("Error generating challenge variant", error=str(e))
            return self._fallback_challenge(task_data)
    
    def _get_parameter_value(self, param: str, task_data: Dict, user_profile: Optional[Dict]) -> str:
        """Get value for template parameter."""
        param_map = {
            'target': task_data.get('title', 'the task'),
            'time_limit': str(random.randint(5, 60)),
            'constraint': random.choice(['no loops', 'functional style', 'OOP', 'async']),
            'technique': random.choice(['TDD', 'pair programming', 'refactoring', 'design patterns']),
            'goal': random.choice(['better performance', 'cleaner code', 'better UX']),
            'issue': random.choice(['bug', 'performance issue', 'security vulnerability']),
            'puzzle_type': random.choice(['logic', 'math', 'pattern', 'word']),
            'question_count': str(random.randint(5, 20)),
            'topic': task_data.get('type', 'general'),
            'output_type': random.choice(['article', 'design', 'prototype', 'presentation']),
            'theme': task_data.get('title', 'productivity'),
            'style': random.choice(['minimalist', 'modern', 'classic', 'bold']),
            'format': random.choice(['blog post', 'essay', 'report', 'story']),
            'purpose': random.choice(['education', 'entertainment', 'inspiration'])
        }
        
        return param_map.get(param, f"[{param}]")
    
    def _generate_narrative(self, challenge_type: str, length: int = 3) -> str:
        """Generate narrative using Markov chain."""
        try:
            chain = self.markov_chains.get('narrative', {})
            if not chain:
                return "Complete this challenge and earn rewards!"
            
            # Start with random word
            current_word = random.choice(list(chain.keys()))
            narrative = [current_word.capitalize()]
            
            for _ in range(length - 1):
                if current_word in chain and chain[current_word]:
                    next_word = random.choice(chain[current_word])
                    narrative.append(next_word)
                    current_word = next_word
                else:
                    break
            
            return " ".join(narrative) + "!"
            
        except Exception as e:
            logger.error("Error generating narrative", error=str(e))
            return "Complete this challenge and unlock rewards!"
    
    def _extract_parameters(self, task_data: Dict, user_profile: Optional[Dict]) -> Dict:
        """Extract parameters for challenge."""
        return {
            'task_title': task_data.get('title', ''),
            'task_type': task_data.get('type', 'general'),
            'complexity': task_data.get('complexity', 0.5),
            'user_skill': user_profile.get('skill_level', 0.5) if user_profile else 0.5
        }
    
    def _fallback_challenge(self, task_data: Dict) -> Dict:
        """Fallback challenge if generation fails."""
        return {
            'title': f"Complete: {task_data.get('title', 'Task')}",
            'description': "Complete this task to earn rewards!",
            'type': 'general',
            'template_used': 'fallback',
            'parameters': {}
        }
    
    def optimize_puzzle_genetic(
        self,
        puzzle_type: str,
        target_difficulty: float,
        generations: int = 10,
        population_size: int = 20
    ) -> Dict:
        """
        Optimize puzzle using genetic algorithm.
        
        Args:
            puzzle_type: Type of puzzle
            target_difficulty: Target difficulty (0.0-1.0)
            generations: Number of generations
            population_size: Population size
            
        Returns:
            Optimized puzzle configuration
        """
        try:
            # Initialize population
            population = []
            for _ in range(population_size):
                puzzle = self._create_random_puzzle(puzzle_type)
                puzzle['fitness'] = self._calculate_puzzle_fitness(puzzle, target_difficulty)
                population.append(puzzle)
            
            # Evolve
            for generation in range(generations):
                # Sort by fitness
                population.sort(key=lambda x: x['fitness'], reverse=True)
                
                # Keep top 50%
                elite = population[:population_size // 2]
                
                # Generate new population
                new_population = elite.copy()
                while len(new_population) < population_size:
                    # Crossover
                    parent1 = random.choice(elite)
                    parent2 = random.choice(elite)
                    child = self._crossover_puzzles(parent1, parent2)
                    
                    # Mutation
                    if random.random() < 0.3:
                        child = self._mutate_puzzle(child)
                    
                    child['fitness'] = self._calculate_puzzle_fitness(child, target_difficulty)
                    new_population.append(child)
                
                population = new_population
                logger.debug(f"Generation {generation} best fitness: {population[0]['fitness']}")
            
            # Return best puzzle
            population.sort(key=lambda x: x['fitness'], reverse=True)
            return population[0]
            
        except Exception as e:
            logger.error("Error in genetic puzzle optimization", error=str(e))
            return self._create_random_puzzle(puzzle_type)
    
    def _create_random_puzzle(self, puzzle_type: str) -> Dict:
        """Create random puzzle configuration."""
        return {
            'type': puzzle_type,
            'complexity': random.random(),
            'time_limit': random.randint(5, 60),
            'hints_available': random.randint(0, 3),
            'parameters': {
                'size': random.randint(3, 10),
                'rules': random.randint(1, 5)
            }
        }
    
    def _calculate_puzzle_fitness(self, puzzle: Dict, target_difficulty: float) -> float:
        """Calculate fitness of puzzle (how close to target difficulty)."""
        current_difficulty = puzzle.get('complexity', 0.5)
        distance = abs(current_difficulty - target_difficulty)
        fitness = 1.0 - distance  # Closer = higher fitness
        return fitness
    
    def _crossover_puzzles(self, parent1: Dict, parent2: Dict) -> Dict:
        """Crossover two puzzles to create child."""
        child = {
            'type': parent1['type'],
            'complexity': (parent1['complexity'] + parent2['complexity']) / 2,
            'time_limit': random.choice([parent1['time_limit'], parent2['time_limit']]),
            'hints_available': random.choice([parent1['hints_available'], parent2['hints_available']]),
            'parameters': {
                'size': (parent1['parameters']['size'] + parent2['parameters']['size']) // 2,
                'rules': random.choice([parent1['parameters']['rules'], parent2['parameters']['rules']])
            }
        }
        return child
    
    def _mutate_puzzle(self, puzzle: Dict) -> Dict:
        """Mutate puzzle with small random changes."""
        mutation_rate = 0.1
        
        if random.random() < mutation_rate:
            puzzle['complexity'] = max(0.0, min(1.0, puzzle['complexity'] + random.uniform(-0.1, 0.1)))
        
        if random.random() < mutation_rate:
            puzzle['time_limit'] = max(5, puzzle['time_limit'] + random.randint(-10, 10))
        
        if random.random() < mutation_rate:
            puzzle['parameters']['size'] = max(3, puzzle['parameters']['size'] + random.randint(-2, 2))
        
        return puzzle
    
    def apply_style_transfer(self, challenge: Dict, style: str) -> Dict:
        """Apply style transfer to challenge theming."""
        style_themes = {
            'cyberpunk': {
                'color_scheme': 'neon',
                'atmosphere': 'futuristic',
                'music': 'electronic'
            },
            'medieval': {
                'color_scheme': 'earthy',
                'atmosphere': 'fantasy',
                'music': 'orchestral'
            },
            'minimalist': {
                'color_scheme': 'monochrome',
                'atmosphere': 'clean',
                'music': 'ambient'
            },
            'retro': {
                'color_scheme': 'vibrant',
                'atmosphere': 'nostalgic',
                'music': '8-bit'
            }
        }
        
        theme = style_themes.get(style, style_themes['minimalist'])
        challenge['theme'] = theme
        challenge['style'] = style
        
        return challenge


# Singleton instance
_content_generator = None

def get_procedural_content_generator() -> ProceduralContentGenerator:
    """Get singleton ProceduralContentGenerator instance."""
    global _content_generator
    if _content_generator is None:
        _content_generator = ProceduralContentGenerator()
    return _content_generator

