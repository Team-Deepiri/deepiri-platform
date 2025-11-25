# Deepiri AI Layer - Complete Architecture

## 🎯 Overview

This document outlines the AI layer architecture for Deepiri's gamification system, including three complementary AI models for role-based abilities, dynamic generation, and adaptive learning.

**Status**: ✅ **FULLY IMPLEMENTED** with LangChain integration

All services are implemented in `diri-cyrex/app/services/`:
- `deepiri_intent_classifier.py` - Tier 1: Classification
- `deepiri_ability_generator.py` - Tier 2: Generation (LangChain)
- `deepiri_productivity_agent.py` - Tier 3: RL Optimization
- `deepiri_rag_orchestrator.py` - RAG Orchestration (LangChain)

API endpoints available at `/agent/ai/*`

---

## 📊 Three-Tier AI Architecture

### 1. **Classification Layer** (Reliability & Control)
**Purpose**: Predefined ability selection and intent classification  
**Use Case**: Enterprise-grade shortcuts, role-based abilities, task classification

### 2. **Generation Layer** (Creativity & Flexibility)  
**Purpose**: On-the-fly ability creation and context-aware responses  
**Use Case**: Dynamic abilities, personalized suggestions, creative problem-solving

### 3. **Optimization Layer** (Adaptive Learning)  
**Purpose**: Long-term learning and behavior optimization  
**Use Case**: Personalized productivity patterns, proactive suggestions, workflow optimization

---

## 1️⃣ Classification Layer: Role-Based Abilities

### Model Selection
**Primary**: Fine-tuned **BERT** or **DeBERTa**  
**Alternative**: DistilBERT (faster, slightly less accurate)

### Architecture

```python
# Model: BERT-based classifier
Input: User command text (e.g., "Can you summarize this?")
Output: Probability distribution over predefined abilities

Layers:
- BERT Base (bert-base-uncased)
- Dropout (0.1)
- Dense Layer (768 → 512)
- ReLU Activation
- Dropout (0.2)
- Dense Layer (512 → num_abilities)
- Softmax Output
```

### Training Dataset Structure

```json
{
  "training_data": [
    {
      "text": "Can you make this shorter?",
      "intent": "summarize",
      "ability_id": "ability_summarize",
      "confidence": 0.95
    },
    {
      "text": "Create a task from this email",
      "intent": "create_objective",
      "ability_id": "ability_create_objective",
      "confidence": 0.92
    },
    {
      "text": "Activate focus mode for 60 minutes",
      "intent": "activate_boost",
      "ability_id": "ability_focus_boost",
      "confidence": 0.98
    }
  ]
}
```

### Role-Based Abilities

```python
ROLE_ABILITIES = {
    "software_engineer": [
        "code_review",
        "debug_assist",
        "refactor_suggest",
        "documentation_gen",
        "test_generation",
        "commit_message_gen"
    ],
    "designer": [
        "design_critique",
        "color_palette_gen",
        "layout_suggest",
        "export_assets",
        "design_system_check"
    ],
    "product_manager": [
        "feature_breakdown",
        "user_story_gen",
        "sprint_planning",
        "roadmap_suggest",
        "stakeholder_update"
    ],
    "marketer": [
        "copy_gen",
        "campaign_suggest",
        "audience_analysis",
        "content_calendar",
        "seo_optimize"
    ]
}
```

### Implementation Files

**✅ IMPLEMENTED**: `app/services/deepiri_intent_classifier.py`

```
diri-cyrex/app/
├── services/
│   └── deepiri_intent_classifier.py  # ✅ Main classifier (BERT/DeBERTa)
├── routes/
│   └── deepiri_ai_routes.py          # ✅ API endpoints
└── train/
    ├── scripts/
    │   └── train_intent_classifier.py # Training script
    └── data/
        └── ability_commands.jsonl     # Training data
```

### API Endpoint

```python
@app.post("/ai/classify-ability")
async def classify_ability(request: AbilityRequest):
    """
    Classify user command to predefined ability
    
    Input: {
        "user_id": "user123",
        "role": "software_engineer",
        "command": "Can you review this code?",
        "context": {"file": "auth.ts", "lines": 50}
    }
    
    Output: {
        "ability_id": "code_review",
        "confidence": 0.95,
        "parameters": {
            "file": "auth.ts",
            "review_type": "security",
            "priority": "high"
        }
    }
    """
    pass
```

---

## 2️⃣ Generation Layer: LLM + RAG

### Model Selection
**Primary**: GPT-4 Turbo (via Azure OpenAI) or Claude 3.5 Sonnet  
**Alternative**: Llama 3 70B (self-hosted) with fine-tuning

### Architecture

```
User Input → RAG Retriever → Context Builder → LLM → Structured Output
                ↓
          Vector Database
       (User history, Rules,
        Project context)
```

### RAG System Components

#### Vector Database Structure
```python
# Using ChromaDB or Pinecone
collections = {
    "user_patterns": {
        # User's historical behavior, preferences
        "embedding_model": "text-embedding-ada-002",
        "metadata": ["timestamp", "user_id", "success_rate"]
    },
    "project_context": {
        # Current project files, docs, code
        "embedding_model": "text-embedding-ada-002",
        "metadata": ["file_path", "last_modified", "language"]
    },
    "ability_templates": {
        # Pre-defined ability templates
        "embedding_model": "text-embedding-ada-002",
        "metadata": ["category", "complexity", "role"]
    },
    "rules_knowledge": {
        # Business rules, constraints
        "embedding_model": "text-embedding-ada-002",
        "metadata": ["priority", "scope", "version"]
    }
}
```

#### LLM Prompt Structure

```python
GENERATION_PROMPT = """
You are an AI assistant for Deepiri, a gamified productivity platform.

CONTEXT FROM RAG:
{retrieved_context}

USER REQUEST:
{user_command}

USER ROLE: {user_role}
CURRENT MOMENTUM: {user_momentum}
ACTIVE BOOSTS: {active_boosts}
RECENT ACTIVITIES: {recent_activities}

TASK:
Generate a dynamic ability that helps the user accomplish their request.
The ability should be contextual, actionable, and fit within the gamification system.

OUTPUT FORMAT (JSON):
{
  "ability_name": "string",
  "description": "string",
  "category": "string (productivity|automation|boost|skill)",
  "parameters": {
    "action": "string",
    "target": "string",
    "options": {}
  },
  "momentum_cost": number,
  "estimated_duration": number,
  "success_criteria": "string"
}

RULES:
- Abilities must align with user's role and skill level
- Cost should be proportional to complexity
- Include clear success criteria
- Respect momentum balance and boost limitations
"""
```

### Implementation Files

**✅ IMPLEMENTED**: `app/services/deepiri_ability_generator.py` + `deepiri_rag_orchestrator.py`

```
diri-cyrex/app/
├── services/
│   ├── deepiri_ability_generator.py  # ✅ Main LLM generator (LangChain)
│   └── deepiri_rag_orchestrator.py  # ✅ RAG orchestration (LangChain)
├── routes/
│   └── deepiri_ai_routes.py          # ✅ API endpoints
└── train/
    └── scripts/
        └── train_ability_generator.py # Training/data collection
```

### API Endpoint

```python
@app.post("/ai/generate-ability")
async def generate_ability(request: GenerationRequest):
    """
    Generate dynamic ability using LLM + RAG
    
    Input: {
        "user_id": "user123",
        "command": "I need to refactor this codebase to use TypeScript",
        "context": {
            "project": "deepiri-web-frontend",
            "current_files": ["*.js", "*.jsx"],
            "estimated_size": "10k lines"
        }
    }
    
    Output: {
        "ability": {
            "name": "TypeScript Migration Assistant",
            "description": "Converts JS/JSX files to TypeScript with type inference",
            "steps": [
                "Analyze current JS files",
                "Generate TypeScript equivalents",
                "Add type annotations",
                "Fix type errors"
            ],
            "momentum_cost": 50,
            "estimated_duration": 120
        },
        "confidence": 0.87,
        "alternative_approaches": [...]
    }
    """
    pass
```

---

## 3️⃣ Optimization Layer: Reinforcement Learning

### Model Selection
**Primary**: PPO (Proximal Policy Optimization)  
**Alternative**: A2C (Advantage Actor-Critic) for faster training

### Architecture

```
State Space: [user_context, current_momentum, active_tasks, time_of_day, 
              past_performance, available_abilities]
              
Action Space: [select_ability, suggest_objective, activate_boost, 
               schedule_task, propose_odyssey]
               
Reward Function: user_satisfaction + task_completion_rate + 
                momentum_growth + time_efficiency
```

### RL System Design

```python
class ProductivityAgent:
    def __init__(self):
        self.state_dim = 128  # Embedded state representation
        self.action_dim = 50  # Number of possible actions
        
        # Actor Network (Policy)
        self.actor = nn.Sequential(
            nn.Linear(128, 256),
            nn.ReLU(),
            nn.Linear(256, 256),
            nn.ReLU(),
            nn.Linear(256, 50),
            nn.Softmax(dim=-1)
        )
        
        # Critic Network (Value)
        self.critic = nn.Sequential(
            nn.Linear(128, 256),
            nn.ReLU(),
            nn.Linear(256, 256),
            nn.ReLU(),
            nn.Linear(256, 1)
        )
    
    def get_state(self, user_data):
        """Encode user state into embedding"""
        return torch.tensor([
            user_data['momentum_normalized'],
            user_data['task_completion_rate'],
            user_data['current_streak'],
            user_data['time_of_day_encoded'],
            user_data['work_intensity'],
            # ... more features
        ])
    
    def select_action(self, state):
        """Select ability/action based on current state"""
        action_probs = self.actor(state)
        dist = Categorical(action_probs)
        action = dist.sample()
        return action, dist.log_prob(action)
    
    def compute_reward(self, outcome):
        """Calculate reward based on user outcome"""
        reward = 0.0
        
        # Task completion reward
        if outcome['task_completed']:
            reward += 10.0 * outcome['efficiency']
        
        # User satisfaction (explicit feedback)
        reward += outcome['user_rating'] * 5.0
        
        # Time efficiency (completed faster than estimated)
        if outcome['time_saved'] > 0:
            reward += outcome['time_saved'] * 0.5
        
        # Momentum growth
        reward += outcome['momentum_gained'] * 0.1
        
        # Penalties
        if outcome['user_frustrated']:
            reward -= 20.0
        
        return reward
```

### Training Pipeline

```
1. Data Collection (Online/Offline)
   - User interactions
   - Task completions
   - Ability usage patterns
   - Explicit feedback

2. State Encoding
   - User profile embedding
   - Context embedding
   - Historical pattern embedding

3. Training Loop (PPO)
   - Collect trajectories
   - Compute advantages
   - Update policy
   - Update value function

4. Evaluation
   - A/B testing against baseline
   - User satisfaction metrics
   - Productivity improvements
```

### Implementation Files

**✅ IMPLEMENTED**: `app/services/deepiri_productivity_agent.py`

```
diri-cyrex/app/
├── services/
│   └── deepiri_productivity_agent.py  # ✅ PPO agent (full implementation)
├── routes/
│   └── deepiri_ai_routes.py           # ✅ API endpoints
└── train/
    ├── scripts/
    │   └── train_productivity_agent.py # Training loop
    └── data/
        └── rl_interactions.jsonl       # Experience data
```

### API Endpoint

```python
@app.post("/ai/recommend-action")
async def recommend_action(request: RecommendationRequest):
    """
    Get RL agent's recommended action
    
    Input: {
        "user_id": "user123",
        "current_state": {
            "momentum": 450,
            "active_tasks": 3,
            "time_of_day": "afternoon",
            "recent_efficiency": 0.85
        }
    }
    
    Output: {
        "recommended_action": {
            "type": "activate_boost",
            "ability": "velocity",
            "reasoning": "You're in high-efficiency mode. A velocity boost now could help you complete 2-3 more tasks.",
            "expected_benefit": {
                "momentum_gain": 25,
                "time_saved": 30,
                "confidence": 0.82
            }
        },
        "alternatives": [...]
    }
    """
    pass
```

---

## 🏗️ Infrastructure & Pipeline

### Technology Stack

**✅ IMPLEMENTED**:

```yaml
Machine Learning:
  - PyTorch 2.0+ ✅
  - Transformers (Hugging Face) ✅
  - LangChain 0.1.0+ ✅ (FULLY INTEGRATED)
  - LangChain OpenAI ✅
  - LangChain Community ✅
  - LangChain Chroma ✅
  - ChromaDB ✅
  - MLflow ✅

Backend:
  - FastAPI ✅
  - Redis (caching) ✅
  - MongoDB (document storage) ✅

Model Serving:
  - Direct PyTorch inference ✅
  - Docker + Kubernetes (ready)
```

**LangChain Integration**:
- ✅ LangChain chains for RAG
- ✅ LangChain vector stores (Chroma/Milvus)
- ✅ LangChain output parsers (Pydantic)
- ✅ LangChain prompt templates
- ✅ LangChain retrievers with compression

### Directory Structure

**✅ IMPLEMENTED**:

```
diri-cyrex/
├── app/
│   ├── services/
│   │   ├── deepiri_intent_classifier.py      # ✅ Tier 1: Classification
│   │   ├── deepiri_ability_generator.py      # ✅ Tier 2: Generation (LangChain)
│   │   ├── deepiri_productivity_agent.py     # ✅ Tier 3: RL
│   │   └── deepiri_rag_orchestrator.py       # ✅ RAG Orchestration (LangChain)
│   ├── routes/
│   │   └── deepiri_ai_routes.py             # ✅ All AI endpoints
│   └── ml_models/                            # (Legacy - use services/)
│       ├── classifiers/
│       ├── generators/
│       └── rl_agent/
├── train/
│   ├── scripts/                              # Training scripts
│   └── data/                                 # Training data
└── tests/                                    # Unit & integration tests
```

### Model Deployment Pipeline

```
1. Training (Offline)
   └─> Train classifier, fine-tune LLM, train RL agent

2. Evaluation
   └─> Validate on test set, A/B testing

3. Model Registry (MLflow)
   └─> Version control, model metadata

4. Containerization (Docker)
   └─> Package models with dependencies

5. Deployment (Kubernetes)
   └─> Rolling updates, auto-scaling

6. Monitoring (Prometheus + Grafana)
   └─> Latency, accuracy, user satisfaction

7. Continual Learning
   └─> Online updates, feedback loops
```

---

## 📝 Implementation Roadmap

### Phase 1: Classification Layer (2-3 weeks)
- [ ] Collect training data (user commands → abilities)
- [ ] Fine-tune BERT model for intent classification
- [ ] Implement role-based ability mapping
- [ ] Create inference API endpoint
- [ ] Deploy and test in production

### Phase 2: Generation Layer (3-4 weeks)
- [ ] Set up vector database (ChromaDB/Pinecone)
- [ ] Implement RAG retrieval system
- [ ] Integrate GPT-4 / Claude API
- [ ] Build context builder and prompt engineering
- [ ] Create generation API endpoint
- [ ] Test with real user scenarios

### Phase 3: RL Optimization Layer (4-6 weeks)
- [ ] Define state/action space
- [ ] Implement PPO agent
- [ ] Create productivity environment simulator
- [ ] Collect user interaction data
- [ ] Train RL agent offline
- [ ] Deploy for online learning
- [ ] A/B test against baseline

### Phase 4: Integration & Monitoring (2 weeks)
- [ ] Integrate all three layers
- [ ] Build unified API gateway
- [ ] Set up monitoring and logging
- [ ] Implement feedback loops
- [ ] Create admin dashboard for model management

---

## 🎯 Success Metrics

### Classification Layer
- **Accuracy**: >90% on test set
- **Latency**: <100ms per request
- **User Satisfaction**: >4.5/5

### Generation Layer
- **Relevance**: >85% of generated abilities used
- **Creativity**: User-rated uniqueness >4/5
- **Latency**: <3s per generation

### RL Layer
- **Productivity Gain**: +20% task completion rate
- **User Engagement**: +30% daily active time
- **Satisfaction**: +25% positive feedback

---

## 🔒 Security & Privacy

- All user data encrypted at rest and in transit
- PII removed from training data
- Model outputs sanitized before display
- Rate limiting on AI endpoints
- User opt-out for AI suggestions

---

This architecture provides a complete, production-ready AI layer for Deepiri's gamification system!

