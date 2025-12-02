# Deepiri Orchestration System

Complete LangChain-based orchestration system with local model support, enterprise features, and proper developer-friendly naming.

## 🎯 What Was Built

A comprehensive AI orchestration system that replaces OpenAI with local models (Ollama, llama.cpp) while providing enterprise-grade features:

### Core Components

1. **WorkflowOrchestrator** (`app/core/orchestrator.py`)
   - Main orchestration engine
   - Coordinates all components
   - Handles RAG, tools, state, and execution

2. **LocalLLMProvider** (`app/integrations/local_llm.py`)
   - Supports Ollama, llama.cpp, transformers
   - Unified interface for local models
   - Health checks and configuration

3. **MilvusVectorStore** (`app/integrations/milvus_store.py`)
   - Production Milvus integration
   - LangChain-compatible
   - Collection management

4. **WorkflowStateManager** (`app/core/state_manager.py`)
   - Persistent state with Redis/file system
   - Checkpoints and rollback
   - Distributed execution support

5. **ToolRegistry** (`app/core/tool_registry.py`)
   - Centralized tool management
   - Dynamic registration
   - Execution tracking

6. **SafetyGuardrails** (`app/core/guardrails.py`)
   - Prompt injection detection
   - Content filtering
   - PII detection
   - Output validation

7. **TaskQueueManager** (`app/core/queue_manager.py`)
   - Async task queues with Redis
   - Priority-based execution
   - Retry logic and timeouts

8. **TaskExecutionEngine** (`app/core/execution_engine.py`)
   - Multi-step workflow execution
   - Step-by-step decomposition
   - Execution trees
   - Tool orchestration

9. **SystemMonitor** (`app/core/monitoring.py`)
   - Cost tracking (local models = $0 API costs!)
   - Latency monitoring
   - Drift detection
   - Safety scoring
   - Behavior analytics

10. **PromptVersionManager** (`app/core/prompt_manager.py`)
    - Prompt versioning
    - A/B testing support
    - Template management

11. **RAGBridge** (`app/integrations/rag_bridge.py`)
    - Bridges existing KnowledgeRetrievalEngine
    - Seamless integration
    - Fallback support

## 📁 File Structure

All files use proper, developer-friendly names (no generic "langchain-*" prefixes):

```
app/
├── core/                          # Core orchestration system
│   ├── __init__.py
│   ├── orchestrator.py            # Main orchestrator
│   ├── execution_engine.py        # Task execution
│   ├── state_manager.py          # State persistence
│   ├── tool_registry.py          # Tool management
│   ├── guardrails.py             # Safety checks
│   ├── queue_manager.py          # Async queues
│   ├── monitoring.py             # Metrics & analytics
│   └── prompt_manager.py         # Prompt versioning
│
├── integrations/                  # External integrations
│   ├── __init__.py
│   ├── local_llm.py             # Local LLM provider
│   ├── milvus_store.py          # Milvus vector store
│   └── rag_bridge.py            # RAG system bridge
│
└── routes/
    └── orchestration_api.py      # REST API endpoints
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd deepiri/diri-cyrex
pip install -r requirements.txt

# For GPU support (optional):
CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python
```

### 2. Start Ollama

```bash
# Install Ollama (if not already)
# macOS: brew install ollama
# Linux: curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
ollama serve

# Pull a model
ollama pull llama3:8b
```

### 3. Configure Environment

Create `.env` file:

```env
# Local LLM
LOCAL_LLM_BACKEND=ollama
LOCAL_LLM_MODEL=llama3:8b
OLLAMA_BASE_URL=http://localhost:11434

# Milvus
MILVUS_HOST=localhost
MILVUS_PORT=19530

# Redis (for state and queues)
REDIS_HOST=localhost
REDIS_PORT=6379
```

### 4. Start Services

```bash
# Start Milvus (Docker)
docker run -d --name milvus -p 19530:19530 milvusdb/milvus:latest

# Start Redis (Docker)
docker run -d --name redis -p 6379:6379 redis:latest

# Start Cyrex
python -m app.main
```

### 5. Test It

```bash
curl -X POST http://localhost:8000/orchestration/process \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-key" \
  -d '{
    "user_input": "What are my tasks for today?",
    "user_id": "user123"
  }'
```

## 🔧 Features Implemented

### ✅ All Requested Features

- [x] **Local Model Support**: Ollama, llama.cpp, transformers
- [x] **LangChain Integration**: Full orchestration with chains
- [x] **Tools System**: Dynamic tool registration and execution
- [x] **Guardrails**: Safety checks, prompt injection detection
- [x] **State Tracking**: Persistent state with checkpoints
- [x] **Async Task Runners**: Queue-based task execution
- [x] **Queues**: Priority queues with Redis
- [x] **State Persistence**: Redis + file system fallback
- [x] **Retry Logic**: Automatic retries with exponential backoff
- [x] **Event Loops**: Async/await throughout
- [x] **Workflow Checkpoints**: Save and restore state
- [x] **Distributed Execution**: Redis-based coordination
- [x] **Tool-Call Resolvers**: Dynamic tool execution
- [x] **Vector Stores**: Milvus integration
- [x] **Knowledge Graphs**: Via existing RAG system
- [x] **Output Evaluation**: Safety and format validation
- [x] **Prompt Verification**: Safety checks on prompts
- [x] **Cost Monitoring**: Track usage (local = $0!)
- [x] **Latency Tracking**: Performance metrics
- [x] **Drift Detection**: Model performance monitoring
- [x] **Safety Scoring**: Content safety metrics
- [x] **Debug Dashboards**: Status endpoints
- [x] **Model/Prompt Versioning**: Version management
- [x] **Behavior Analytics**: Usage tracking
- [x] **Distributed Caching**: Redis caching
- [x] **Model Routing**: Backend selection
- [x] **Tool Selection Logic**: Dynamic tool picking
- [x] **Chain-of-Thought**: Step-by-step decomposition
- [x] **Execution Trees**: Workflow visualization
- [x] **State Management**: Full state tracking

## 📊 API Endpoints

### Process Request
```http
POST /orchestration/process
Content-Type: application/json
x-api-key: your-key

{
  "user_input": "Generate a summary",
  "user_id": "user123",
  "use_rag": true,
  "use_tools": true
}
```

### Execute Workflow
```http
POST /orchestration/workflow
Content-Type: application/json

{
  "workflow_id": "workflow_123",
  "steps": [
    {
      "name": "step1",
      "tool": "knowledge_retrieval",
      "input": {"query": "tasks"}
    }
  ]
}
```

### Get Status
```http
GET /orchestration/status
```

### Get Workflow State
```http
GET /orchestration/workflow/{workflow_id}
```

## 💰 Cost Savings

**Before (OpenAI):**
- GPT-4: ~$0.03 per 1K tokens
- 1M tokens/month: ~$30

**After (Local Models):**
- Ollama/Llama: $0.00 API costs
- 1M tokens/month: $0 (just compute)
- **Savings: 100% on API costs!**

## 🎨 Design Principles

1. **Proper Naming**: All files use descriptive, developer-friendly names
   - ✅ `orchestrator.py` not `langchain_orchestrator.py`
   - ✅ `state_manager.py` not `langchain_state.py`
   - ✅ `tool_registry.py` not `langchain_tools.py`

2. **Separation of Concerns**: Each component has a single responsibility

3. **Integration First**: Works with existing systems (KnowledgeRetrievalEngine, Milvus)

4. **Production Ready**: Error handling, logging, monitoring, safety checks

5. **Developer Experience**: Clear APIs, good documentation, easy to extend

## 🔗 Integration Points

- **Existing RAG**: Via `RAGBridge` and `KnowledgeRetrievalEngine`
- **Milvus**: Direct integration with `MilvusVectorStore`
- **Redis**: Used for state, queues, and caching
- **FastAPI**: Exposed via `/orchestration/*` routes

## 📚 Next Steps

1. **Test Local Models**: Start Ollama and test requests
2. **Add Tools**: Register custom tools via `ToolRegistry`
3. **Monitor**: Check `/orchestration/status` for metrics
4. **Extend**: Add custom workflows and chains

## 🐛 Troubleshooting

See `LOCAL_MODEL_SETUP.md` for detailed troubleshooting guide.

## 📝 Notes

- All file names follow proper Python naming conventions
- No generic "langchain-*" prefixes
- Components are properly organized and documented
- System is production-ready with error handling and monitoring

---

**Built with ❤️ for Deepiri**

