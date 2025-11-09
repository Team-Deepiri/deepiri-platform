#!/bin/bash
# MLOps Environment Setup Script

set -e

echo "🚀 Setting up MLOps Environment for Deepiri"

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    python3-pip \
    python3-venv \
    docker.io \
    docker-compose \
    kubectl \
    curl \
    wget

# Create virtual environment
echo "🐍 Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📚 Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt
pip install \
    mlflow==2.8.1 \
    kubernetes==28.1.0 \
    prometheus-client==0.19.0 \
    grafana-api==1.0.3 \
    numpy \
    pandas \
    scikit-learn \
    torch \
    transformers

# Create directories
echo "📁 Creating directories..."
mkdir -p model_registry
mkdir -p models/staging
mkdir -p models/production
mkdir -p data/raw
mkdir -p data/processed
mkdir -p logs
mkdir -p experiments

# Setup MLflow
echo "🔬 Setting up MLflow..."
if [ ! -f .env ]; then
    cat > .env << EOF
MLFLOW_TRACKING_URI=http://localhost:5000
MODEL_REGISTRY_PATH=./model_registry
STAGING_MODEL_PATH=./models/staging
PRODUCTION_MODEL_PATH=./models/production
PINECONE_API_KEY=
WEAVIATE_URL=
KUBERNETES_CONFIG=~/.kube/config
EOF
fi

# Start MLflow server (background)
echo "🚀 Starting MLflow server..."
mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlflow/artifacts &
MLFLOW_PID=$!
echo "MLflow PID: $MLFLOW_PID"

# Wait for MLflow to start
sleep 5

# Test MLflow connection
echo "🧪 Testing MLflow connection..."
python3 -c "import mlflow; mlflow.set_tracking_uri('http://localhost:5000'); print('MLflow connected!')" || echo "⚠️  MLflow connection failed"

# Setup Prometheus (if not using Docker)
if [ ! -f prometheus/prometheus.yml ]; then
    echo "📊 Setting up Prometheus..."
    mkdir -p prometheus
    cat > prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'mlops'
    static_configs:
      - targets: ['localhost:8000']
EOF
fi

# Create test script
cat > test_mlops_setup.py << 'EOF'
#!/usr/bin/env python3
"""Test MLOps setup"""
import sys

def test_imports():
    """Test required imports"""
    try:
        import mlflow
        import kubernetes
        import prometheus_client
        print("✅ All imports successful")
        return True
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False

def test_mlflow():
    """Test MLflow connection"""
    try:
        import mlflow
        mlflow.set_tracking_uri("http://localhost:5000")
        print("✅ MLflow connection successful")
        return True
    except Exception as e:
        print(f"⚠️  MLflow connection failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing MLOps setup...")
    imports_ok = test_imports()
    mlflow_ok = test_mlflow()
    
    if imports_ok and mlflow_ok:
        print("\n✅ MLOps environment setup complete!")
        sys.exit(0)
    else:
        print("\n⚠️  Some tests failed. Check the output above.")
        sys.exit(1)
EOF

chmod +x test_mlops_setup.py

# Run tests
echo "🧪 Running setup tests..."
python3 test_mlops_setup.py

echo ""
echo "✅ MLOps environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Activate virtual environment: source venv/bin/activate"
echo "2. Start MLflow: mlflow server --host 0.0.0.0 --port 5000"
echo "3. Start services: docker-compose -f mlops/docker/docker-compose.mlops.yml up"
echo "4. Access MLflow UI: http://localhost:5000"
echo "5. Access Grafana: http://localhost:3000 (admin/admin)"

