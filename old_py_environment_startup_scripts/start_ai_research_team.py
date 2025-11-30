#!/usr/bin/env python3
"""
Startup script for AI Research Team
Starts: jupyter, mlflow, cyrex, mongodb (for data access)
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start AI research team services."""
    print("=" * 60)
    print("Starting AI Research Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    # Define services for AI research team
    services = [
        # MongoDB - For data access
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-research",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_research_data": "/data/db"
            },
        },
        # MLflow - Experiment tracking
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow-research",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_research_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
        },
        # Python AI Service (Cyrex) - For model testing
        {
            "image": None,
            "name": "deepiri-cyrex-research",
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
            },
            "volumes": {
                str(project_root / "diri-cyrex" / "train" / "models"): "/app/train/models",
                str(project_root / "diri-cyrex" / "train" / "data"): "/app/train/data",
            },
            "depends_on": [("mongodb", 5), ("mlflow", 3)],
        },
        # Jupyter Notebook - Primary research tool
        {
            "image": None,
            "name": "deepiri-jupyter-research",
            "build": {
                "context": str(project_root / "diri-cyrex"),
                "dockerfile": "Dockerfile.jupyter",
            },
            "ports": {"8888/tcp": 8888},
            "command": "jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.notebook_dir=/app/notebooks",
            "environment": {
                "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
                "MLFLOW_TRACKING_URI": "http://mlflow:5000",
                "CYREX_URL": "http://cyrex:8000",
            },
            "volumes": {
                str(project_root / "diri-cyrex" / "train" / "notebooks"): "/app/notebooks",
                str(project_root / "diri-cyrex" / "train" / "data"): "/app/data",
                str(project_root / "diri-cyrex" / "train" / "experiments"): "/app/experiments",
            },
            "depends_on": [("mlflow", 3), ("cyrex", 5)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("AI Research Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • Jupyter Notebook: http://localhost:8888")
        print("  • MLflow: http://localhost:5001")
        print("  • Cyrex (AI Service): http://localhost:8000")
        print("  • MongoDB: localhost:27017")
        print("\nTo stop services, use: python stop_ai_research_team.py")
        
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

