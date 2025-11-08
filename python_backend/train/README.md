# AI Training Infrastructure

## Directory Structure

- `models/` - Saved model checkpoints
- `data/` - Training datasets
- `experiments/` - Experiment tracking results
- `notebooks/` - Jupyter notebooks for research
- `scripts/` - Training scripts

## Training Scripts

- `train_task_classifier.py` - Task understanding model
- `train_challenge_generator.py` - Challenge generation model
- `train_personalization_model.py` - RL personalization model

## Usage

Run training scripts from the python_backend directory:

```bash
python train/scripts/train_task_classifier.py
python train/scripts/train_challenge_generator.py
python train/scripts/train_personalization_model.py
```

## Data Requirements

Training data should be placed in `train/data/`:
- Task classification datasets
- Challenge generation examples
- User behavior patterns

## Model Checkpoints

Trained models are saved to `train/models/` for versioning and deployment.

