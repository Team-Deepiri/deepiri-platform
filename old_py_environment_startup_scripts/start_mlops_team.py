#!/usr/bin/env python3
"""
Startup script for ML Ops Team
Starts: mlflow, prometheus, grafana, mlops-service, cyrex
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start ML Ops team services."""
    print("=" * 60)
    print("Starting ML Ops Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    # Define services for ML Ops team
    services = [
        # MLflow - Model registry and tracking
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow-mlops",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_mlops_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
        },
        # Prometheus - Metrics collection
        {
            "image": "prom/prometheus:latest",
            "name": "deepiri-prometheus-mlops",
            "ports": {"9090/tcp": 9090},
            "volumes": {
                str(project_root / "ops" / "prometheus" / "prometheus.yml"): "/etc/prometheus/prometheus.yml:ro",
                "prometheus_mlops_data": "/prometheus"
            },
            "command": [
                "--config.file=/etc/prometheus/prometheus.yml",
                "--storage.tsdb.path=/prometheus"
            ],
        },
        # Grafana - Metrics visualization
        {
            "image": "grafana/grafana:latest",
            "name": "deepiri-grafana-mlops",
            "ports": {"3000/tcp": 3001},
            "environment": {
                "GF_SECURITY_ADMIN_PASSWORD": env.get("GRAFANA_ADMIN_PASSWORD", "admin"),
            },
            "volumes": {
                "grafana_mlops_data": "/var/lib/grafana"
            },
            "depends_on": [("prometheus", 3)],
        },
        # ML Ops Service - Model deployment automation
        {
            "image": None,
            "name": "deepiri-mlops-service",
            "build": {
                "context": str(project_root / "diri-cyrex"),
                "dockerfile": str(project_root / "diri-cyrex" / "mlops" / "docker" / "Dockerfile.mlops"),
            },
            "ports": {"8000/tcp": 8001},
            "environment": {
                "MLFLOW_TRACKING_URI": "http://mlflow:5000",
                "MODEL_REGISTRY_PATH": "/app/model_registry",
                "STAGING_MODEL_PATH": "/app/models/staging",
                "PRODUCTION_MODEL_PATH": "/app/models/production",
                "PROMETHEUS_URL": "http://prometheus:9090",
            },
            "volumes": {
                "model_registry_mlops": "/app/model_registry",
                "models_staging_mlops": "/app/models/staging",
                "models_production_mlops": "/app/models/production",
            },
            "depends_on": [("mlflow", 5), ("prometheus", 3)],
        },
        # Cyrex - For model inference testing
        {
            "image": None,
            "name": "deepiri-cyrex-mlops",
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
                "MODEL_REGISTRY_PATH": "/app/model_registry",
            },
            "volumes": {
                str(project_root / "diri-cyrex" / "train" / "models"): "/app/train/models",
                "model_registry_mlops": "/app/model_registry",
            },
            "depends_on": [("mlflow", 5)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("ML Ops Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • MLflow: http://localhost:5001")
        print("  • Prometheus: http://localhost:9090")
        print("  • Grafana: http://localhost:3001 (admin/admin)")
        print("  • ML Ops Service: http://localhost:8001")
        print("  • Cyrex: http://localhost:8000")
        print("\nTo stop services, use: python stop_mlops_team.py")
        
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

