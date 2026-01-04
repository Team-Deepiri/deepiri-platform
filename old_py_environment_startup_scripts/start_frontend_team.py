#!/usr/bin/env python3
"""
Startup script for Frontend Team
Starts: frontend, api-gateway, mongodb, redis, mongo-express
"""
import sys
from pathlib import Path
from docker_manager import DockerServiceManager, load_env_file

def main():
    """Start frontend team services."""
    print("=" * 60)
    print("Starting Frontend Team Services")
    print("=" * 60)
    
    manager = DockerServiceManager()
    env = load_env_file()
    
    # Define services for frontend team
    services = [
        # MongoDB - For API data
        {
            "image": "mongo:7.0",
            "name": "deepiri-mongodb-frontend",
            "ports": {"27017/tcp": 27017},
            "environment": {
                "MONGO_INITDB_ROOT_USERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "MONGO_INITDB_ROOT_PASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "MONGO_INITDB_DATABASE": env.get("MONGO_DB", "deepiri"),
            },
            "volumes": {
                "mongodb_frontend_data": "/data/db"
            },
            "wait_url": None,
        },
        # Mongo Express - Database admin UI
        {
            "image": "mongo-express:1.0.2",
            "name": "deepiri-mongo-express-frontend",
            "ports": {"8081/tcp": 8081},
            "environment": {
                "ME_CONFIG_MONGODB_ADMINUSERNAME": env.get("MONGO_ROOT_USER", "admin"),
                "ME_CONFIG_MONGODB_ADMINPASSWORD": env.get("MONGO_ROOT_PASSWORD", "password"),
                "ME_CONFIG_MONGODB_URL": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/",
                "ME_CONFIG_BASICAUTH": "false",
            },
            "wait_url": None,
            "depends_on": [("mongodb", 5)],
        },
        # Redis - For caching
        {
            "image": "redis:7.2-alpine",
            "name": "deepiri-redis-frontend",
            "ports": {"6379/tcp": 6379},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                "redis_frontend_data": "/data"
            },
            "wait_url": None,
        },
        # API Gateway - Backend API
        {
            "image": None,  # Will build from Dockerfile
            "name": "deepiri-api-gateway-frontend",
            "build": {
                "context": str(Path(__file__).parent.parent / "services" / "deepiri-api-gateway"),
                "dockerfile": "Dockerfile",
            },
            "ports": {"5000/tcp": 5000},
            "environment": {
                "NODE_ENV": "development",
                "PORT": "5000",
                "MONGO_URI": f"mongodb://{env.get('MONGO_ROOT_USER', 'admin')}:{env.get('MONGO_ROOT_PASSWORD', 'password')}@mongodb:27017/{env.get('MONGO_DB', 'deepiri')}?authSource=admin",
                "REDIS_URL": f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379",
            },
            "volumes": {
                str(Path(__file__).parent.parent / "services" / "api-gateway"): "/app",
                "/app/node_modules": {},
            },
            "wait_url": "http://localhost:5000/api/health",
            "depends_on": [("mongodb", 5), ("redis", 2)],
        },
        # Frontend - React app with Vite HMR
        {
            "image": None,  # Will build from Dockerfile
            "name": "deepiri-frontend-dev",
            "build": {
                "context": str(Path(__file__).parent.parent / "deepiri-web-frontend"),
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
                str(Path(__file__).parent.parent / "deepiri-web-frontend"): "/app",
                "/app/node_modules": {},
            },
            "wait_url": "http://localhost:5173",
            "depends_on": [("api-gateway", 5)],
        },
    ]
    
    # Start services
    try:
        started = manager.start_services(services, wait_for_dependencies=True)
        
        print("\n" + "=" * 60)
        print("Frontend Team Services Started Successfully!")
        print("=" * 60)
        print("\nServices running:")
        for name in started:
            print(f"  ✓ {name}")
        print("\nAccess points:")
        print("  • Frontend (Vite HMR): http://localhost:5173")
        print("  • API Gateway: http://localhost:5000")
        print("  • Mongo Express: http://localhost:8081")
        print("  • MongoDB: localhost:27017")
        print("  • Redis: localhost:6379")
        print("\nTo stop services, use: python stop_frontend_team.py")
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Error starting services: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

