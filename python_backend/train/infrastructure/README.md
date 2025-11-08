# Training Infrastructure - Production Setup

## Hardware Requirements

### On-Prem Development Farm
- 4-8x NVIDIA RTX 4090 (24GB) for development
- 1-2x NVIDIA H200/H100 (80GB) for medium-scale training
- CPU: AMD EPYC or Intel Xeon (16+ cores)
- RAM: 512GB per node
- Storage: 4-8TB NVMe + 20TB SATA
- Network: Dual 25-100GbE NICs with RDMA

### Cloud Burst
- AWS/GCP/OCI GPU VMs (H100 scale)
- Lambda Labs / CoreWeave for cheaper burst capacity
- Kubernetes GPU autoscaling

## Software Stack

### Orchestration
- Kubernetes for cluster management
- Ray for distributed RL experiments
- DeepSpeed ZeRO for large-model training
- vLLM for high-throughput inference

### Training Libraries
- PyTorch (main framework)
- Transformers (Hugging Face)
- bitsandbytes (4-bit/8-bit quantization)
- PEFT (LoRA adapters)
- DeepSpeed (ZeRO optimization)

### Data & Storage
- MinIO (S3-compatible) for object storage
- MongoDB for metadata
- Milvus/Weaviate for vector storage
- DVC for dataset versioning

### Experiment Tracking
- MLflow (on-prem)
- Weights & Biases (cloud)
- Model registry with versioning

## Quick Start

### LoRA Training (7B model on 4x4090)
```bash
python train/infrastructure/lora_training.py \
    --base_model mistralai/Mistral-7B-v0.1 \
    --use_qlora \
    --lora_rank 16 \
    --train_dataset data/task_classification.jsonl \
    --output_dir models/lora_adapter
```

### RAG Pipeline Setup
```bash
# Start Milvus
docker run -d --name milvus -p 19530:19530 milvusdb/milvus:latest

# Initialize RAG
python train/infrastructure/rag_pipeline.py
```

### Experiment Tracking
```python
from train.infrastructure.experiment_tracker import ExperimentTracker

tracker = ExperimentTracker("task_classification", use_wandb=True)
tracker.start_run()
tracker.log_params({"learning_rate": 2e-4, "batch_size": 4})
tracker.log_metrics({"accuracy": 0.92}, step=100)
tracker.end_run()
```

