# AI Inference Infrastructure

## Directory Structure

- `models/` - Deployed models for inference
- `pipelines/` - Inference pipeline scripts

## Model Deployment

Trained models from `train/models/` are deployed to `inference/models/` for production use.

## Inference Pipelines

Inference pipelines handle:
- Task classification
- Challenge generation
- Personalization scoring
- Real-time model inference

## Usage

Inference pipelines are integrated into the main FastAPI application at `app/main.py`.

