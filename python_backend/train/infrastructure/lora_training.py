"""
LoRA/QLoRA Fine-Tuning Pipeline
Production-ready fine-tuning with bitsandbytes, PEFT, and DeepSpeed
"""
import torch
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
    BitsAndBytesConfig
)
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from datasets import load_dataset
import json
from pathlib import Path
from ..logging_config import get_logger

logger = get_logger("lora.training")


class LoRATrainer:
    """LoRA fine-tuning trainer with QLoRA support."""
    
    def __init__(
        self,
        base_model: str = "mistralai/Mistral-7B-v0.1",
        use_qlora: bool = True,
        lora_rank: int = 16,
        lora_alpha: int = 32,
        target_modules: Optional[List[str]] = None
    ):
        self.base_model = base_model
        self.use_qlora = use_qlora
        self.lora_rank = lora_rank
        self.lora_alpha = lora_alpha
        self.target_modules = target_modules or ["q_proj", "v_proj", "k_proj", "o_proj"]
        self.model = None
        self.tokenizer = None
    
    def setup_model(self):
        """Setup model with quantization and LoRA."""
        logger.info("Setting up model", model=self.base_model, qlora=self.use_qlora)
        
        if self.use_qlora:
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16,
                bnb_4bit_use_double_quant=True
            )
            
            self.model = AutoModelForCausalLM.from_pretrained(
                self.base_model,
                quantization_config=bnb_config,
                device_map="auto",
                trust_remote_code=True
            )
            
            self.model = prepare_model_for_kbit_training(self.model)
        else:
            self.model = AutoModelForCausalLM.from_pretrained(
                self.base_model,
                torch_dtype=torch.bfloat16,
                device_map="auto"
            )
        
        self.tokenizer = AutoTokenizer.from_pretrained(self.base_model)
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        lora_config = LoraConfig(
            r=self.lora_rank,
            lora_alpha=self.lora_alpha,
            target_modules=self.target_modules,
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM"
        )
        
        self.model = get_peft_model(self.model, lora_config)
        self.model.print_trainable_parameters()
        
        logger.info("Model setup complete")
    
    def prepare_dataset(self, dataset_path: str, max_length: int = 512):
        """Prepare training dataset."""
        logger.info("Loading dataset", path=dataset_path)
        
        dataset = load_dataset('json', data_files=dataset_path, split='train')
        
        def tokenize_function(examples):
            texts = examples.get('text', [])
            return self.tokenizer(
                texts,
                truncation=True,
                padding="max_length",
                max_length=max_length,
                return_tensors="pt"
            )
        
        tokenized = dataset.map(
            tokenize_function,
            batched=True,
            remove_columns=dataset.column_names
        )
        
        return tokenized
    
    def train(
        self,
        train_dataset,
        output_dir: str = "./models/lora_adapter",
        num_epochs: int = 3,
        batch_size: int = 4,
        gradient_accumulation_steps: int = 16,
        learning_rate: float = 2e-4,
        use_deepspeed: bool = True
    ):
        """Train LoRA adapter."""
        logger.info("Starting LoRA training", epochs=num_epochs, batch_size=batch_size)
        
        training_args = TrainingArguments(
            output_dir=output_dir,
            num_train_epochs=num_epochs,
            per_device_train_batch_size=batch_size,
            gradient_accumulation_steps=gradient_accumulation_steps,
            learning_rate=learning_rate,
            fp16=True,
            logging_steps=10,
            save_steps=500,
            evaluation_strategy="steps",
            eval_steps=500,
            save_total_limit=3,
            load_best_model_at_end=True,
            report_to="wandb",
            deepspeed="ds_config.json" if use_deepspeed else None
        )
        
        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=train_dataset,
        )
        
        trainer.train()
        
        self.model.save_pretrained(output_dir)
        self.tokenizer.save_pretrained(output_dir)
        
        logger.info("Training complete", output_dir=output_dir)
    
    def merge_and_export(self, adapter_path: str, output_path: str):
        """Merge LoRA adapter with base model and export."""
        from peft import PeftModel
        
        base_model = AutoModelForCausalLM.from_pretrained(
            self.base_model,
            torch_dtype=torch.bfloat16,
            device_map="auto"
        )
        
        model = PeftModel.from_pretrained(base_model, adapter_path)
        merged_model = model.merge_and_unload()
        
        merged_model.save_pretrained(output_path)
        self.tokenizer.save_pretrained(output_path)
        
        logger.info("Model merged and exported", output_path=output_path)


class QLoRATrainingPipeline:
    """Complete QLoRA training pipeline."""
    
    def __init__(self, config: Dict):
        self.config = config
        self.trainer = LoRATrainer(
            base_model=config.get("base_model", "mistralai/Mistral-7B-v0.1"),
            use_qlora=config.get("use_qlora", True),
            lora_rank=config.get("lora_rank", 16),
            lora_alpha=config.get("lora_alpha", 32)
        )
    
    def run_full_pipeline(self):
        """Run complete training pipeline."""
        logger.info("Starting QLoRA training pipeline")
        
        self.trainer.setup_model()
        
        train_dataset = self.trainer.prepare_dataset(
            self.config["train_dataset_path"],
            max_length=self.config.get("max_length", 512)
        )
        
        self.trainer.train(
            train_dataset,
            output_dir=self.config["output_dir"],
            num_epochs=self.config.get("num_epochs", 3),
            batch_size=self.config.get("batch_size", 4),
            gradient_accumulation_steps=self.config.get("gradient_accumulation_steps", 16),
            learning_rate=self.config.get("learning_rate", 2e-4),
            use_deepspeed=self.config.get("use_deepspeed", True)
        )
        
        if self.config.get("merge_model", False):
            self.trainer.merge_and_export(
                self.config["output_dir"],
                self.config.get("merged_output_dir", f"{self.config['output_dir']}_merged")
            )
        
        logger.info("QLoRA pipeline complete")


def create_deepspeed_config(stage: int = 2) -> Dict:
    """Create DeepSpeed ZeRO configuration."""
    if stage == 2:
        return {
            "zero_optimization": {
                "stage": 2,
                "offload_optimizer": {
                    "device": "cpu",
                    "pin_memory": True
                },
                "allgather_partitions": True,
                "allgather_bucket_size": 2e8,
                "overlap_comm": True,
                "reduce_scatter": True,
                "reduce_bucket_size": 2e8,
                "contiguous_gradients": True
            },
            "gradient_accumulation_steps": 16,
            "gradient_clipping": 1.0,
            "train_batch_size": "auto",
            "train_micro_batch_size_per_gpu": "auto"
        }
    elif stage == 3:
        return {
            "zero_optimization": {
                "stage": 3,
                "offload_optimizer": {
                    "device": "cpu",
                    "pin_memory": True
                },
                "offload_param": {
                    "device": "cpu",
                    "pin_memory": True
                }
            },
            "gradient_accumulation_steps": 16,
            "train_batch_size": "auto",
            "train_micro_batch_size_per_gpu": "auto"
        }
    
    return {}

