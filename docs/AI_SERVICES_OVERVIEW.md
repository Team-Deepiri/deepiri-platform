# AI Services Overview - Deepiri

Complete guide to all AI services and their capabilities.

## Core AI Services

### 1. Advanced Task Parser (`advanced_task_parser.py`)

**Purpose**: Next-generation task understanding with multimodal capabilities

**Features**:
- Fine-tuned Transformer (DeBERTa-v3) classification
- Multimodal understanding (CLIP + LayoutLM) for images, documents, code
- Context awareness using Graph Neural Networks
- Temporal reasoning with Temporal Fusion Transformers
- Comprehensive task decomposition
- Multi-factor complexity scoring
- Optimal conditions prediction

**Key Methods**:
- `parse_task()` - Main parsing method with full analysis
- `_classify_with_nlp()` - NLP-based classification
- `_process_multimodal()` - Multimodal input processing
- `_analyze_context()` - Context-aware analysis
- `_temporal_reasoning()` - Temporal pattern analysis
- `_decompose_task()` - Task breakdown into subtasks
- `_calculate_complexity()` - Complexity scoring

**Usage**:
```python
from app.services.advanced_task_parser import get_advanced_task_parser

parser = get_advanced_task_parser()
result = await parser.parse_task(
    task_input="Build React component",
    description="Create a reusable button component",
    context={"scheduled_time": "2024-01-15T09:00:00Z"},
    media_files=["component_design.png"],
    user_history={"task_history": [...]}
)
```

**Output Structure**:
```python
{
    "task_type": "coding",
    "complexity_score": 0.75,
    "time_estimate": "2.5 hours",
    "prerequisites": ["setup_environment", "review_design"],
    "optimal_conditions": {
        "time_of_day": "morning",
        "focus_level": "deep",
        "environment": "quiet"
    },
    "subtasks": ["setup", "implement", "test"],
    "dependencies": ["react", "typescript"],
    "cognitive_load": "high",
    "skill_requirements": ["react", "typescript", "css"],
    "multimodal_insights": {...},
    "context_analysis": {...},
    "temporal_insights": {...},
    "confidence": 0.85
}
```

---

### 2. Adaptive Challenge Generator (`adaptive_challenge_generator.py`)

**Purpose**: RL-based adaptive challenge generation with engagement prediction

**Features**:
- Proximal Policy Optimization (PPO) for challenge type selection
- Transformer-based engagement prediction
- Creative challenge design using AI
- Real-time difficulty adjustment
- Immersive 3D environment design
- Progressive reward structures
- Adaptation rules for dynamic adjustment

**Key Methods**:
- `generate_challenge()` - Main challenge generation
- `_predict_engagement()` - Engagement forecasting
- `_select_challenge_type_rl()` - RL-based type selection
- `_calculate_adaptive_difficulty()` - Dynamic difficulty
- `_generate_creative_challenge()` - AI-powered design
- `_design_reward_structure()` - Reward system design
- `_create_immersive_elements()` - 3D/audio/visual elements

**Usage**:
```python
from app.services.adaptive_challenge_generator import get_adaptive_challenge_generator

generator = get_adaptive_challenge_generator()
challenge = await generator.generate_challenge(
    task=parsed_task,
    user_profile={
        "skill_level": {"coding": 0.8},
        "preferences": {"challenge_types": ["coding_kata"]},
        "recent_performance": {...}
    },
    context={"time_of_day": "morning"},
    previous_challenges=[...]
)
```

**Output Structure**:
```python
{
    "challenge_id": "challenge_20240115_093000_1234",
    "challenge_type": "coding_kata",
    "difficulty_level": "advanced",
    "title": "React Component Sprint",
    "description": "Build a reusable button component in record time!",
    "reward_structure": {
        "base_points": 200,
        "bonus_multipliers": {...},
        "unlockables": [...],
        "progressive_rewards": [...]
    },
    "immersive_elements": {
        "3d_environment": {...},
        "audio": {...},
        "visual_effects": {...}
    },
    "time_constraints": {"min": 15, "max": 45, "optimal": 30},
    "success_criteria": ["component_created", "tests_passing"],
    "hints_system": [...],
    "adaptation_rules": {...},
    "engagement_prediction": {"predicted_engagement": 0.85}
}
```

---

### 3. Standard Services

#### Task Classifier (`task_classifier.py`)
Basic NLP-based task classification with type, complexity, and keyword extraction.

#### Challenge Generator (`challenge_generator.py`)
Standard challenge generation using OpenAI API with basic personalization.

#### Multimodal Task Understanding (`multimodal_understanding.py`)
Processes images, documents, and code files for task understanding.

#### Context-Aware Adapter (`context_aware_adaptation.py`)
Adapts challenges based on user context, time, and environment.

#### Neuro-Symbolic Challenge Generator (`neuro_symbolic_challenge.py`)
Hybrid symbolic-AI approach for rule-based + AI challenge generation.

#### Hybrid AI Service (`hybrid_ai_service.py`)
Switches between local models and cloud APIs based on availability and task requirements.

#### Reward Model (`reward_model.py`)
RLHF reward modeling for training personalized models.

#### Embedding Service (`embedding_service.py`)
Generates vector embeddings for RAG (Retrieval-Augmented Generation).

#### Inference Service (`inference_service.py`)
High-performance model inference with caching and batching.

---

## Service Integration

### Using Services Together

```python
from app.services.advanced_task_parser import get_advanced_task_parser
from app.services.adaptive_challenge_generator import get_adaptive_challenge_generator

# Step 1: Parse task with advanced understanding
parser = get_advanced_task_parser()
parsed_task = await parser.parse_task(
    task_input="Build React component",
    description="Create reusable button",
    user_history=user_history
)

# Step 2: Generate adaptive challenge
generator = get_adaptive_challenge_generator()
challenge = await generator.generate_challenge(
    task=parsed_task,
    user_profile=user_profile,
    context=context
)
```

---

## API Endpoints

### Task Parsing
- `POST /api/task/parse` - Advanced task parsing (uses AdvancedTaskParser)
- `POST /api/task/classify` - Basic task classification (uses TaskClassifier)

### Challenge Generation
- `POST /api/challenge/generate` - Adaptive challenge generation (uses AdaptiveChallengeGenerator)
- `POST /api/challenge/generate/basic` - Standard challenge generation (uses ChallengeGenerator)

### Personalization
- `POST /api/personalization/adapt` - Context-aware adaptation

### Inference
- `POST /api/inference/generate` - Model inference

### RAG
- `POST /api/rag/query` - RAG-based query processing

---

## Performance Considerations

### Caching
- Task parsing results are cached based on task text
- Challenge generation uses engagement prediction cache
- Embeddings are cached for repeated queries

### Optimization
- Batch processing for multiple tasks
- Async operations for I/O-bound tasks
- GPU acceleration for local models
- Model quantization for faster inference

---

## Future Enhancements

1. **Multi-Agent Collaboration**: Multiple AI agents working together
2. **Cognitive State Monitoring**: Real-time user state detection
3. **Predictive Analytics**: Time series forecasting for productivity
4. **Enhanced RAG**: Cross-modal retrieval with improved accuracy
5. **Dynamic LoRA Adapters**: Per-user model fine-tuning

---

## Testing

```bash
# Run AI service tests
cd diri-cyrex
pytest tests/ai/test_advanced_task_parser.py
pytest tests/ai/test_adaptive_challenge_generator.py
```

---

## Documentation

- **Service Code**: `diri-cyrex/app/services/`
- **API Routes**: `diri-cyrex/app/routes/`
- **Tests**: `diri-cyrex/tests/ai/`
- **Training**: `diri-cyrex/train/`


