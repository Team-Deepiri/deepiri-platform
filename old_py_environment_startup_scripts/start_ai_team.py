#!/usr/bin/env python3
"""
Startup script for AI Team
Starts: cyrex, mlflow, jupyter, challenge-service, mongodb, redis
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start AI team services."""
    print("=" * 60)
    print("Starting AI Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    
    # Define services for AI team
    services = [
        # MongoDB - Required for data storage
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-ai",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_ai_data": "/data/db"
            },
            "wait_url": None,
        },
        # Redis - For caching
        {
            "image": "redis:7.2-alpine",
            "name": "deepiri-redis-ai",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_ai_data": "/data"
            },
            "wait_url": None,
        },
        # MLflow - Experiment tracking
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow-ai",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_ai_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
            "wait_url": "http://mlflow:5000/health",
            "depends_on": [],
        },
        # Python AI Service (Cyrex)
        {
            "image": None,  # Will build from Dockerfile
            "name": "deepiri-cyrex-ai",
            "build": {
                "context": str(Path(__file__).parent.parent / "diri-cyrex"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"8000/tcp": 8000},
            "environment": {
                "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
                "OPENAI_MODEL": env.get("OPENAI_MODEL", "gpt-4o-mini"),
                "CORS_ORIGIN": env.get("CORS_ORIGIN", "http://localhost:5173"),
                "CYREX_API_KEY": env.get("CYREX_API_KEY", "change-me"),
                "MLFLOW_TRACKING_URI": "http://mlflow:5000",
                "WANDB_API_KEY": env.get("WANDB_API_KEY", ""),
                "MONGO_URI": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin",
                "REDIS_URL": f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379",
            },
            "volumes": {
                str(Path(__file__).parent.parent / "diri-cyrex" / "train" / "models"): "/app/train/models",
                str(Path(__file__).parent.parent / "diri-cyrex" / "train" / "data"): "/app/train/data",
            },
            "wait_url": "http://localhost:8000/health",
            "depends_on": [("mongodb", 5), ("redis", 2), ("mlflow", 3)],
        },
        # Jupyter Notebook - For research
        {
            "image": None,  # Will build from Dockerfile
            "name": "deepiri-jupyter-ai",
            "build": {
                "context": str(Path(__file__).parent.parent / "diri-cyrex"),
                "dockerfile": "Dockerfile.jupyter",
            },
            "ports": {"8888/tcp": 8888},
            "command": "jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.notebook_dir=/app/notebooks",
            "environment": {
                "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
            },
            "volumes": {
                str(Path(__file__).parent.parent / "diri-cyrex" / "train" / "notebooks"): "/app/notebooks",
                str(Path(__file__).parent.parent / "diri-cyrex" / "train" / "data"): "/app/data",
            },
            "wait_url": None,
            "depends_on": [("cyrex", 3)],
        },
        # Challenge Service - Needs AI service
        {
            "image": None,  # Will build from Dockerfile
            "name": "deepiri-challenge-service-ai",
            "build": {
                "context": str(Path(__file__).parent.parent / "services" / "challenge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5007/tcp": 5007},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5007",
                "MONGO_URI": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin",
                "CYREX_URL": "http://cyrex:8000",
            },
            "volumes": {
                str(Path(__file__).parent.parent / "services" / "challenge-service"): "/app",
                "/app/node_modules": {},
            },
            "wait_url": None,
            "depends_on": [("mongodb", 5), ("cyrex", 5)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("AI Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • Cyrex (AI Service): http://localhost:8000")
        print("  • MLflow: http://localhost:5001")
        print("  • Jupyter: http://localhost:8888")
        print("  • Challenge Service: http://localhost:5007")
        print("  • MongoDB: localhost:27017")
        print("  • Redis: localhost:6379")
        print("\nTo stop services, use: python stop_ai_team.py")
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Error starting services: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

