#!/bin/bash
# Model Monitoring Script

set -e

MODEL_NAME=${1:-"task_classifier"}

echo "📊 Monitoring ${MODEL_NAME}"

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run monitoring checks
python3 -c "
from mlops.monitoring.model_monitor import get_model_monitor
import json

monitor = get_model_monitor()

# Check performance
performance = monitor.check_model_performance('${MODEL_NAME}')
print('Performance:', json.dumps(performance, indent=2))

# Detect data drift
drift = monitor.detect_data_drift('${MODEL_NAME}', {})
print('Data Drift:', json.dumps(drift, indent=2))

# Detect prediction drift
pred_drift = monitor.detect_prediction_drift('${MODEL_NAME}')
print('Prediction Drift:', json.dumps(pred_drift, indent=2))
"

echo "✅ Monitoring checks completed"

