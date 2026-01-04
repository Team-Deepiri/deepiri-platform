#!/usr/bin/env python3
"""
Startup script for QA Testing Team
Starts: All services needed for testing (frontend, backend, AI services, databases)
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start QA team services."""
    print("=" * 60)
    print("Starting QA Testing Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    project_root = Path(__file__).parent.parent
    
    mongo_uri = f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Define services for QA team - need full stack for testing
    services = [
        # Infrastructure Services
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-qa",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_qa_data": "/data/db"
            },
        },
        {
            "image": "mongo-express:1.0.2",
            "name": "deepiri-mongo-express-qa",
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
            "name": "deepiri-redis-qa",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_qa_data": "/data"
            },
        },
        {
            "image": "influxdb:2.7",
            "name": "deepiri-influxdb-qa",
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
                "influxdb_qa_data": "/var/lib/influxdb2"
            },
        },
        # API Gateway
        {
            "image": None,
            "name": "deepiri-api-gateway-qa",
            "build": {
                "context": str(project_root / "services" / "api-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5000/tcp": 5000},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
        # Core Microservices
        {
            "image": None,
            "name": "deepiri-deepiri-auth-service-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-auth-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5001/tcp": 5001},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-deepiri-task-orchestrator-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-task-orchestrator"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5002/tcp": 5002},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-deepiri-engagement-service-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-engagement-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5003/tcp": 5003},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-deepiri-platform-analytics-service-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-platform-analytics-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5004/tcp": 5004},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-notification-service-qa",
            "build": {
                "context": str(project_root / "services" / "notification-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5005/tcp": 5005},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-deepiri-external-bridge-service-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-external-bridge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5006/tcp": 5006},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-challenge-service-qa",
            "build": {
                "context": str(project_root / "services" / "challenge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5007/tcp": 5007},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-deepiri-realtime-gateway-qa",
            "build": {
                "context": str(project_root / "services" / "deepiri-realtime-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5008/tcp": 5008},
            "environment": {
                "NODE_ENV": env.get("NODE_ENV", "test"),
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
            "name": "deepiri-cyrex-qa",
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
            "depends_on": [("mongodb", 5), ("redis", 2), ("influxdb", 5)],
        },
        # Frontend - For UI testing
        {
            "image": None,
            "name": "deepiri-frontend-qa",
            "build": {
                "context": str(project_root / "deepiri-web-frontend"),
                "dockerfile": "Dockerfile.dev",
            },
            "ports": {"5173/tcp": 5173},
            "environment": {
                "NODE_ENV": "test",
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
        print("Starting QA testing environment (this may take a while)...")
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("QA Testing Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points for testing:")
        print("  • Frontend: http://localhost:5173")
        print("  • API Gateway: http://localhost:5000")
        print("  • Cyrex (AI): http://localhost:8000")
        print("  • User Service: http://localhost:5001")
        print("  • Task Service: http://localhost:5002")
        print("  • Gamification Service: http://localhost:5003")
        print("  • Analytics Service: http://localhost:5004")
        print("  • Notification Service: http://localhost:5005")
        print("  • Integration Service: http://localhost:5006")
        print("  • Challenge Service: http://localhost:5007")
        print("  • WebSocket Service: http://localhost:5008")
        print("  • Mongo Express: http://localhost:8081")
        print("  • InfluxDB: http://localhost:8086")
        print("\nTesting endpoints:")
        print("  • Health check: http://localhost:5000/api/health")
        print("  • API docs: http://localhost:5000/api/docs")
        print("\nTo stop services, use: python stop_qa_team.py")
        
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

