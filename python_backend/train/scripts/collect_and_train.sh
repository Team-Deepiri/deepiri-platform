#!/bin/bash
# Complete data collection and training pipeline

echo "Starting Data Collection and Training Pipeline"
echo "==============================================="

# Step 1: Collect data from recent usage
echo "Step 1: Collecting training data..."
python -c "
from train.pipelines.data_collection_pipeline import get_data_collector
collector = get_data_collector()
collector.export_for_training('train/data/collected_classifications.jsonl', 'classification')
collector.export_for_training('train/data/collected_challenges.jsonl', 'challenge')
print('Data collection complete')
"

# Step 2: Prepare datasets
echo "Step 2: Preparing datasets..."
python train/data/prepare_dataset.py

# Step 3: Train models
echo "Step 3: Training models..."

if [ "$1" == "classifier" ] || [ "$1" == "all" ]; then
    echo "Training task classifier..."
    python train/pipelines/full_training_pipeline.py \
        --config train/configs/training_config.json
fi

if [ "$1" == "generator" ] || [ "$1" == "all" ]; then
    echo "Training challenge generator..."
    python train/pipelines/full_training_pipeline.py \
        --config train/configs/challenge_generator_config.json
fi

if [ "$1" == "bandit" ] || [ "$1" == "all" ]; then
    echo "Training bandit..."
    python train/pipelines/bandit_training.py
fi

# Step 4: Evaluate models
echo "Step 4: Evaluating models..."
python train/scripts/evaluate_model.py \
    --model_path train/models/task_classifier \
    --test_dataset train/data/task_classification_test.jsonl

echo "Pipeline complete!"

