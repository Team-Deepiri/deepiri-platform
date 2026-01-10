#!/usr/bin/env python3
"""
Startup script for Backend Team
Starts: All microservices, postgres, redis, influxdb, pgadmin, adminer
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
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Define services for backend team
    services = [
        # Infrastructure Services
        {
            "image": "postgres:16-alpine",
            "name": "deepiri-postgres-backend",
            "ports": {"5432/tcp": 5432},
            "environment": {
                "POSTGRES_USER": env.get("POSTGRES_USER", "deepiri"),
                "POSTGRES_PASSWORD": env.get("POSTGRES_PASSWORD", "deepiripassword"),
                "POSTGRES_DB": env.get("POSTGRES_DB", "deepiri"),
            },
            "volumes": {
                "postgres_backend_data": "/var/lib/postgresql/data"
            },
            "wait_url": None,
        },
        {
            "image": "dpage/pgadmin4:latest",
            "name": "deepiri-pgadmin-backend",
            "ports": {"5050/tcp": 5050},
            "environment": {
                "PGADMIN_DEFAULT_EMAIL": env.get("PGADMIN_EMAIL", "admin@deepiri.com"),
                "PGADMIN_DEFAULT_PASSWORD": env.get("PGADMIN_PASSWORD", "admin"),
                "PGADMIN_CONFIG_SERVER_MODE": "False",
            },
            "depends_on": [("postgres", 5)],
        },
        {
            "image": "adminer:latest",
            "name": "deepiri-adminer-backend",
            "ports": {"8080/tcp": 8080},
            "environment": {
                "ADMINER_DEFAULT_SERVER": "postgres",
            },
            "depends_on": [("postgres", 5)],
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
                "DATABASE_URL": database_url,
                "REDIS_URL": redis_url,
                "AUTH_SERVICE_URL": "http://deepiri-auth-service:5001",
                "TASK_ORCHESTRATOR_URL": "http://deepiri-task-orchestrator:5002",
                "ENGAGEMENT_SERVICE_URL": "http://deepiri-engagement-service:5003",
                "PLATFORM_ANALYTICS_SERVICE_URL": "http://deepiri-platform-analytics-service:5004",
                "NOTIFICATION_SERVICE_URL": "http://notification-service:5005",
                "EXTERNAL_BRIDGE_SERVICE_URL": "http://deepiri-external-bridge-service:5006",
                "CHALLENGE_SERVICE_URL": "http://challenge-service:5007",
                "REALTIME_GATEWAY_URL": "http://deepiri-realtime-gateway:5008",
            },
            "volumes": {
                str(project_root / "services" / "api-gateway"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-auth-service-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-auth-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5001/tcp": 5001},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5001",
                "DATABASE_URL": database_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-auth-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-task-orchestrator-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-task-orchestrator"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5002/tcp": 5002},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5002",
                "DATABASE_URL": database_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-task-orchestrator"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-engagement-service-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-engagement-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5003/tcp": 5003},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5003",
                "DATABASE_URL": database_url,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-engagement-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5), ("redis", 2)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-platform-analytics-service-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-platform-analytics-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5004/tcp": 5004},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5004",
                "DATABASE_URL": database_url,
                "INFLUXDB_URL": "http://influxdb:8086",
                "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
                "INFLUXDB_ORG": env.get("INFLUXDB_ORG", "deepiri"),
                "INFLUXDB_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            },
            "volumes": {
                str(project_root / "services" / "deepiri-platform-analytics-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5), ("influxdb", 5)],
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
                "DATABASE_URL": database_url,
            },
            "volumes": {
                str(project_root / "services" / "notification-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-external-bridge-service-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-external-bridge-service"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5006/tcp": 5006},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5006",
                "DATABASE_URL": database_url,
                "GITHUB_CLIENT_ID": env.get("GITHUB_CLIENT_ID", ""),
                "GITHUB_CLIENT_SECRET": env.get("GITHUB_CLIENT_SECRET", ""),
                "NOTION_CLIENT_ID": env.get("NOTION_CLIENT_ID", ""),
                "NOTION_CLIENT_SECRET": env.get("NOTION_CLIENT_SECRET", ""),
            },
            "volumes": {
                str(project_root / "services" / "deepiri-external-bridge-service"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5)],
        },
        {
            "image": None,
            "name": "deepiri-deepiri-realtime-gateway-backend",
            "build": {
                "context": str(project_root / "services" / "deepiri-realtime-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5008/tcp": 5008},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5008",
                "DATABASE_URL": database_url,
                "REDIS_URL": redis_url,
            },
            "volumes": {
                str(project_root / "services" / "deepiri-realtime-gateway"): "/app",
                "/app/node_modules": {},
            },
            "depends_on": [("postgres", 5), ("redis", 2)],
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
        print("  • pgAdmin: http://localhost:5050")
        print("  • Adminer: http://localhost:8080")
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

