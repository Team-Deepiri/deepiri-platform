#!/bin/bash
# Complete training script
# Usage: ./run_training.sh [model_type] [config_path]

MODEL_TYPE=${1:-task_classifier}
CONFIG_PATH=${2:-train/configs/training_config.json}

echo "Starting training pipeline for $MODEL_TYPE"
echo "Config: $CONFIG_PATH"

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Set CUDA devices
export CUDA_VISIBLE_DEVICES=0,1,2,3

# Run training
python train/pipelines/full_training_pipeline.py --config $CONFIG_PATH

echo "Training complete!"

