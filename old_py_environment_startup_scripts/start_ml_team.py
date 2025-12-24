#!/usr/bin/env python3
"""
Startup script for ML Team
Starts: cyrex, mlflow, jupyter, mongodb, redis, influxdb
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start ML team services."""
    print("=" * 60)
    print("Starting ML Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    # Define services for ML team
    services = [
        # MongoDB - For data storage
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-ml",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_ml_data": "/data/db"
            },
        },
        # Redis - For caching
        {
            "image": "redis:7.2-alpine",
            "name": "deepiri-redis-ml",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_ml_data": "/data"
            },
        },
        # InfluxDB - For time-series analytics
        {
            "image": "influxdb:2.7",
            "name": "deepiri-influxdb-ml",
            "ports": {"8086/tcp": 8086},
            "environment": {
                "DOCKER_INFLUXDB_INIT_MODE": "setup",
                "DOCKER_INFLUXDB_INIT_USERNAME": env.get("INFLUXDB_USER", "admin"),
                "DOCKER_INFLUXDB_INIT_PASSWORD": env.get("INFLUXDB_PASSWORD", "adminpassword"),
                "DOCKER_INFLUXDB_INIT_ORG": env.get("INFLUXDB_ORG", "deepiri"),
                "DOCKER_INFLUXDB_INIT_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
                "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
            },
            "volumes": {
                "influxdb_ml_data": "/var/lib/influxdb2"
            },
        },
        # MLflow - Experiment tracking
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow-ml",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_ml_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
            "depends_on": [],
        },
        # Python AI Service (Cyrex) - For model inference
        {
            "image": None,
            "name": "deepiri-cyrex-ml",
            "build": {
                "context": str(project_root / "diri-cyrex"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"8000/tcp": 8000},
            "environment": {
                "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
                "OPENAI_MODEL": env.get("OPENAI_MODEL", "gpt-4o-mini"),
                "CYREX_API_KEY": env.get("CYREX_API_KEY", "change-me"),
                "MLFLOW_TRACKING_URI": "http://mlflow:5000",
                "WANDB_API_KEY": env.get("WANDB_API_KEY", ""),
                "MONGO_URI": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin",
                "REDIS_URL": f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379",
                "INFLUXDB_URL": "http://influxdb:8086",
                "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
                "INFLUXDB_ORG": env.get("INFLUXDB_ORG", "deepiri"),
                "INFLUXDB_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            },
            "volumes": {
                str(project_root / "diri-cyrex" / "train" / "models"): "/app/train/models",
                str(project_root / "diri-cyrex" / "train" / "data"): "/app/train/data",
                str(project_root / "diri-cyrex" / "inference" / "models"): "/app/inference/models",
            },
            "depends_on": [("mongodb", 5), ("redis", 2), ("mlflow", 3), ("influxdb", 5)],
        },
        # Jupyter Notebook - For experimentation
        {
            "image": None,
            "name": "deepiri-jupyter-ml",
            "build": {
                "context": str(project_root / "diri-cyrex"),
                "dockerfile": "Dockerfile.jupyter",
            },
            "ports": {"8888/tcp": 8888},
            "command": "jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.notebook_dir=/app/notebooks",
            "environment": {
                "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
                "MLFLOW_TRACKING_URI": "http://mlflow:5000",
            },
            "volumes": {
                str(project_root / "diri-cyrex" / "train" / "notebooks"): "/app/notebooks",
                str(project_root / "diri-cyrex" / "train" / "data"): "/app/data",
            },
            "depends_on": [("mlflow", 3), ("cyrex", 3)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("ML Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • Cyrex (AI Service): http://localhost:8000")
        print("  • MLflow: http://localhost:5001")
        print("  • Jupyter: http://localhost:8888")
        print("  • InfluxDB: http://localhost:8086")
        print("  • MongoDB: localhost:27017")
        print("  • Redis: localhost:6379")
        print("\nTo stop services, use: python stop_ml_team.py")
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Error starting services: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

