#!/usr/bin/env python3
"""
Startup script for Backend Team
Starts: All microservices, mongodb, redis, influxdb, mongo-express
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start backend team services."""
    print("=" * 60)
    print("Starting Backend Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    
    project_root = Path(__file__).parent.parent
    mongo_uri = f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Define services for backend team
    services = [
        # Infrastructure Services
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-backend",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_backend_data": "/data/db"
            },
            "wait_url": None,
        },
        {
            "image": "mongo-express:1.0.2",
            "name": "deepiri-mongo-express-backend",
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
            "name": "deepiri-redis-backend",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_backend_data": "/data"
            },
        },
        {
            "image": "influxdb:2.7",
            "name": "deepiri-influxdb-backend",
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
                "influxdb_backend_data": "/var/lib/influxdb2"
            },
        },
        # Microservices
        {
            "image": None,
            "name": "deepiri-api-gateway-backend",
            "build": {
                "context": str(project_root / "services" / "api-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5000/tcp": 5000},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5000",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
                "USER_SERVICE_URL": "http://user-service:5001",
                "TASK_SERVICE_URL": "http://task-service:5002",
                "GAMIFICATION_SERVICE_URL": "http://gamification-service:5003",
                "ANALYTICS_SERVICE_URL": "http://analytics-service:5004",
                "NOTIFICATION_SERVICE_URL": "http://notification-service:5005",
                "INTEGRATION_SERVICE_URL": "http://integration-service:5006",
                "CHALLENGE_SERVICE_URL": "http://challenge-service:5007",
                "WEBSOCKET_SERVICE_URL": "http://websocket-service:5008",
            },
            "volumes": {
                str(project_root / "services" / "api-gateway"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-user-service-backend",
            "build": {
                "context": str(project_root / "services" / "user-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5001/tcp": 5001},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5001",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "user-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-task-service-backend",
            "build": {
                "context": str(project_root / "services" / "task-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5002/tcp": 5002},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5002",
                "MONGO_URI": mongo_uri,
            },
            "volumes": {
                str(project_root / "services" / "task-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-gamification-service-backend",
            "build": {
                "context": str(project_root / "services" / "gamification-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5003/tcp": 5003},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5003",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "gamification-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-analytics-service-backend",
            "build": {
                "context": str(project_root / "services" / "analytics-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5004/tcp": 5004},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5004",
                "MONGO_URI": mongo_uri,
                "INFLUXDB_URL": "http://influxdb:8086",
                "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
                "INFLUXDB_ORG": env.get("INFLUXDB_ORG", "deepiri"),
                "INFLUXDB_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            },
            "volumes": {
                str(project_root / "services" / "analytics-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("influxdb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-notification-service-backend",
            "build": {
                "context": str(project_root / "services" / "notification-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5005/tcp": 5005},
            "environment": {
                "NODE_ENV": "development",
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
            "name": "deepiri-integration-service-backend",
            "build": {
                "context": str(project_root / "services" / "integration-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5006/tcp": 5006},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5006",
                "MONGO_URI": mongo_uri,
                "GITHUB_CLIENT_ID": env.get("GITHUB_CLIENT_ID", ""),
                "GITHUB_CLIENT_SECRET": env.get("GITHUB_CLIENT_SECRET", ""),
                "NOTION_CLIENT_ID": env.get("NOTION_CLIENT_ID", ""),
                "NOTION_CLIENT_SECRET": env.get("NOTION_CLIENT_SECRET", ""),
            },
            "volumes": {
                str(project_root / "services" / "integration-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5)],
        },
        {
            "image": None,
            "name": "deepiri-websocket-service-backend",
            "build": {
                "context": str(project_root / "services" / "websocket-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5008/tcp": 5008},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5008",
                "MONGO_URI": mongo_uri,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "websocket-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("Backend Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • API Gateway: http://localhost:5000")
        print("  • User Service: http://localhost:5001")
        print("  • Task Service: http://localhost:5002")
        print("  • Gamification Service: http://localhost:5003")
        print("  • Analytics Service: http://localhost:5004")
        print("  • Notification Service: http://localhost:5005")
        print("  • Integration Service: http://localhost:5006")
        print("  • WebSocket Service: http://localhost:5008")
        print("  • Mongo Express: http://localhost:8081")
        print("  • InfluxDB: http://localhost:8086")
        print("\nTo stop services, use: python stop_backend_team.py")
        
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

