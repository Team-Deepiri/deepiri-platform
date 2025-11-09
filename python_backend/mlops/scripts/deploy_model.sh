#!/bin/bash
# Model Deployment Script

set -e

MODEL_NAME=${1:-"task_classifier"}
MODEL_VERSION=${2:-"latest"}
STRATEGY=${3:-"canary"}

echo "🚀 Deploying ${MODEL_NAME} version ${MODEL_VERSION} using ${STRATEGY} strategy"

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run deployment
python3 -c "
from mlops.deployment.deployment_automation import get_deployment_automation
import json
import sys

deployment = get_deployment_automation()

config = {}
if '${STRATEGY}' == 'canary':
    config = {
        'initial_traffic': 10,
        'increment': 10,
        'interval_minutes': 5
    }

result = deployment.deploy_model(
    model_name='${MODEL_NAME}',
    model_version='${MODEL_VERSION}',
    strategy='${STRATEGY}',
    config=config if config else None
)

print(json.dumps(result, indent=2))

if not result.get('success'):
    sys.exit(1)
"

echo "✅ Deployment completed successfully"

