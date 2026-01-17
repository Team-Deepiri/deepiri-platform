# Synapse Data Streaming Pipeline - Complete Implementation Plan
## Strictly Divided: Taylor's Bootcamp | Harrison's Bootcamp | Convergence Point

---

## Table of Contents

1. [Shared Background](#shared-background) - Read This First
2. [TAYLOR'S BOOTCAMP](#taylors-bootcamp) - Complete Independent Path (Weeks 1-2)
3. [HARRISON'S BOOTCAMP](#harrisons-bootcamp) - Complete Independent Path (Weeks 1-2)
4. [CONVERGENCE POINT](#convergence-point) - Where You Collide (Week 3)
5. [ADVANCED FEATURES TOGETHER](#advanced-features-together) - Final Phase (Week 4)

---

## Shared Background

**Both Taylor and Harrison must read this section before starting.**

### What is Synapse?

Synapse is the **nervous system** of the Deepiri platform. Think of it as a central messaging hub that allows all services to communicate in real-time through events.

**Analogy**: If services are neurons, Synapse is the network that connects them, allowing them to send and receive signals instantly.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SYNAPSE SERVICE                          │
│              (Redis Streams + Management API)               │
│                                                              │
│  Streams:                                                    │
│  • model-events      (Helox → Cyrex)                        │
│  • inference-events  (Cyrex → Platform Services)            │
│  • training-events   (Helox → Analytics)                    │
│  • platform-events   (All Services → Realtime Gateway)     │
│  • agi-decisions     (Future: AGI → Platform)              │
│  • error-events      (All Services → Monitoring)             │
└──────────────────┬──────────────────────────────────────────┘
                   │
    ┌──────────────┼──────────────┬──────────────┐
    │              │              │              │
    ▼              ▼              ▼              ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐  ┌──────────────┐
│  HELOX  │  │  CYREX  │  │   PLATFORM   │  │   SHARED     │
│  (ML)   │  │  (AI)   │  │   SERVICES   │  │   LIBRARIES  │
│         │  │         │  │              │  │              │
│ Publishes│  │Subscribes│  │ 9 Services:  │  │ ModelKit     │
│ • model │  │ • model │  │ • API Gateway│  │ Shared Utils  │
│ • train │  │         │  │ • Auth       │  │               │
│         │  │ Publishes│  │ • Task      │  │               │
│         │  │ • infer │  │ • Analytics  │  │               │
│         │  │ • RAG   │  │ • Notify     │  │               │
│         │  │ • agent │  │ • Realtime   │  │               │
│         │  │         │  │ • Challenge  │  │               │
│         │  │         │  │ • Engagement │  │               │
│         │  │         │  │ • External   │  │               │
└─────────┘  └─────────┘  └──────────────┘  └──────────────┘
```

### Key Concepts

**Events**: Messages that services send to each other. Examples:
- "A new model is ready" (from Helox)
- "An inference was completed" (from Cyrex)
- "A user logged in" (from Auth Service)

**Streams**: Channels where events flow. Like different radio stations - each stream carries specific types of events.

**Publish**: Sending an event to a stream (like broadcasting)

**Subscribe**: Listening to events from a stream (like tuning in)

**Consumer Groups**: Multiple services can listen to the same stream, and Redis ensures each event is delivered to each consumer.

### What Exists Today

**Synapse Service** (`platform-services/shared/deepiri-synapse/`):
- Basic stream manager
- Health check endpoint
- Stream statistics
- Basic metrics collection

**Cyrex Integration** (`diri-cyrex/app/integrations/streaming/`):
- Event publisher exists
- Can publish inference events
- Can subscribe to model events

**Helox Integration** (`diri-helox/integrations/`):
- Event publisher exists
- Can publish training events
- Can publish model-ready events

**Platform Services**:
- Some services have basic integration
- Most need complete implementation

### Your Responsibilities

**Taylor**: You own the AI/ML side - Cyrex and Helox. You make sure models train, publish events, and Cyrex consumes them.

**Harrison**: You own the platform services side - all 9 backend services. You make sure they publish and consume events correctly.

**Together**: You'll meet in Week 3 to integrate everything and test end-to-end.

---

## TAYLOR'S BOOTCAMP

**Complete Independent Path - Weeks 1-2**
**You work alone on this. Harrison is working on his own bootcamp.**

### Overview

You are responsible for:
1. **Helox (ML Training)**: Publishing training events and model-ready events
2. **Cyrex (AI Runtime)**: Subscribing to model events, publishing inference events, RAG events, agent events

**Your Goal**: By end of Week 2, Helox and Cyrex are fully integrated with Synapse, publishing and consuming all required events.

### Week 1: Foundation and Cyrex Integration

#### Day 1: Understanding Your Domain

**Objective**: Get familiar with Cyrex and Helox codebases and current Synapse integration.

**Tasks**:

1. **Explore Cyrex Codebase**:
   ```bash
   cd deepiri-platform/diri-cyrex
   ```
   - Read `app/integrations/streaming/event_publisher.py`
   - Read `app/core/model_manager.py`
   - Understand how models are loaded
   - Find where inference happens

2. **Explore Helox Codebase**:
   ```bash
   cd deepiri-platform/diri-helox
   ```
   - Read `integrations/synapse_event_publisher.py`
   - Read `training/unified_training_orchestrator.py`
   - Understand training loop structure
   - Find where checkpoints are saved

3. **Understand Current Integration**:
   - Read `deepiri-platform/docs/development/SYNAPSE_INTEGRATION_GUIDE.md`
   - Trace how Helox publishes model-ready events
   - Trace how Cyrex subscribes to model events
   - Understand event data structures

4. **Set Up Development Environment**:
   ```bash
   # Test Redis connection
   python -c "import redis; r = redis.Redis(host='localhost', port=6379); print(r.ping())"
   
   # Check if Redis Streams work
   python -c "import redis.asyncio as redis; import asyncio; async def test(): r = await redis.Redis(host='localhost', port=6379, decode_responses=True); await r.xadd('test', {'msg': 'hello'}); print('OK'); asyncio.run(test())"
   ```

**Deliverable**: 
- Document explaining current state
- List of what works and what doesn't
- Questions or blockers

#### Day 2: Redis Streams Deep Dive

**Objective**: Master Redis Streams - the foundation of everything you'll build.

**Tasks**:

1. **Learn Redis Streams Commands**:
   - XADD: Add events to stream
   - XREAD: Read events from stream
   - XGROUP: Create consumer groups
   - XREADGROUP: Read from consumer group
   - XINFO: Get stream information

2. **Create Test Scripts**:
   ```python
   # Create: test_redis_streams.py
   import redis.asyncio as redis
   import asyncio
   from datetime import datetime
   
   async def test_basic_streams():
       """Test basic stream operations"""
       r = await redis.Redis(host='localhost', port=6379, decode_responses=True)
       
       # Add event
       event_id = await r.xadd(
           "test-stream",
           {
               "event": "test",
               "data": "hello",
               "timestamp": datetime.utcnow().isoformat()
           }
       )
       print(f"Added event: {event_id}")
       
       # Read events
       messages = await r.xread({"test-stream": "0"}, count=10)
       for stream, events in messages:
           for event_id, data in events:
               print(f"Event {event_id}: {data}")
       
       await r.close()
   
   async def test_consumer_groups():
       """Test consumer groups"""
       r = await redis.Redis(host='localhost', port=6379, decode_responses=True)
       
       # Create consumer group
       try:
           await r.xgroup_create("test-stream", "test-group", id="0", mkstream=True)
       except redis.ResponseError as e:
           if "BUSYGROUP" not in str(e):
               raise
       
       # Read from consumer group
       messages = await r.xreadgroup(
           "test-group",
           "consumer-1",
           {"test-stream": ">"},
           count=10
       )
       
       for stream, events in messages:
           for event_id, data in events:
               print(f"Consumer received: {event_id} - {data}")
       
       await r.close()
   
   if __name__ == "__main__":
       asyncio.run(test_basic_streams())
       asyncio.run(test_consumer_groups())
   ```

3. **Run Tests**:
   - Execute test scripts
   - Verify events are added
   - Verify events are read
   - Verify consumer groups work

**Deliverable**: 
- Working test scripts
- Understanding of Redis Streams
- Ability to publish and consume events

#### Day 3: Model-Ready Event Subscription and Auto-Loading

**Objective**: Make Cyrex automatically load models when Helox publishes model-ready events.

**Current State**: Cyrex can subscribe but doesn't auto-load models.

**Tasks**:

1. **Examine Current Subscription**:
   - Read `diri-cyrex/app/integrations/streaming/event_publisher.py`
   - Find `subscribe_to_model_events` method
   - Understand what it does currently

2. **Understand Model Manager**:
   - Read `diri-cyrex/app/core/model_manager.py`
   - Understand `load_model` method
   - Understand model registry structure
   - Understand how models are stored

3. **Create Model Event Subscriber**:
   ```python
   # Create: diri-cyrex/app/integrations/streaming/model_event_subscriber.py
   """
   Subscribes to model-ready events and auto-loads models into Cyrex
   """
   import asyncio
   from typing import Optional
   from deepiri_modelkit import ModelReadyEvent
   from ..streaming.event_publisher import CyrexEventPublisher
   from ...core.model_manager import ModelManager
   from ...logging_config import get_logger
   
   logger = get_logger("cyrex.model_subscriber")
   
   class ModelEventSubscriber:
       """
       Subscribes to model-ready events from Helox and auto-loads models
       """
       
       def __init__(
           self,
           event_publisher: CyrexEventPublisher,
           model_manager: ModelManager
       ):
           self.event_publisher = event_publisher
           self.model_manager = model_manager
           self._running = False
           self._task: Optional[asyncio.Task] = None
       
       async def start(self):
           """Start listening for model events"""
           if self._running:
               logger.warning("Model subscriber already running")
               return
           
           self._running = True
           logger.info("Starting model event subscriber")
           
           self._task = asyncio.create_task(self._listen_loop())
       
       async def stop(self):
           """Stop listening for model events"""
           self._running = False
           if self._task:
               await self._task
           logger.info("Model event subscriber stopped")
       
       async def _listen_loop(self):
           """Main listening loop"""
           try:
               async for event in self.event_publisher.subscribe_to_model_events(
                   self._handle_event
               ):
                   if not self._running:
                       break
                   await self._handle_model_ready(event)
           except Exception as e:
               logger.error(f"Error in model subscriber loop: {e}")
               self._running = False
       
       async def _handle_event(self, event_data: dict):
           """Callback for event publisher"""
           # This is called by the event publisher
           pass
       
       async def _handle_model_ready(self, event: ModelReadyEvent):
           """Handle model-ready event by loading the model"""
           try:
               logger.info(
                   f"Model ready event received: {event.model_name} v{event.version}",
                   model_name=event.model_name,
                   version=event.version
               )
               
               # Check if model already loaded
               if self.model_manager.is_model_loaded(event.model_name, event.version):
                   logger.info(
                       f"Model {event.model_name} v{event.version} already loaded, skipping"
                   )
                   return
               
               # Load model from registry
               await self.model_manager.load_model(
                   model_name=event.model_name,
                   version=event.version,
                   registry_path=event.checkpoint_path
               )
               
               logger.info(
                   f"Model {event.model_name} v{event.version} loaded successfully",
                   model_name=event.model_name,
                   version=event.version
               )
               
           except Exception as e:
               logger.error(
                   f"Failed to load model {event.model_name}: {e}",
                   model_name=event.model_name,
                   error=str(e)
               )
               # Optionally publish error event
   ```

4. **Integrate into Cyrex Startup**:
   - Find Cyrex main application file (likely `app/main.py` or similar)
   - Initialize subscriber on startup
   - Start subscriber when Cyrex starts
   - Stop subscriber on shutdown

   ```python
   # In Cyrex main application file
   from app.integrations.streaming.model_event_subscriber import ModelEventSubscriber
   from app.integrations.streaming.event_publisher import get_event_publisher
   from app.core.model_manager import ModelManager
   
   # On startup
   event_publisher = await get_event_publisher()
   model_manager = ModelManager()  # Or however it's initialized
   model_subscriber = ModelEventSubscriber(event_publisher, model_manager)
   await model_subscriber.start()
   
   # On shutdown
   await model_subscriber.stop()
   ```

5. **Test**:
   - Start Cyrex
   - Publish a test model-ready event (manually or from Helox)
   - Verify Cyrex receives event
   - Verify model is loaded
   - Check logs for confirmation

**Deliverable**: 
- Working model auto-loading
- Test: Publish model-ready event, verify Cyrex loads it
- Logs showing successful loading

#### Day 4: Enhanced Inference Event Publishing

**Objective**: Publish comprehensive inference events with all relevant metrics.

**Current State**: Basic inference events are published but may be missing data.

**Tasks**:

1. **Examine Current Publishing**:
   - Find where inference events are published
   - Understand what data is currently included
   - Identify what's missing

2. **Enhance Event Publisher**:
   ```python
   # Enhance: diri-cyrex/app/integrations/streaming/event_publisher.py
   async def publish_inference(
       self,
       model_name: str,
       version: str,
       latency_ms: float,
       user_id: Optional[str] = None,
       request_id: Optional[str] = None,
       tokens_used: Optional[int] = None,
       cost: Optional[float] = None,
       confidence: Optional[float] = None,
       # NEW: Add these comprehensive fields
       input_length: Optional[int] = None,
       output_length: Optional[int] = None,
       model_type: Optional[str] = None,
       temperature: Optional[float] = None,
       top_p: Optional[float] = None,
       max_tokens: Optional[int] = None,
       error: Optional[str] = None,
       error_type: Optional[str] = None,
       metadata: Optional[Dict[str, Any]] = None
   ):
       """
       Publish comprehensive inference event with all metrics
       """
       await self.connect()
       
       event = InferenceEvent(
           event="inference-complete",
           source="cyrex",
           model_name=model_name,
           version=version,
           user_id=user_id,
           request_id=request_id,
           latency_ms=latency_ms,
           tokens_used=tokens_used,
           cost=cost,
           confidence=confidence,
           input_length=input_length,
           output_length=output_length,
           model_type=model_type,
           temperature=temperature,
           top_p=top_p,
           max_tokens=max_tokens,
           success=error is None,
           error=error,
           error_type=error_type,
           metadata=metadata or {}
       )
       
       await self.client.publish(
           StreamTopics.INFERENCE_EVENTS,
           event.model_dump()
       )
       
       logger.info(
           "inference_event_published",
           model=model_name,
           version=version,
           latency_ms=latency_ms,
           success=error is None
       )
   ```

3. **Find Inference Engine**:
   - Locate where inference actually happens
   - This might be in `app/core/inference_engine.py` or similar
   - Understand the inference flow

4. **Integrate Event Publishing**:
   ```python
   # In inference engine, after inference completes
   from app.integrations.streaming.event_publisher import get_event_publisher
   
   async def run_inference(self, model_name, input_data, **kwargs):
       """Run inference and publish event"""
       start_time = time.time()
       
       try:
           result = await self._do_inference(model_name, input_data, **kwargs)
           latency_ms = (time.time() - start_time) * 1000
           
           # Publish success event
           publisher = await get_event_publisher()
           await publisher.publish_inference(
               model_name=model_name,
               version=self.get_model_version(model_name),
               latency_ms=latency_ms,
               tokens_used=result.get('tokens_used'),
               confidence=result.get('confidence'),
               input_length=len(input_data),
               output_length=len(result.get('output', '')),
               model_type=result.get('model_type'),
               temperature=kwargs.get('temperature'),
               top_p=kwargs.get('top_p'),
               max_tokens=kwargs.get('max_tokens'),
               metadata=result.get('metadata')
           )
           
           return result
           
       except Exception as e:
           latency_ms = (time.time() - start_time) * 1000
           
           # Publish error event
           publisher = await get_event_publisher()
           await publisher.publish_inference(
               model_name=model_name,
               version=self.get_model_version(model_name),
               latency_ms=latency_ms,
               error=str(e),
               error_type=type(e).__name__
           )
           
           raise
   ```

5. **Test**:
   - Run an inference
   - Verify event is published
   - Check event contains all data
   - Verify event appears in Redis Streams

**Deliverable**: 
- Enhanced inference events with all metrics
- Test: Run inference, verify event contains complete data
- Documentation of all fields

#### Day 5: RAG and Agent Event Publishing

**Objective**: Publish events for RAG retrievals and agent decisions.

**Tasks**:

1. **Find RAG Pipeline**:
   - Locate RAG pipeline code
   - Understand retrieval flow
   - Identify where to add event publishing

2. **Create RAG Event Publisher**:
   ```python
   # Create: diri-cyrex/app/integrations/streaming/rag_event_publisher.py
   from datetime import datetime
   from typing import Dict, Any, Optional, List
   from ..streaming.event_publisher import CyrexEventPublisher
   from ...logging_config import get_logger
   
   logger = get_logger("cyrex.rag_events")
   
   class RAGEventPublisher:
       """Publishes RAG retrieval events"""
       
       def __init__(self, event_publisher: CyrexEventPublisher):
           self.event_publisher = event_publisher
       
       async def publish_rag_retrieval(
           self,
           query: str,
           top_k: int,
           retrieval_time_ms: float,
           documents_retrieved: int,
           model_name: Optional[str] = None,
           collection_name: Optional[str] = None,
           similarity_scores: Optional[List[float]] = None,
           metadata: Optional[Dict[str, Any]] = None
       ):
           """Publish RAG retrieval event"""
           await self.event_publisher.connect()
           
           event = {
               "event": "rag-retrieval",
               "source": "cyrex",
               "query": query[:200],  # Truncate for storage
               "top_k": top_k,
               "retrieval_time_ms": retrieval_time_ms,
               "documents_retrieved": documents_retrieved,
               "model_name": model_name,
               "collection_name": collection_name,
               "similarity_scores": similarity_scores,
               "timestamp": datetime.utcnow().isoformat(),
               "metadata": metadata or {}
           }
           
           await self.event_publisher.client.publish(
               StreamTopics.INFERENCE_EVENTS,  # Or create new stream
               event
           )
           
           logger.info(
               "rag_retrieval_published",
               query_length=len(query),
               documents_retrieved=documents_retrieved,
               retrieval_time_ms=retrieval_time_ms
           )
   ```

3. **Integrate into RAG Pipeline**:
   - Find where RAG retrieval happens
   - Add event publishing after retrieval
   - Include timing and metrics

4. **Create Agent Event Publisher**:
   ```python
   # Create: diri-cyrex/app/integrations/streaming/agent_event_publisher.py
   from datetime import datetime
   from typing import Dict, Any, Optional
   from ..streaming.event_publisher import CyrexEventPublisher
   from ...logging_config import get_logger
   
   logger = get_logger("cyrex.agent_events")
   
   class AgentEventPublisher:
       """Publishes agent decision events"""
       
       def __init__(self, event_publisher: CyrexEventPublisher):
           self.event_publisher = event_publisher
       
       async def publish_agent_decision(
           self,
           agent_name: str,
           decision_type: str,
           decision_data: Dict[str, Any],
           reasoning: Optional[str] = None,
           confidence: Optional[float] = None,
           execution_time_ms: Optional[float] = None,
           metadata: Optional[Dict[str, Any]] = None
       ):
           """Publish agent decision event"""
           await self.event_publisher.connect()
           
           event = {
               "event": "agent-decision",
               "source": "cyrex",
               "agent_name": agent_name,
               "decision_type": decision_type,
               "decision_data": decision_data,
               "reasoning": reasoning,
               "confidence": confidence,
               "execution_time_ms": execution_time_ms,
               "timestamp": datetime.utcnow().isoformat(),
               "metadata": metadata or {}
           }
           
           await self.event_publisher.client.publish(
               StreamTopics.PLATFORM_EVENTS,
               event
           )
           
           logger.info(
               "agent_decision_published",
               agent_name=agent_name,
               decision_type=decision_type
           )
   ```

5. **Integrate into Agents**:
   - Find agent code
   - Add event publishing after decisions
   - Include reasoning and confidence

6. **Test**:
   - Run RAG query, verify event
   - Run agent, verify event
   - Check events in Redis Streams

**Deliverable**: 
- RAG events being published
- Agent events being published
- Test: Run RAG and agent, verify events

### Week 2: Helox Integration and Advanced Features

#### Day 1: Training Orchestrator Integration

**Objective**: Integrate comprehensive event publishing into the unified training orchestrator.

**Tasks**:

1. **Examine Training Orchestrator**:
   - Read `diri-helox/training/unified_training_orchestrator.py`
   - Understand training loop structure
   - Identify all event publishing points

2. **Enhance Event Publisher**:
   ```python
   # Enhance: diri-helox/integrations/synapse_event_publisher.py
   async def publish_training_started(
       self,
       model_name: str,
       config: Dict[str, Any],
       dataset_info: Dict[str, Any],
       training_config: Dict[str, Any]
   ):
       """Publish training started event"""
       if not self._connected:
           await self.connect()
       
       event = {
           "event": "training-started",
           "model_name": model_name,
           "config": json.dumps(config),
           "dataset_info": json.dumps(dataset_info),
           "training_config": json.dumps(training_config),
           "timestamp": datetime.utcnow().isoformat()
       }
       
       await self.redis_client.xadd("training-events", event)
       logger.info(f"Published training-started: {model_name}")
   
   async def publish_training_progress(
       self,
       model_name: str,
       step: int,
       epoch: int,
       metrics: Dict[str, float],
       learning_rate: float,
       loss: float,
       elapsed_time_seconds: float
   ):
       """Publish training progress event"""
       if not self._connected:
           await self.connect()
       
       event = {
           "event": "training-progress",
           "model_name": model_name,
           "step": step,
           "epoch": epoch,
           "metrics": json.dumps(metrics),
           "learning_rate": learning_rate,
           "loss": loss,
           "elapsed_time_seconds": elapsed_time_seconds,
           "timestamp": datetime.utcnow().isoformat()
       }
       
       await self.redis_client.xadd("training-events", event)
   
   async def publish_training_completed(
       self,
       model_name: str,
       final_metrics: Dict[str, float],
       total_time_seconds: float,
       total_steps: int
   ):
       """Publish training completed event"""
       if not self._connected:
           await self.connect()
       
       event = {
           "event": "training-completed",
           "model_name": model_name,
           "final_metrics": json.dumps(final_metrics),
           "total_time_seconds": total_time_seconds,
           "total_steps": total_steps,
           "timestamp": datetime.utcnow().isoformat()
       }
       
       await self.redis_client.xadd("training-events", event)
       logger.info(f"Published training-completed: {model_name}")
   ```

3. **Integrate into Training Loop**:
   ```python
   # In unified_training_orchestrator.py
   async def train(self, train_loader, val_loader):
       """Training loop with event publishing"""
       # Publish training started
       await self.synapse_publisher.publish_training_started(
           model_name=self.model_config.name,
           config=self.model_config.dict(),
           dataset_info=self.data_config.dict(),
           training_config=self.training_config.dict()
       )
       
       start_time = time.time()
       
       for epoch in range(self.training_config.num_epochs):
           for step, batch in enumerate(train_loader):
               # Training step
               loss, metrics = await self.training_step(batch)
               
               # Publish progress every N steps
               if step % self.training_config.log_interval == 0:
                   await self.synapse_publisher.publish_training_progress(
                       model_name=self.model_config.name,
                       step=step,
                       epoch=epoch,
                       metrics=metrics,
                       learning_rate=self.optimizer.param_groups[0]['lr'],
                       loss=loss,
                       elapsed_time_seconds=time.time() - start_time
                   )
       
       # Publish training completed
       await self.synapse_publisher.publish_training_completed(
           model_name=self.model_config.name,
           final_metrics=final_metrics,
           total_time_seconds=time.time() - start_time,
           total_steps=total_steps
       )
   ```

4. **Test**:
   - Run a training job
   - Verify events are published
   - Check events in Redis Streams

**Deliverable**: 
- Training events published throughout training
- Test: Run training, verify events appear

#### Day 2: Real-Time Metrics Streaming

**Objective**: Stream training metrics in real-time for monitoring.

**Tasks**:

1. **Create Metrics Streaming Service**:
   ```python
   # Create: diri-helox/integrations/metrics_streaming.py
   import asyncio
   from typing import Dict, Any, Optional
   from .synapse_event_publisher import SynapseEventPublisher
   from ..observability.metrics_collector import MetricsCollector
   from ..logging_config import get_logger
   
   logger = get_logger("helox.metrics_streaming")
   
   class MetricsStreamingService:
       """Streams training metrics in real-time"""
       
       def __init__(
           self,
           event_publisher: SynapseEventPublisher,
           metrics_collector: Optional[MetricsCollector] = None
       ):
           self.event_publisher = event_publisher
           self.metrics_collector = metrics_collector
           self._streaming = False
           self._task: Optional[asyncio.Task] = None
       
       async def start_streaming(
           self,
           model_name: str,
           interval_seconds: int = 10
       ):
           """Start streaming metrics at interval"""
           if self._streaming:
               logger.warning("Metrics streaming already started")
               return
           
           self._streaming = True
           logger.info(f"Starting metrics streaming for {model_name}")
           
           self._task = asyncio.create_task(
               self._stream_loop(model_name, interval_seconds)
           )
       
       async def stop_streaming(self):
           """Stop streaming metrics"""
           self._streaming = False
           if self._task:
               await self._task
           logger.info("Metrics streaming stopped")
       
       async def _stream_loop(self, model_name: str, interval_seconds: int):
           """Main streaming loop"""
           while self._streaming:
               try:
                   metrics = self._collect_current_metrics()
                   
                   await self.event_publisher.publish_training_progress(
                       model_name=model_name,
                       step=metrics.get("step", 0),
                       epoch=metrics.get("epoch", 0),
                       metrics=metrics.get("metrics", {}),
                       learning_rate=metrics.get("learning_rate", 0.0),
                       loss=metrics.get("loss", 0.0),
                       elapsed_time_seconds=metrics.get("elapsed_time", 0.0)
                   )
                   
                   await asyncio.sleep(interval_seconds)
                   
               except Exception as e:
                   logger.error(f"Error in metrics streaming: {e}")
                   await asyncio.sleep(interval_seconds)
       
       def _collect_current_metrics(self) -> Dict[str, Any]:
           """Collect current training metrics"""
           if self.metrics_collector:
               return self.metrics_collector.get_current_metrics()
           
           # Fallback: return empty metrics
           return {
               "step": 0,
               "epoch": 0,
               "metrics": {},
               "learning_rate": 0.0,
               "loss": 0.0,
               "elapsed_time": 0.0
           }
   ```

2. **Integrate with Observability**:
   - Find observability/metrics collector
   - Connect to metrics streaming
   - Stream GPU metrics, memory usage, etc.

3. **Integrate into Training**:
   - Start streaming at training start
   - Stop streaming at training end

4. **Test**:
   - Run training with metrics streaming
   - Verify metrics are published regularly
   - Check metrics in Redis Streams

**Deliverable**: 
- Real-time metrics streaming
- Test: Monitor metrics during training

#### Day 3: Checkpoint and Evaluation Events

**Objective**: Publish events for checkpoints and evaluation results.

**Tasks**:

1. **Checkpoint Event Publishing**:
   ```python
   # Enhance: diri-helox/integrations/synapse_event_publisher.py
   async def publish_checkpoint(
       self,
       model_name: str,
       checkpoint_path: str,
       step: int,
       epoch: int,
       metrics: Dict[str, float],
       checkpoint_size_mb: float,
       is_best: bool = False
   ):
       """Publish checkpoint created event"""
       if not self._connected:
           await self.connect()
       
       event = {
           "event": "checkpoint-created",
           "model_name": model_name,
           "checkpoint_path": checkpoint_path,
           "step": step,
           "epoch": epoch,
           "metrics": json.dumps(metrics),
           "checkpoint_size_mb": checkpoint_size_mb,
           "is_best": is_best,
           "timestamp": datetime.utcnow().isoformat()
       }
       
       await self.redis_client.xadd("training-events", event)
       logger.info(f"Published checkpoint: {model_name} at step {step}")
   ```

2. **Evaluation Event Publishing**:
   ```python
   async def publish_evaluation(
       self,
       model_name: str,
       evaluation_type: str,
       metrics: Dict[str, float],
       dataset_name: str,
       evaluation_time_seconds: float,
       num_samples: Optional[int] = None
   ):
       """Publish evaluation completed event"""
       if not self._connected:
           await self.connect()
       
       event = {
           "event": "evaluation-completed",
           "model_name": model_name,
           "evaluation_type": evaluation_type,
           "metrics": json.dumps(metrics),
           "dataset_name": dataset_name,
           "evaluation_time_seconds": evaluation_time_seconds,
           "num_samples": num_samples,
           "timestamp": datetime.utcnow().isoformat()
       }
       
       await self.redis_client.xadd("training-events", event)
       logger.info(f"Published evaluation: {model_name} on {dataset_name}")
   ```

3. **Integrate into Training**:
   - Add checkpoint events when checkpoints are saved
   - Add evaluation events when evaluations complete
   - Connect to evaluation harness

4. **Test**:
   - Run training with checkpoints
   - Run evaluation
   - Verify events are published

**Deliverable**: 
- Checkpoint events
- Evaluation events
- Test: Run training with checkpoints, verify events

#### Day 4: Model Health Monitoring

**Objective**: Monitor model health in Cyrex and publish alerts.

**Tasks**:

1. **Create Health Monitor**:
   ```python
   # Create: diri-cyrex/app/integrations/model_health_monitor.py
   import asyncio
   from typing import Dict, Any, Optional, List
   from datetime import datetime
   from ..streaming.event_publisher import CyrexEventPublisher
   from ...core.model_manager import ModelManager
   from ...logging_config import get_logger
   
   logger = get_logger("cyrex.health_monitor")
   
   class ModelHealthMonitor:
       """Monitors model health and publishes alerts"""
       
       def __init__(
           self,
           event_publisher: CyrexEventPublisher,
           model_manager: ModelManager
       ):
           self.event_publisher = event_publisher
           self.model_manager = model_manager
           self._monitoring: Dict[str, asyncio.Task] = {}
       
       async def start_monitoring(
           self,
           model_name: str,
           check_interval_seconds: int = 60
       ):
           """Start monitoring a model"""
           if model_name in self._monitoring:
               logger.warning(f"Already monitoring {model_name}")
               return
           
           task = asyncio.create_task(
               self._monitor_loop(model_name, check_interval_seconds)
           )
           self._monitoring[model_name] = task
           logger.info(f"Started monitoring {model_name}")
       
       async def stop_monitoring(self, model_name: str):
           """Stop monitoring a model"""
           if model_name in self._monitoring:
               self._monitoring[model_name].cancel()
               del self._monitoring[model_name]
               logger.info(f"Stopped monitoring {model_name}")
       
       async def _monitor_loop(self, model_name: str, interval: int):
           """Main monitoring loop"""
           while True:
               try:
                   health = await self._check_model_health(model_name)
                   
                   if health["status"] != "healthy":
                       await self._publish_health_alert(model_name, health)
                   
                   await asyncio.sleep(interval)
                   
               except asyncio.CancelledError:
                   break
               except Exception as e:
                   logger.error(f"Error monitoring {model_name}: {e}")
                   await asyncio.sleep(interval)
       
       async def _check_model_health(self, model_name: str) -> Dict[str, Any]:
           """Check model health metrics"""
           issues = []
           
           # Check if model is loaded
           if not self.model_manager.is_model_loaded(model_name):
               issues.append("Model not loaded")
           
           # Check memory usage
           memory_usage = self._get_model_memory_usage(model_name)
           if memory_usage > 0.9:  # 90% threshold
               issues.append(f"High memory usage: {memory_usage:.2%}")
           
           # Check error rate
           error_rate = self._get_model_error_rate(model_name)
           if error_rate > 0.1:  # 10% threshold
               issues.append(f"High error rate: {error_rate:.2%}")
           
           # Check latency
           avg_latency = self._get_avg_latency(model_name)
           if avg_latency > 5000:  # 5 seconds threshold
               issues.append(f"High latency: {avg_latency}ms")
           
           return {
               "status": "healthy" if not issues else "unhealthy",
               "issues": issues,
               "memory_usage": memory_usage,
               "error_rate": error_rate,
               "avg_latency": avg_latency
           }
       
       def _get_model_memory_usage(self, model_name: str) -> float:
           """Get model memory usage (0-1)"""
           # Implement memory checking
           return 0.0
       
       def _get_model_error_rate(self, model_name: str) -> float:
           """Get model error rate (0-1)"""
           # Implement error rate tracking
           return 0.0
       
       def _get_avg_latency(self, model_name: str) -> float:
           """Get average latency in ms"""
           # Implement latency tracking
           return 0.0
       
       async def _publish_health_alert(
           self,
           model_name: str,
           health: Dict[str, Any]
       ):
           """Publish health alert event"""
           await self.event_publisher.publish_platform_event({
               "event": "model-health-alert",
               "model_name": model_name,
               "status": health["status"],
               "issues": health["issues"],
               "memory_usage": health.get("memory_usage"),
               "error_rate": health.get("error_rate"),
               "avg_latency": health.get("avg_latency"),
               "timestamp": datetime.utcnow().isoformat()
           })
   ```

2. **Integrate Health Monitoring**:
   - Start monitoring when models are loaded
   - Stop monitoring when models are unloaded

3. **Test**:
   - Load a model
   - Simulate health issues
   - Verify alerts are published

**Deliverable**: 
- Model health monitoring
- Test: Simulate issues, verify alerts

#### Day 5: Error Handling and Retry Logic

**Objective**: Add robust error handling and retry logic.

**Tasks**:

1. **Add Retry Logic**:
   ```python
   # Enhance: diri-cyrex/app/integrations/streaming/event_publisher.py
   from tenacity import retry, stop_after_attempt, wait_exponential
   
   @retry(
       stop=stop_after_attempt(3),
       wait=wait_exponential(multiplier=1, min=4, max=10)
   )
   async def publish_with_retry(self, stream: str, event: Dict[str, Any]):
       """Publish event with retry logic"""
       try:
           await self.client.publish(stream, event)
       except Exception as e:
           logger.error(f"Failed to publish event: {e}")
           raise
   ```

2. **Add Error Event Publishing**:
   - Publish events when errors occur
   - Include error context and stack traces

3. **Add Dead Letter Queue**:
   - Route failed events to DLQ
   - Add monitoring for DLQ

4. **Test**:
   - Simulate Redis failures
   - Verify retry logic works
   - Verify DLQ routing

**Deliverable**: 
- Robust error handling
- Retry logic
- DLQ for failed events

### Taylor's Week 2 Summary

**By end of Week 2, you should have**:
- ✅ Helox publishing all training events
- ✅ Helox publishing model-ready events
- ✅ Cyrex subscribing to model events
- ✅ Cyrex auto-loading models
- ✅ Cyrex publishing comprehensive inference events
- ✅ Cyrex publishing RAG events
- ✅ Cyrex publishing agent events
- ✅ Model health monitoring
- ✅ Error handling and retry logic

**Next**: You'll meet Harrison in Week 3 for integration testing.

---

## HARRISON'S BOOTCAMP

**Complete Independent Path - Weeks 1-2**
**You work alone on this. Taylor is working on his own bootcamp.**

### Overview

You are responsible for:
1. **All 9 Platform Services**: Making them publish and consume events correctly
2. **Event Consumption**: Services that need to react to events (Analytics, Notifications, Realtime Gateway)
3. **Event Publishing**: Services that generate events (Auth, Task, Engagement, etc.)

**Your Goal**: By end of Week 2, all 9 platform services are fully integrated with Synapse, publishing and consuming all required events.

### Week 1: Foundation and Service Integration

#### Day 1: Understanding Platform Services

**Objective**: Get familiar with all platform services and their current state.

**Tasks**:

1. **List All Services**:
   ```bash
   cd deepiri-platform/platform-services/backend
   ls -la
   ```
   
   You should see:
   - deepiri-api-gateway
   - deepiri-auth-service
   - deepiri-task-orchestrator
   - deepiri-challenge-service
   - deepiri-engagement-service
   - deepiri-platform-analytics-service
   - deepiri-external-bridge-service
   - deepiri-notification-service
   - deepiri-realtime-gateway

2. **Read Each Service's README**:
   - Understand what each service does
   - Understand current functionality
   - Note any existing Synapse integration

3. **Check Current Integration**:
   ```bash
   # Search for existing streaming/event code
   grep -r "streaming\|eventPublisher\|Synapse" deepiri-platform/platform-services/backend/*/src/
   ```

4. **Understand Shared Utils**:
   ```bash
   cd deepiri-platform/platform-services/shared/deepiri-shared-utils
   ```
   - Read README.md
   - Read `src/streaming/StreamingClient.ts`
   - Understand event types and schemas

5. **Create Integration Status Document**:
   - List each service
   - Current integration status (Yes/No/Partial)
   - What events it should publish
   - What events it should consume
   - Priority (High/Medium/Low)

**Deliverable**: 
- Integration status spreadsheet/document
- Understanding of all services
- List of what needs to be built

#### Day 2: Understanding Event Publishing Pattern

**Objective**: Master the event publishing pattern for platform services.

**Tasks**:

1. **Study Shared Utils StreamingClient**:
   ```typescript
   // Read: platform-services/shared/deepiri-shared-utils/src/streaming/StreamingClient.ts
   // Understand:
   // - How to initialize client
   // - How to connect
   // - How to publish events
   // - How to subscribe to events
   // - Event types (StreamTopics)
   // - Event schemas (StreamEvent)
   ```

2. **Check Existing Integration** (if any):
   - Find services with `src/streaming/` directory
   - Understand the pattern they use
   - Note what works and what doesn't

3. **Create Template Event Publisher**:
   ```typescript
   // Create: event-publisher-template.ts
   // This will be your template for all services
   import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
   import { config } from '../config/environment';
   import { logger } from '../utils/logger';
   
   let streamingClient: StreamingClient | null = null;
   
   export async function initializeEventPublisher(): Promise<void> {
       try {
           streamingClient = new StreamingClient(
               config.redis.host,
               config.redis.port,
               config.redis.password
           );
           await streamingClient.connect();
           logger.info('[Service Name] Connected to Redis Streams');
       } catch (error: any) {
           logger.error('[Service Name] Failed to initialize event publisher:', error);
           throw error;
       }
   }
   
   export async function publishEvent(
       eventType: string,
       action: string,
       data: any
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: eventType,
           timestamp: new Date().toISOString(),
           source: 'service-name',
           service: 'service-name',
           action: action,
           data: data
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
       logger.info(`[Service Name] Published ${eventType}: ${action}`);
   }
   ```

4. **Test Template**:
   - Create test script
   - Publish test event
   - Verify it appears in Redis Streams

**Deliverable**: 
- Working event publisher template
- Understanding of publishing pattern
- Test script that works

#### Day 3: Task Orchestrator Service

**Objective**: Add complete event publishing to Task Orchestrator.

**Tasks**:

1. **Examine Task Orchestrator**:
   ```bash
   cd deepiri-platform/platform-services/backend/deepiri-task-orchestrator
   ```
   - Read README.md
   - Explore `src/` directory
   - Understand task lifecycle
   - Find task creation endpoint
   - Find task completion logic

2. **Create Event Publisher**:
   ```typescript
   // Create: src/streaming/eventPublisher.ts
   import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
   import { config } from '../config/environment';
   import { logger } from '../utils/logger';
   
   let streamingClient: StreamingClient | null = null;
   
   export async function initializeEventPublisher(): Promise<void> {
       try {
           streamingClient = new StreamingClient(
               config.redis.host,
               config.redis.port,
               config.redis.password
           );
           await streamingClient.connect();
           logger.info('[Task Orchestrator] Connected to Redis Streams');
       } catch (error: any) {
           logger.error('[Task Orchestrator] Failed to initialize event publisher:', error);
           throw error;
       }
   }
   
   export async function publishTaskCreated(
       taskId: string,
       taskData: any
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: 'task-created',
           timestamp: new Date().toISOString(),
           source: 'task-orchestrator',
           service: 'task-orchestrator',
           action: 'task-created',
           data: {
               taskId,
               userId: taskData.userId,
               title: taskData.title,
               status: taskData.status,
               createdAt: taskData.createdAt
           }
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
       logger.info(`[Task Orchestrator] Published task-created: ${taskId}`);
   }
   
   export async function publishTaskUpdated(
       taskId: string,
       updates: any
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: 'task-updated',
           timestamp: new Date().toISOString(),
           source: 'task-orchestrator',
           service: 'task-orchestrator',
           action: 'task-updated',
           data: {
               taskId,
               ...updates
           }
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
       logger.info(`[Task Orchestrator] Published task-updated: ${taskId}`);
   }
   
   export async function publishTaskCompleted(
       taskId: string,
       result: any
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: 'task-completed',
           timestamp: new Date().toISOString(),
           source: 'task-orchestrator',
           service: 'task-orchestrator',
           action: 'task-completed',
           data: {
               taskId,
               completedAt: new Date().toISOString(),
               result: result
           }
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
       logger.info(`[Task Orchestrator] Published task-completed: ${taskId}`);
   }
   
   export async function publishTaskFailed(
       taskId: string,
       error: string
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: 'task-failed',
           timestamp: new Date().toISOString(),
           source: 'task-orchestrator',
           service: 'task-orchestrator',
           action: 'task-failed',
           data: {
               taskId,
               error: error,
               failedAt: new Date().toISOString()
           }
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
       logger.error(`[Task Orchestrator] Published task-failed: ${taskId}`);
   }
   ```

3. **Integrate into Service**:
   ```typescript
   // In task creation endpoint (src/routes/tasks.ts or similar)
   import { publishTaskCreated } from '../streaming/eventPublisher';
   
   router.post('/tasks', async (req, res) => {
       try {
           // Create task
           const task = await taskService.createTask(req.body);
           
           // Publish event
           await publishTaskCreated(task.id, task);
           
           res.status(201).json({ success: true, data: task });
       } catch (error) {
           res.status(500).json({ error: error.message });
       }
   });
   
   // In task completion logic
   import { publishTaskCompleted, publishTaskFailed } from '../streaming/eventPublisher';
   
   async function completeTask(taskId: string) {
       try {
           const result = await taskService.completeTask(taskId);
           await publishTaskCompleted(taskId, result);
       } catch (error) {
           await publishTaskFailed(taskId, error.message);
           throw error;
       }
   }
   ```

4. **Initialize on Startup**:
   ```typescript
   // In src/server.ts
   import { initializeEventPublisher } from './streaming/eventPublisher';
   
   // On server startup
   await initializeEventPublisher().catch((err) => {
       logger.error('Failed to initialize event publisher:', err);
   });
   ```

5. **Test**:
   - Start service
   - Create a task
   - Verify event is published
   - Check Redis Streams

**Deliverable**: 
- Task Orchestrator publishing events
- Test: Create task, verify event appears

#### Day 4: Analytics and Notification Services (Event Consumers)

**Objective**: Make Analytics and Notification services consume events.

**Tasks**:

1. **Analytics Service - Event Consumer**:
   ```typescript
   // Create: deepiri-platform-analytics-service/src/streaming/eventConsumer.ts
   import { StreamingClient, StreamTopics } from '@deepiri/shared-utils';
   import { config } from '../config/environment';
   import { logger } from '../utils/logger';
   import { aggregateInferenceMetrics } from '../services/analyticsService';
   
   let streamingClient: StreamingClient | null = null;
   
   export async function initializeEventConsumer(): Promise<void> {
       try {
           streamingClient = new StreamingClient(
               config.redis.host,
               config.redis.port,
               config.redis.password
           );
           await streamingClient.connect();
           logger.info('[Analytics] Connected to Redis Streams');
       } catch (error: any) {
           logger.error('[Analytics] Failed to initialize event consumer:', error);
           throw error;
       }
   }
   
   export async function startInferenceEventConsumer(): Promise<void> {
       if (!streamingClient) await initializeEventConsumer();
       
       // Subscribe to inference events
       await streamingClient!.subscribe(
           StreamTopics.INFERENCE_EVENTS,
           async (event) => {
               try {
                   logger.info('[Analytics] Received inference event', {
                       model: event.data?.model_name,
                       latency: event.data?.latency_ms
                   });
                   
                   // Aggregate metrics
                   await aggregateInferenceMetrics({
                       modelName: event.data?.model_name,
                       version: event.data?.version,
                       latencyMs: event.data?.latency_ms,
                       tokensUsed: event.data?.tokens_used,
                       cost: event.data?.cost,
                       confidence: event.data?.confidence,
                       success: event.data?.success,
                       timestamp: event.timestamp
                   });
                   
               } catch (error: any) {
                   logger.error('[Analytics] Error processing inference event:', error);
               }
           },
           'analytics-service',
           'analytics-1'
       );
       
       logger.info('[Analytics] Started inference event consumer');
   }
   
   export async function startTrainingEventConsumer(): Promise<void> {
       if (!streamingClient) await initializeEventConsumer();
       
       // Subscribe to training events
       await streamingClient!.subscribe(
           StreamTopics.TRAINING_EVENTS,
           async (event) => {
               try {
                   logger.info('[Analytics] Received training event', {
                       event: event.event,
                       model: event.data?.model_name
                   });
                   
                   // Process training metrics
                   await processTrainingMetrics(event);
                   
               } catch (error: any) {
                   logger.error('[Analytics] Error processing training event:', error);
               }
           },
           'analytics-service',
           'analytics-1'
       );
       
       logger.info('[Analytics] Started training event consumer');
   }
   ```

2. **Notification Service - Event Consumer**:
   ```typescript
   // Create: deepiri-notification-service/src/streaming/eventConsumer.ts
   import { StreamingClient, StreamTopics } from '@deepiri/shared-utils';
   import { config } from '../config/environment';
   import { logger } from '../utils/logger';
   import { sendNotification } from '../services/notificationService';
   
   let streamingClient: StreamingClient | null = null;
   
   export async function initializeEventConsumer(): Promise<void> {
       try {
           streamingClient = new StreamingClient(
               config.redis.host,
               config.redis.port,
               config.redis.password
           );
           await streamingClient.connect();
           logger.info('[Notification] Connected to Redis Streams');
       } catch (error: any) {
           logger.error('[Notification] Failed to initialize event consumer:', error);
           throw error;
       }
   }
   
   export async function startPlatformEventConsumer(): Promise<void> {
       if (!streamingClient) await initializeEventConsumer();
       
       // Subscribe to platform events
       await streamingClient!.subscribe(
           StreamTopics.PLATFORM_EVENTS,
           async (event) => {
               try {
                   // Check if notification needed
                   if (shouldNotify(event)) {
                       await sendNotification({
                           userId: event.data?.userId,
                           type: getNotificationType(event),
                           title: getNotificationTitle(event),
                           message: getNotificationMessage(event),
                           data: event.data
                       });
                   }
                   
               } catch (error: any) {
                   logger.error('[Notification] Error processing platform event:', error);
               }
           },
           'notification-service',
           'notification-1'
       );
       
       logger.info('[Notification] Started platform event consumer');
   }
   
   function shouldNotify(event: any): boolean {
       // Determine if event requires notification
       const notifyEvents = [
           'task-completed',
           'task-failed',
           'challenge-completed',
           'achievement-unlocked'
       ];
       return notifyEvents.includes(event.event);
   }
   
   function getNotificationType(event: any): string {
       // Map event to notification type
       const typeMap: Record<string, string> = {
           'task-completed': 'success',
           'task-failed': 'error',
           'challenge-completed': 'achievement',
           'achievement-unlocked': 'achievement'
       };
       return typeMap[event.event] || 'info';
   }
   
   function getNotificationTitle(event: any): string {
       // Generate notification title from event
       const titleMap: Record<string, string> = {
           'task-completed': 'Task Completed',
           'task-failed': 'Task Failed',
           'challenge-completed': 'Challenge Completed',
           'achievement-unlocked': 'Achievement Unlocked'
       };
       return titleMap[event.event] || 'New Update';
   }
   
   function getNotificationMessage(event: any): string {
       // Generate notification message from event
       if (event.event === 'task-completed') {
           return `Task "${event.data?.title}" has been completed`;
       }
       // Add more mappings
       return 'You have a new update';
   }
   ```

3. **Integrate into Services**:
   ```typescript
   // In Analytics service server.ts
   import { startInferenceEventConsumer, startTrainingEventConsumer } from './streaming/eventConsumer';
   
   // On startup
   await startInferenceEventConsumer();
   await startTrainingEventConsumer();
   
   // In Notification service server.ts
   import { startPlatformEventConsumer } from './streaming/eventConsumer';
   
   // On startup
   await startPlatformEventConsumer();
   ```

4. **Test**:
   - Start Analytics service
   - Publish inference event (manually or from Cyrex)
   - Verify Analytics receives and processes it
   - Start Notification service
   - Publish platform event
   - Verify Notification receives and sends notification

**Deliverable**: 
- Analytics consuming inference and training events
- Notifications consuming platform events
- Test: Publish events, verify consumption

#### Day 5: Auth, Engagement, and External Bridge Services

**Objective**: Add event publishing to Auth, Engagement, and External Bridge services.

**Tasks**:

1. **Auth Service Events**:
   ```typescript
   // Create: deepiri-auth-service/src/streaming/eventPublisher.ts
   // Similar pattern to Task Orchestrator
   
   export async function publishUserLoggedIn(
       userId: string,
       email: string,
       loginMethod: string
   ): Promise<void> {
       // Publish login event
   }
   
   export async function publishUserLoggedOut(
       userId: string
   ): Promise<void> {
       // Publish logout event
   }
   
   export async function publishTokenRefreshed(
       userId: string
   ): Promise<void> {
       // Publish token refresh event
   }
   
   export async function publishUserRegistered(
       userId: string,
       email: string
   ): Promise<void> {
       // Publish registration event
   }
   ```

2. **Engagement Service Events**:
   ```typescript
   // Create: deepiri-engagement-service/src/streaming/eventPublisher.ts
   
   export async function publishUserInteraction(
       userId: string,
       interactionType: string,
       data: any
   ): Promise<void> {
       // Publish interaction event
   }
   
   export async function publishAchievementUnlocked(
       userId: string,
       achievementId: string,
       achievementName: string
   ): Promise<void> {
       // Publish achievement event
   }
   
   export async function publishLeaderboardUpdated(
       leaderboardId: string,
       updates: any
   ): Promise<void> {
       // Publish leaderboard update event
   }
   ```

3. **External Bridge Service Events**:
   ```typescript
   // Create: deepiri-external-bridge-service/src/streaming/eventPublisher.ts
   
   export async function publishExternalAPICall(
       integrationName: string,
       endpoint: string,
       method: string,
       statusCode: number,
       latencyMs: number
   ): Promise<void> {
       // Publish external API call event
   }
   
   export async function publishWebhookReceived(
       integrationName: string,
       webhookType: string,
       data: any
   ): Promise<void> {
       // Publish webhook event
   }
   
   export async function publishIntegrationStatusChanged(
       integrationName: string,
       status: string
   ): Promise<void> {
       // Publish integration status event
   }
   ```

4. **Integrate into Each Service**:
   - Add event publishing to relevant endpoints
   - Initialize on startup
   - Test each service

5. **Test**:
   - Test Auth: Login, verify event
   - Test Engagement: Trigger interaction, verify event
   - Test External Bridge: Make API call, verify event

**Deliverable**: 
- Auth service publishing events
- Engagement service publishing events
- External Bridge service publishing events
- Test: Trigger actions, verify events

### Week 2: Advanced Integration and Remaining Services

#### Day 1: API Gateway Integration

**Objective**: Add event publishing for API metrics and routing.

**Tasks**:

1. **Create API Metrics Middleware**:
   ```typescript
   // Create: deepiri-api-gateway/src/middleware/apiMetrics.ts
   import { Request, Response, NextFunction } from 'express';
   import { publishAPIMetric } from '../streaming/eventPublisher';
   
   export function apiMetricsMiddleware(
       req: Request,
       res: Response,
       next: NextFunction
   ) {
       const startTime = Date.now();
       const userId = (req as any).user?.id;
       
       res.on('finish', async () => {
           const latencyMs = Date.now() - startTime;
           
           await publishAPIMetric(
               req.path,
               req.method,
               res.statusCode,
               latencyMs,
               userId
           );
       });
       
       next();
   }
   ```

2. **Event Publisher**:
   ```typescript
   // Create: deepiri-api-gateway/src/streaming/eventPublisher.ts
   
   export async function publishAPIMetric(
       endpoint: string,
       method: string,
       statusCode: number,
       latencyMs: number,
       userId?: string
   ): Promise<void> {
       if (!streamingClient) await initializeEventPublisher();
       
       const event: StreamEvent = {
           event: 'api-request',
           timestamp: new Date().toISOString(),
           source: 'api-gateway',
           service: 'api-gateway',
           action: 'api-request',
           data: {
               endpoint,
               method,
               statusCode,
               latencyMs,
               userId
           }
       };
       
       await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
   }
   ```

3. **Integrate Middleware**:
   ```typescript
   // In server.ts
   import { apiMetricsMiddleware } from './middleware/apiMetrics';
   
   app.use(apiMetricsMiddleware);
   ```

4. **Test**:
   - Make API calls
   - Verify events are published
   - Check metrics in Redis Streams

**Deliverable**: 
- API Gateway publishing metrics
- Test: Make API calls, verify events

#### Day 2: Challenge Service Integration

**Objective**: Add event publishing and consumption for Challenge service.

**Tasks**:

1. **Challenge Event Publishing**:
   ```typescript
   // Create: deepiri-challenge-service/src/streaming/eventPublisher.ts
   
   export async function publishChallengeCreated(
       challengeId: string,
       challengeData: any
   ): Promise<void> {
       // Publish challenge created event
   }
   
   export async function publishChallengeStarted(
       challengeId: string,
       userId: string
   ): Promise<void> {
       // Publish challenge started event
   }
   
   export async function publishChallengeCompleted(
       challengeId: string,
       userId: string,
       result: any
   ): Promise<void> {
       // Publish challenge completed event
   }
   
   export async function publishChallengeFailed(
       challengeId: string,
       userId: string,
       error: string
   ): Promise<void> {
       // Publish challenge failed event
   }
   ```

2. **Consume Inference Events**:
   ```typescript
   // Create: deepiri-challenge-service/src/streaming/eventConsumer.ts
   
   export async function startInferenceEventConsumer(): Promise<void> {
       // Subscribe to inference events
       await streamingClient!.subscribe(
           StreamTopics.INFERENCE_EVENTS,
           async (event) => {
               // Check if this inference is for a challenge
               if (event.data?.challengeId) {
                   await validateChallengeSolution(
                       event.data.challengeId,
                       event.data
                   );
               }
           },
           'challenge-service',
           'challenge-1'
       );
   }
   ```

3. **Integrate**:
   - Add event publishing to challenge endpoints
   - Add event consumer on startup
   - Test

**Deliverable**: 
- Challenge service fully integrated
- Test: Create challenge, verify events

#### Day 3: Realtime Gateway Enhancement

**Objective**: Enhance Realtime Gateway to consume and forward all relevant events.

**Tasks**:

1. **Multiple Event Streams**:
   ```typescript
   // Enhance: deepiri-realtime-gateway/src/streaming/eventConsumer.ts
   
   export async function startAllEventConsumers(): Promise<void> {
       // Subscribe to platform events
       await startPlatformEventConsumer();
       
       // Subscribe to inference events
       await startInferenceEventConsumer();
       
       // Subscribe to training events
       await startTrainingEventConsumer();
   }
   
   async function startPlatformEventConsumer(): Promise<void> {
       await streamingClient!.subscribe(
           StreamTopics.PLATFORM_EVENTS,
           async (event) => {
               await broadcastToWebSocketClients('platform-events', event);
           },
           'realtime-gateway',
           'realtime-1'
       );
   }
   
   async function startInferenceEventConsumer(): Promise<void> {
       await streamingClient!.subscribe(
           StreamTopics.INFERENCE_EVENTS,
           async (event) => {
               await broadcastToWebSocketClients('inference-events', event);
           },
           'realtime-gateway',
           'realtime-1'
       );
   }
   
   async function startTrainingEventConsumer(): Promise<void> {
       await streamingClient!.subscribe(
           StreamTopics.TRAINING_EVENTS,
           async (event) => {
               await broadcastToWebSocketClients('training-events', event);
           },
           'realtime-gateway',
           'realtime-1'
       );
   }
   
   async function broadcastToWebSocketClients(
       channel: string,
       event: any
   ): Promise<void> {
       // Broadcast to WebSocket clients subscribed to this channel
       // Filter by client subscriptions
   }
   ```

2. **WebSocket Broadcasting**:
   - Forward events to WebSocket clients
   - Filter events by client subscription
   - Handle client disconnections

3. **Test**:
   - Connect WebSocket client
   - Publish events
   - Verify WebSocket delivery

**Deliverable**: 
- Realtime Gateway consuming all relevant events
- Test: Publish events, verify WebSocket delivery

#### Day 4: Error Handling and Retry Logic

**Objective**: Add robust error handling across all services.

**Tasks**:

1. **Add Retry Logic**:
   ```typescript
   // Create: shared utility for retry
   // platform-services/shared/deepiri-shared-utils/src/streaming/retry.ts
   import { retry } from 'ts-retry';
   
   export async function publishWithRetry(
       client: StreamingClient,
       stream: string,
       event: StreamEvent,
       maxRetries: number = 3
   ): Promise<void> {
       await retry(
           async () => {
               await client.publish(stream, event);
           },
           {
               maxTry: maxRetries,
               delay: 1000,
               backoff: 'EXPONENTIAL'
           }
       );
   }
   ```

2. **Add Error Event Publishing**:
   - Publish events when errors occur
   - Include error context

3. **Add Dead Letter Queue**:
   - Route failed events to DLQ
   - Add monitoring

4. **Test**:
   - Simulate failures
   - Verify retry logic
   - Verify DLQ routing

**Deliverable**: 
- Robust error handling
- Retry logic
- DLQ for failed events

#### Day 5: Health Monitoring

**Objective**: Add health monitoring for event publishing/consuming.

**Tasks**:

1. **Health Checks**:
   ```typescript
   // Add to each service
   export async function checkEventPublisherHealth(): Promise<boolean> {
       try {
           await streamingClient!.ping();
           return true;
       } catch {
           return false;
       }
   }
   ```

2. **Metrics Collection**:
   - Track events published
   - Track events consumed
   - Track errors

3. **Alerting**:
   - Alert on connection failures
   - Alert on high error rates
   - Alert on consumer lag

4. **Test**:
   - Check health endpoints
   - Verify metrics
   - Test alerting

**Deliverable**: 
- Health monitoring
- Metrics collection
- Alerting system

### Harrison's Week 2 Summary

**By end of Week 2, you should have**:
- ✅ All 9 services publishing events
- ✅ Analytics consuming inference and training events
- ✅ Notifications consuming platform events
- ✅ Realtime Gateway consuming and forwarding events
- ✅ API Gateway publishing metrics
- ✅ Challenge service integrated
- ✅ Error handling and retry logic
- ✅ Health monitoring

**Next**: You'll meet Taylor in Week 3 for integration testing.

---

## CONVERGENCE POINT

**Week 3: Where You Collide**
**Taylor and Harrison work together on integration testing and coordination.**

### Day 1: End-to-End Integration Testing

**Objective**: Test complete event flow from Helox → Cyrex → Platform Services.

**Tasks** (Both work together):

1. **Test Model Training Flow**:
   - **Taylor**: Start training in Helox
   - **Both**: Verify training events are published (check Redis Streams)
   - **Harrison**: Verify Analytics service receives training events
   - **Taylor**: Complete training, publish model-ready event
   - **Both**: Verify model-ready event appears in Redis Streams
   - **Taylor**: Verify Cyrex receives model-ready event and auto-loads model
   - **Harrison**: Verify Platform Services can use the model (via API Gateway)

2. **Test Inference Flow**:
   - **Harrison**: Trigger inference via API Gateway
   - **Taylor**: Verify Cyrex publishes inference event
   - **Both**: Verify inference event appears in Redis Streams
   - **Harrison**: Verify Analytics receives inference event
   - **Harrison**: Verify Notifications can trigger on inference events

3. **Test Platform Event Flow**:
   - **Harrison**: Create task via Task Orchestrator
   - **Both**: Verify task-created event is published
   - **Harrison**: Verify Notifications receives event and sends notification
   - **Harrison**: Verify Realtime Gateway forwards event to WebSocket clients

4. **Test Error Scenarios**:
   - **Both**: Simulate Redis failure
   - **Both**: Verify error handling works
   - **Both**: Verify DLQ routing works
   - **Both**: Verify services recover gracefully

**Deliverable**: 
- End-to-end test results document
- List of bugs found
- List of fixes needed

### Day 2: Performance Testing

**Objective**: Test system under load.

**Tasks** (Both work together):

1. **Load Testing**:
   - **Taylor**: Publish 1000 events/second from Helox
   - **Harrison**: Publish 1000 events/second from Platform Services
   - **Both**: Verify all consumers keep up
   - **Both**: Measure latency
   - **Both**: Identify bottlenecks

2. **Consumer Lag Testing**:
   - **Both**: Slow down a consumer (simulate)
   - **Both**: Verify lag is detected
   - **Both**: Verify recovery works

3. **Stream Trimming**:
   - **Both**: Fill streams to capacity
   - **Both**: Verify trimming works
   - **Both**: Verify no data loss

**Deliverable**: 
- Performance test results
- Optimization recommendations
- Bottleneck analysis

### Day 3: Bug Fixes and Coordination

**Objective**: Fix issues found during testing.

**Tasks** (Both work together):

1. **Prioritize Bugs**:
   - List all bugs found
   - Prioritize by severity
   - Assign fixes (Taylor fixes Cyrex/Helox, Harrison fixes Platform Services)

2. **Fix Bugs**:
   - **Taylor**: Fix Cyrex/Helox issues
   - **Harrison**: Fix Platform Services issues
   - **Both**: Test fixes together

3. **Coordinate Integration Points**:
   - **Both**: Verify event schemas match
   - **Both**: Verify event types are consistent
   - **Both**: Verify error handling is consistent

**Deliverable**: 
- All critical bugs fixed
- Integration points verified
- System working end-to-end

### Day 4: Documentation

**Objective**: Document everything for future developers.

**Tasks** (Both work together):

1. **API Documentation**:
   - Document all event types
   - Document event schemas
   - Document publishing patterns
   - Document consumption patterns

2. **Integration Guides**:
   - How to add new event types
   - How to add new consumers
   - How to debug issues
   - How to monitor system

3. **Runbooks**:
   - How to monitor system
   - How to handle failures
   - How to scale
   - How to troubleshoot

**Deliverable**: 
- Complete documentation
- Integration guides
- Runbooks

### Day 5: Final Validation

**Objective**: Final end-to-end validation before moving to advanced features.

**Tasks** (Both work together):

1. **Complete Test Suite**:
   - Run all tests
   - Verify all pass
   - Document any remaining issues

2. **System Health Check**:
   - Check all services are healthy
   - Check all consumers are running
   - Check all streams are active

3. **Performance Validation**:
   - Verify system meets performance requirements
   - Verify no memory leaks
   - Verify no connection leaks

**Deliverable**: 
- System fully validated
- Ready for advanced features
- Documentation complete

---

## ADVANCED FEATURES TOGETHER

**Week 4: Advanced Synapse Features**
**Taylor and Harrison work together on advanced features.**

### Day 1: Event Routing and Filtering

**Objective**: Implement advanced routing in Synapse service.

**Tasks** (Both work together):

1. **Pattern-Based Routing**:
   ```python
   # In Synapse service: platform-services/shared/deepiri-synapse/app/consumers/event_router.py
   class EventRouter:
       async def route_event(self, stream: str, event: Dict[str, Any]):
           """Route event based on patterns"""
           # Route based on event type
           # Route based on source
           # Route based on metadata
           pass
   ```

2. **Event Filtering**:
   - Filter events by type
   - Filter events by source
   - Filter events by metadata

**Deliverable**: 
- Event routing system
- Event filtering

### Day 2: Service Discovery

**Objective**: Implement service discovery in Synapse.

**Tasks** (Both work together):

1. **Service Registry**:
   ```python
   # In Synapse service
   class ServiceRegistry:
       async def register_service(
           self,
           service_name: str,
           capabilities: List[str],
           health_endpoint: str
       ):
           """Register service with Synapse"""
           pass
       
       async def discover_services(self, capability: str) -> List[str]:
           """Discover services with capability"""
           pass
   ```

2. **Health Monitoring**:
   - Monitor service health
   - Remove unhealthy services
   - Alert on service failures

**Deliverable**: 
- Service discovery system
- Health monitoring

### Day 3: Event Replay

**Objective**: Implement event replay capabilities.

**Tasks** (Both work together):

1. **Event History**:
   - Store event history
   - Index by time range
   - Index by event type

2. **Replay API**:
   ```python
   # In Synapse service
   @app.post("/replay")
   async def replay_events(
       stream: str,
       start_time: datetime,
       end_time: datetime,
       event_types: List[str] = None
   ):
       """Replay events from time range"""
       pass
   ```

**Deliverable**: 
- Event replay system
- Replay API

### Day 4: Schema Validation

**Objective**: Add Pydantic schema validation.

**Tasks** (Both work together):

1. **Event Schemas**:
   ```python
   # In Synapse service
   from pydantic import BaseModel
   
   class ModelReadyEvent(BaseModel):
       event: str = "model-ready"
       model_name: str
       version: str
       checkpoint_path: str
       timestamp: datetime
   ```

2. **Validation Middleware**:
   - Validate events before publishing
   - Route invalid events to DLQ
   - Alert on validation failures

**Deliverable**: 
- Schema validation
- DLQ for invalid events

### Day 5: Monitoring and Observability

**Objective**: Add comprehensive monitoring.

**Tasks** (Both work together):

1. **Prometheus Metrics**:
   - Events published per second
   - Events consumed per second
   - Consumer lag
   - Error rates

2. **Grafana Dashboards**:
   - Event throughput
   - Consumer lag
   - Error rates
   - Service health

**Deliverable**: 
- Prometheus metrics
- Grafana dashboards

---

## Final Checklist

### Taylor's Checklist
- [ ] Helox publishing all training events
- [ ] Helox publishing model-ready events
- [ ] Cyrex subscribing to model events
- [ ] Cyrex auto-loading models
- [ ] Cyrex publishing inference events
- [ ] Cyrex publishing RAG events
- [ ] Cyrex publishing agent events
- [ ] Model health monitoring
- [ ] Error handling

### Harrison's Checklist
- [ ] All 9 services publishing events
- [ ] Analytics consuming events
- [ ] Notifications consuming events
- [ ] Realtime Gateway forwarding events
- [ ] API Gateway publishing metrics
- [ ] Challenge service integrated
- [ ] Error handling
- [ ] Health monitoring

### Integration Checklist
- [ ] End-to-end event flow works
- [ ] Consumer groups work correctly
- [ ] Event replay works
- [ ] Schema validation works
- [ ] DLQ routing works
- [ ] Performance under load
- [ ] Documentation complete

---

## Success Criteria

1. **All Services Connected**: All 9 platform services + Cyrex + Helox connected to Synapse
2. **Event Types Published**: All required event types being published
3. **Event Consumption**: All required events being consumed
4. **Error Handling**: Robust error handling and retry logic
5. **Monitoring**: Comprehensive monitoring and alerting
6. **Performance**: System handles 1000+ events/second
7. **Documentation**: Complete documentation for future developers

---

## Timeline Summary

**Week 1**: Foundation and basic integration
- **Taylor**: Cyrex/Helox integration
- **Harrison**: Platform services integration

**Week 2**: Advanced features and error handling
- **Taylor**: Advanced Cyrex/Helox features
- **Harrison**: Advanced platform service features

**Week 3**: **CONVERGENCE** - Integration testing and coordination
- **Both**: Work together on testing and fixes

**Week 4**: Advanced Synapse features
- **Both**: Event routing, service discovery, replay, monitoring

**Total: 4 weeks to production-ready**

---

## Getting Help

**Questions about Cyrex/Helox**: Ask Taylor
**Questions about Platform Services**: Ask Harrison
**Questions about Synapse Core**: Ask both or refer to architecture docs
**Blockers**: Document immediately and escalate

---

## Next Steps

1. **Taylor**: Start with Day 1 of your bootcamp
2. **Harrison**: Start with Day 1 of your bootcamp
3. **Daily Sync**: Check in daily (but work independently Weeks 1-2)
4. **Week 3**: Meet for convergence and testing
5. **Week 4**: Work together on advanced features

Good luck! You've got this.
