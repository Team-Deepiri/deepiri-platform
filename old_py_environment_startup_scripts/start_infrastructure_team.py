#!/usr/bin/env python3
"""
Startup script for Infrastructure Team
Starts: Monitoring, databases, all services for infrastructure management
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start infrastructure team services."""
    print("=" * 60)
    print("Starting Infrastructure Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    mongo_uri = f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Define services for infrastructure team - monitoring and infrastructure tools
    services = [
        # Core Infrastructure - Databases
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-infra",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_infra_data": "/data/db"
            },
        },
        {
            "image": "mongo-express:1.0.2",
            "name": "deepiri-mongo-express-infra",
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
            "name": "deepiri-redis-infra",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_infra_data": "/data"
            },
        },
        {
            "image": "influxdb:2.7",
            "name": "deepiri-influxdb-infra",
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
                "influxdb_infra_data": "/var/lib/influxdb2"
            },
        },
        # Monitoring Stack
        {
            "image": "prom/prometheus:latest",
            "name": "deepiri-prometheus-infra",
            "ports": {"9090/tcp": 9090},
            "volumes": {
                str(project_root / "ops" / "prometheus" / "prometheus.yml"): "/etc/prometheus/prometheus.yml:ro",
                "prometheus_infra_data": "/prometheus"
            },
            "command": [
                "--config.file=/etc/prometheus/prometheus.yml",
                "--storage.tsdb.path=/prometheus",
                "--web.enable-lifecycle"
            ],
        },
        {
            "image": "grafana/grafana:latest",
            "name": "deepiri-grafana-infra",
            "ports": {"3000/tcp": 3001},
            "environment": {
                "GF_SECURITY_ADMIN_PASSWORD": env.get("GRAFANA_ADMIN_PASSWORD", "admin"),
                "GF_INSTALL_PLUGINS": "grafana-clock-panel,grafana-simple-json-datasource",
            },
            "volumes": {
                "grafana_infra_data": "/var/lib/grafana",
                str(project_root / "ops" / "grafana" / "dashboards"): "/etc/grafana/provisioning/dashboards:ro",
                str(project_root / "ops" / "grafana" / "datasources"): "/etc/grafana/provisioning/datasources:ro",
            },
            "depends_on": [("prometheus", 3)],
        },
        # MLflow - For model monitoring
        {
            "image": "ghcr.io/mlflow/mlflow:v2.8.1",
            "name": "deepiri-mlflow-infra",
            "ports": {"5000/tcp": 5001},
            "environment": {
                "BACKEND_STORE_URI": "file:/mlflow",
                "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
            },
            "volumes": {
                "mlflow_infra_data": "/mlflow"
            },
            "command": "mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri file:/mlflow --default-artifact-root file:/mlflow/artifacts",
        },
        # All Services for Monitoring (to monitor the full stack)
        {
            "image": None,
            "name": "deepiri-api-gateway-infra",
            "build": {
                "context": str(project_root / "services" / "api-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5000/tcp": 5000},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
                "PORT": "5000",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
                "AUTH_SERVICE_URL": "http://deepiri-auth-service:5001",
                "TASK_ORCHESTRATOR_URL": "http://deepiri-task-orchestrator:5002",
                "ENGAGEMENT_SERVICE_URL": "http://deepiri-engagement-service:5003",
                "PLATFORM_ANALYTICS_SERVICE_URL": "http://deepiri-platform-analytics-service:5004",
                "NOTIFICATION_SERVICE_URL": "http://notification-service:5005",
                "EXTERNAL_BRIDGE_SERVICE_URL": "http://deepiri-external-bridge-service:5006",
                "CHALLENGE_SERVICE_URL": "http://challenge-service:5007",
                "REALTIME_GATEWAY_URL": "http://deepiri-realtime-gateway:5008",
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
            "name": "deepiri-deepiri-auth-service-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-auth-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5001/tcp": 5001},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-deepiri-task-orchestrator-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-task-orchestrator"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5002/tcp": 5002},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-deepiri-engagement-service-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-engagement-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5003/tcp": 5003},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-deepiri-platform-analytics-service-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-platform-analytics-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5004/tcp": 5004},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-notification-service-infra",
            "build": {
                "context": str(project_root / "services" / "notification-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5005/tcp": 5005},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-deepiri-external-bridge-service-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-external-bridge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5006/tcp": 5006},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
                "PORT": "5006",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-external-bridge-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-challenge-service-infra",
            "build": {
                "context": str(project_root / "services" / "challenge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5007/tcp": 5007},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
            "name": "deepiri-deepiri-realtime-gateway-infra",
            "build": {
                "context": str(project_root / "services" / "deepiri-realtime-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5008/tcp": 5008},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "production"),
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
        # AI Service
        {
            "image": None,
            "name": "deepiri-cyrex-infra",
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
            },
            "depends_on": [("mongodb", 5), ("redis", 2), ("mlflow", 3), ("influxdb", 5)],
        },
        # Frontend
        {
            "image": None,
            "name": "deepiri-frontend-infra",
            "build": {
                "context": str(project_root / "deepiri-web-frontend"),
                "dockerfile": "Dockerfile.dev",
            },
            "ports": {"5173/tcp": 5173},
            "environment": {
                "NODE_ENV": "production",
                "VITE_API_URL": "http://localhost:5000/api",
                "VITE_CYREX_URL": "http://localhost:8000",
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
        print("Starting infrastructure monitoring environment...")
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("Infrastructure Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nMonitoring & Infrastructure Tools:")
        print("  • Prometheus: http://localhost:9090")
        print("  • Grafana: http://localhost:3001 (admin/admin)")
        print("  • MLflow: http://localhost:5001")
        print("  • InfluxDB: http://localhost:8086")
        print("  • Mongo Express: http://localhost:8081")
        print("\nApplication Services (for monitoring):")
        print("  • Frontend: http://localhost:5173")
        print("  • API Gateway: http://localhost:5000")
        print("  • Cyrex (AI): http://localhost:8000")
        print("  • All Microservices: ports 5001-5008")
        print("\nInfrastructure Management:")
        print("  • View metrics in Grafana dashboards")
        print("  • Query Prometheus for service metrics")
        print("  • Monitor database health via Mongo Express")
        print("  • Track ML experiments in MLflow")
        print("\nTo stop services, use: python stop_infrastructure_team.py")
        
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

