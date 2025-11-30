#!/usr/bin/env python3
"""
Startup script for ALL Services
Starts: Everything - all microservices, frontend, AI services, databases, monitoring
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start all services."""
    print("=" * 60)
    print("Starting ALL Deepiri Services")
    print("=" * 60)
    print("This will start the complete platform...")
    print()
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    mongo_uri = f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Define ALL services
    services = [
        # Infrastructure
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_data": "/data/db"
            },
        },
        {
            "image": "mongo-express:1.0.2",
            "name": "deepiri-mongo-express",
            "ports": {"8081/tcp": 8081},
            "environment": {
                "ME_CONFIG_MONGODB_ADMINUSERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "ME_CONFIG_MONGODB_ADMINPASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "ME_CONFIG_MONGODB_URL": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/",
                "ME_CONFIG_BASICAUTH": "false",
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": "redis:7.2-alpine",
            "name": "deepiri-redis",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_data": "/data"
            },
        },
        {
            "image": "influxdb:2.7",
            "name": "deepiri-influxdb",
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
                "influxdb_data": "/var/lib/influxdb2"
            },
        },
        # MLflow
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
        },
        # Prometheus & Grafana
        {
            "image": "prom/prometheus:latest",
            "name": "deepiri-prometheus",
            "ports": {"9090/tcp": 9090},
            "volumes": {
                str(project_root / "ops" / "prometheus" / "prometheus.yml"): "/etc/prometheus/prometheus.yml:ro",
                "prometheus_data": "/prometheus"
            },
            "command": [
                "--config.file=/etc/prometheus/prometheus.yml",
                "--storage.tsdb.path=/prometheus"
            ],
        },
        {
            "image": "grafana/grafana:latest",
            "name": "deepiri-grafana",
            "ports": {"3000/tcp": 3001},
            "environment": {
                "GF_SECURITY_ADMIN_PASSWORD": env.get("GRAFANA_ADMIN_PASSWORD", "admin"),
            },
            "volumes": {
                "grafana_data": "/var/lib/grafana"
            },
            "depends_on": [("prometheus", 3)],
        },
        # Microservices
        {
            "image": None,
            "name": "deepiri-api-gateway",
            "build": {
                "context": str(project_root / "services" / "api-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5000/tcp": 5000},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5000",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
                "AUTH_SERVICE_URL": "http://deepiri-auth-service:5001",
                "TASK_ORCHESTRATOR_URL": "http://deepiri-task-orchestrator:5002",
                "ENGAGEMENT_SERVICE_URL": "http://deepiri-engagement-service:5003",
                "PLATFORM_ANALYTICS_SERVICE_URL": "http://deepiri-platform-analytics-service:5004",
                "NOTIFICATION_SERVICE_URL": "http://notification-service:5005",
                "EXTERNAL_BRIDGE_SERVICE_URL": "http://external-bridge-service:5006",
                "CHALLENGE_SERVICE_URL": "http://challenge-service:5007",
                "REALTIME_GATEWAY_URL": "http://realtime-gateway:5008",
                "CYREX_URL": "http://cyrex:8000",
            },
            "volumes": {
                str(project_root / "services" / "api-gateway"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-auth-service",
            "build": {
                "context": str(project_root / "services" / "deepiri-auth-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5001/tcp": 5001},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5001",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-auth-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-task-orchestrator",
            "build": {
                "context": str(project_root / "services" / "deepiri-task-orchestrator"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5002/tcp": 5002},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5002",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-task-orchestrator"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-engagement-service",
            "build": {
                "context": str(project_root / "services" / "deepiri-engagement-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5003/tcp": 5003},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5003",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-engagement-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-platform-analytics-service",
            "build": {
                "context": str(project_root / "services" / "deepiri-platform-analytics-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5004/tcp": 5004},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5004",
                "MONGO_URI": mongo_uri,
                "INFLUXDB_URL": "http://influxdb:8086",
                "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
                "INFLUXDB_ORG": env.get("INFLUXDB_ORG", "deepiri"),
                "INFLUXDB_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            },
            "volumes": {
                str(project_root / "services" / "deepiri-platform-analytics-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("influxdb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-notification-service",
            "build": {
                "context": str(project_root / "services" / "notification-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5005/tcp": 5005},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5005",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "notification-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-external-bridge-service",
            "build": {
                "context": str(project_root / "services" / "deepiri-external-bridge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5006/tcp": 5006},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5006",
                "MONGO_URI": mongo_uri,
                "GITHUB_CLIENT_ID": env.get("GITHUB_CLIENT_ID", ""),
                "GITHUB_CLIENT_SECRET": env.get("GITHUB_CLIENT_SECRET", ""),
                "NOTION_CLIENT_ID": env.get("NOTION_CLIENT_ID", ""),
                "NOTION_CLIENT_SECRET": env.get("NOTION_CLIENT_SECRET", ""),
            },
            "volumes": {
                str(project_root / "services" / "deepiri-external-bridge-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-challenge-service",
            "build": {
                "context": str(project_root / "services" / "challenge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5007/tcp": 5007},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5007",
                "MONGO_URI": mongo_uri,
                "CYREX_URL": "http://cyrex:8000",
            },
            "volumes": {
                str(project_root / "services" / "challenge-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("cyrex", 5)],
        },
        {
            "image": None,
            "name": "deepiri-realtime-gateway",
            "build": {
                "context": str(project_root / "services" / "deepiri-realtime-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5008/tcp": 5008},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "development"),
                "PORT": "5008",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-realtime-gateway"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        # AI Services
        {
            "image": None,
            "name": "deepiri-cyrex",
            "build": {
                "context": str(project_root / "diri-cyrex"),
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
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
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
        {
            "image": None,
            "name": "deepiri-jupyter",
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
        # Frontend
        {
            "image": None,
            "name": "deepiri-frontend",
            "build": {
                "context": str(project_root / "deepiri-web-frontend"),
                "dockerfile": "Dockerfile.dev",
            },
            "ports": {"5173/tcp": 5173},
            "environment": {
                "NODE_ENV": "development",
                "VITE_API_URL": "http://localhost:5000/api",
                "VITE_CYREX_URL": "http://localhost:8000",
                "CHOKIDAR_USEPOLLING": "true",
                "WATCHPACK_POLLING": "true",
            },
            "volumes": {
                str(project_root / "deepiri-web-frontend"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("api-gateway", 5)],
        },
    ]
    
    # Start services
    try:
        print("Starting services (this may take a while)...")
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("ALL Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • Frontend: http://localhost:5173")
        print("  • API Gateway: http://localhost:5000")
        print("  • Cyrex (AI): http://localhost:8000")
        print("  • Jupyter: http://localhost:8888")
        print("  • MLflow: http://localhost:5001")
        print("  • Prometheus: http://localhost:9090")
        print("  • Grafana: http://localhost:3001")
        print("  • Mongo Express: http://localhost:8081")
        print("  • InfluxDB: http://localhost:8086")
        print("\nMicroservices:")
        print("  • User Service: http://localhost:5001")
        print("  • Task Service: http://localhost:5002")
        print("  • Gamification: http://localhost:5003")
        print("  • Analytics: http://localhost:5004")
        print("  • Notifications: http://localhost:5005")
        print("  • Integration: http://localhost:5006")
        print("  • Challenge: http://localhost:5007")
        print("  • WebSocket: http://localhost:5008")
        print("\nTo stop services, use: python stop_all_services.py")
        
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

