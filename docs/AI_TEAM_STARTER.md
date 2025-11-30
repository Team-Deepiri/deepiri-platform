# AI Team Starter Guide

## What's Been Implemented

### 1. Task Classification Service
**Location**: `diri-cyrex/app/services/task_classifier.py`

**Features**:
- NLP-based task classification
- Extracts task type, complexity, duration estimates
- Keyword extraction
- Focus requirements detection
- Chunking capability detection

**Usage**:
```python
from app.services.task_classifier import get_task_classifier

classifier = get_task_classifier()
result = await classifier.classify_task(
    "Write a report on AI trends",
    "Research and write comprehensive report"
)
```

**API Endpoint**: `POST /agent/task/classify`

### 2. Challenge Generation Service
**Location**: `diri-cyrex/app/services/challenge_generator.py`

**Features**:
- Converts tasks into gamified challenges
- Adaptive difficulty based on user history
- Multiple challenge types (quiz, puzzle, coding, timed, etc.)
- Points calculation based on difficulty
- Milestone generation

**Usage**:
```python
from app.services.challenge_generator import get_challenge_generator

generator = get_challenge_generator()
challenge = await generator.generate_challenge(
    task_dict,
    user_history=user_performance_data,
    difficulty_preference='medium'
)
```

**API Endpoint**: `POST /agent/challenge/generate`

### 3. Training Script Templates
**Location**: `diri-cyrex/train/scripts/`

- `train_task_classifier.py` - Task classification model training
- `train_challenge_generator.py` - Challenge generation model training
- `train_personalization_model.py` - RL personalization model training

## Next Steps for AI Team

### Immediate Tasks

1. **AI Research Scientists**
   - Implement actual model training in training scripts
   - Research and test different model architectures
   - Fine-tune transformer models for task classification
   - Experiment with challenge generation approaches

2. **ML Engineers**
   - Set up training pipelines
   - Implement model training loops
   - Add evaluation metrics
   - Set up model versioning

3. **Data Engineers**
   - Create training datasets in `train/data/`
   - Format: JSONL files with task examples
   - Collect user behavior data
   - Prepare challenge generation examples

4. **AI Systems Engineers**
   - Integrate trained models into services
   - Optimize inference performance
   - Set up model serving infrastructure
   - Implement model caching

### Training Data Format

**Task Classification** (`train/data/task_classification.jsonl`):
```json
{"text": "Write a report on AI trends", "type": "creative", "complexity": "medium", "duration": 60}
{"text": "Fix bug in login system", "type": "code", "complexity": "hard", "duration": 45}
```

**Challenge Generation** (`train/data/challenge_generation.jsonl`):
```json
{"task": {"title": "Write report", "type": "creative"}, "challenge": {"type": "puzzle", "difficulty": "medium", "points": 250}}
```

**User Behavior** (`train/data/user_behavior.jsonl`):
```json
{"user_id": "123", "challenge_id": "456", "performance": 0.8, "engagement": 0.9, "completion_time": 45}
```

## Running Training

```bash
# Task classifier
python train/scripts/train_task_classifier.py

# Challenge generator
python train/scripts/train_challenge_generator.py

# Personalization model
python train/scripts/train_personalization_model.py
```

## Model Deployment

Trained models should be saved to:
- `train/models/task_classifier/` - Task classification models
- `train/models/challenge_generator/` - Challenge generation models
- `train/models/personalization/` - Personalization models

Models are then deployed to:
- `inference/models/` - For production use

## Integration

The services are already integrated into the API:
- Task classification: `POST /agent/task/classify`
- Challenge generation: `POST /agent/challenge/generate`

Both endpoints work with:
- Web app (React deepiri-web-frontend)
- Desktop IDE (Electron app)

## Resources

- OpenAI API for current implementation
- PyTorch/Transformers for model training
- MLflow for experiment tracking
- Weights & Biases for experiment management

## Questions?

See `README_AI_TEAM.md` for full team documentation.


