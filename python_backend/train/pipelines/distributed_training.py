"""
Distributed Training Pipeline
Multi-GPU training with DeepSpeed ZeRO
"""
import torch
import torch.distributed as dist
from deepspeed import init_distributed
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model
import os
from typing import Dict
from ..logging_config import get_logger

logger = get_logger("train.distributed")


class DistributedTrainer:
    """Distributed training with DeepSpeed ZeRO."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.rank = int(os.environ.get('RANK', 0))
        self.world_size = int(os.environ.get('WORLD_SIZE', 1))
        self.local_rank = int(os.environ.get('LOCAL_RANK', 0))
        
        if self.world_size > 1:
            init_distributed()
            torch.cuda.set_device(self.local_rank)
        
        logger.info("Distributed training setup", 
                   rank=self.rank,
                   world_size=self.world_size)
    
    def setup_model_distributed(self):
        """Setup model for distributed training."""
        model_name = self.config.get("base_model", "mistralai/Mistral-7B-v0.1")
        
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.bfloat16
        )
        
        lora_config = LoraConfig(
            r=self.config.get("lora_rank", 16),
            lora_alpha=self.config.get("lora_alpha", 32),
            target_modules=["q_proj", "v_proj", "k_proj", "o_proj"]
        )
        
        model = get_peft_model(model, lora_config)
        
        if self.world_size > 1:
            model = torch.nn.parallel.DistributedDataParallel(
                model,
                device_ids=[self.local_rank],
                output_device=self.local_rank
            )
        
        return model
    
    def create_deepspeed_config(self, stage: int = 3) -> Dict:
        """Create DeepSpeed ZeRO configuration."""
        return {
            "train_batch_size": "auto",
            "train_micro_batch_size_per_gpu": "auto",
            "gradient_accumulation_steps": "auto",
            "zero_optimization": {
                "stage": stage,
                "offload_optimizer": {
                    "device": "cpu",
                    "pin_memory": True
                },
                "offload_param": {
                    "device": "cpu",
                    "pin_memory": True
                } if stage == 3 else None,
                "overlap_comm": True,
                "contiguous_gradients": True,
                "reduce_bucket_size": 5e8,
                "stage3_prefetch_bucket_size": 5e7,
                "stage3_param_persistence_threshold": 1e6,
                "stage3_max_live_parameters": 1e9,
                "stage3_max_reuse_distance": 1e9
            },
            "gradient_clipping": 1.0,
            "fp16": {
                "enabled": True,
                "loss_scale": 0,
                "loss_scale_window": 1000,
                "initial_scale_power": 16,
                "hysteresis": 2,
                "min_loss_scale": 1
            },
            "wall_clock_breakdown": False
        }

