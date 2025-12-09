#!/usr/bin/env python3
"""
Development Environment - Full Stack Runner
Uses docker_manager to create and run ALL containers programmatically
Mimics Kubernetes by injecting ConfigMaps and Secrets
"""

import os
import sys
from pathlib import Path

# Add shared utilities to path
sys.path.insert(0, str(Path(__file__).parent / 'team_dev_environments' / 'shared'))
sys.path.insert(0, str(Path(__file__).parent / 'py_environment_startup_scripts'))

from k8s_env_loader import load_all_configmaps_and_secrets, GREEN, YELLOW, CYAN, GRAY, RESET
from docker_manager import DockerServiceManager, load_env_file
from docker_utils import wait_for_postgres, get_base_services, create_volume_if_not_exists
from service_definitions import get_backend_team_services, get_frontend_team_services, get_ai_team_services


def main():
    """Start all development services using docker_manager."""
    project_root = Path(__file__).parent
    
    print(f"{GREEN}🚀 Starting Development Environment (All Services)...{RESET}")
    print(f"{CYAN}   (Using docker_manager to create containers){RESET}")
    print()
    
    # Load environment variables
    env = load_env_file()
    k8s_env = load_all_configmaps_and_secrets(project_root)
    env.update(k8s_env)
    
    print(f"{GREEN}📦 Loaded {len(env)} environment variables{RESET}")
    print()
    
    # Initialize docker manager
    manager = DockerServiceManager(str(project_root))
    network_name = "deepiri-dev-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = [
        "postgres_dev_data", "pgadmin_dev_data", 
        "redis_dev_data", "influxdb_dev_data",
        "mlflow_dev_data", "cyrex_dev_cache",
        "milvus_dev_data", "etcd_dev_data", "minio_dev_data"
    ]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("dev", env, network_name, project_root)
    
    # Add InfluxDB
    services.append({
        "image": "influxdb:2.7",
        "name": "deepiri-influxdb-dev",
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
            "influxdb_dev_data": "/var/lib/influxdb2"
        },
        "network": network_name,
    })
    
    # Add etcd, MinIO, Milvus for AI services
    services.append({
        "image": "quay.io/coreos/etcd:v3.5.5",
        "name": "deepiri-etcd-dev",
        "environment": {
            "ETCD_AUTO_COMPACTION_MODE": "revision",
            "ETCD_AUTO_COMPACTION_RETENTION": "1000",
        },
        "volumes": {
            "etcd_dev_data": "/etcd"
        },
        "network": network_name,
        "command": "etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd",
    })
    
    services.append({
        "image": "minio/minio:latest",
        "name": "deepiri-minio-dev",
        "ports": {"9000/tcp": 9000, "9001/tcp": 9001},
        "environment": {
            "MINIO_ACCESS_KEY": env.get("MINIO_ACCESS_KEY", "minioadmin"),
            "MINIO_SECRET_KEY": env.get("MINIO_SECRET_KEY", "minioadmin"),
        },
        "volumes": {
            "minio_dev_data": "/data"
        },
        "network": network_name,
        "command": "minio server /data --console-address :9001",
    })
    
    services.append({
        "image": "milvusdb/milvus:v2.3.0",
        "name": "deepiri-milvus-dev",
        "ports": {"19530/tcp": 19530, "9091/tcp": 9091},
        "environment": {
            "ETCD_ENDPOINTS": "deepiri-etcd-dev:2379",
            "MINIO_ADDRESS": "deepiri-minio-dev:9000",
        },
        "volumes": {
            "milvus_dev_data": "/var/lib/milvus"
        },
        "network": network_name,
        "command": ["milvus", "run", "standalone"],
        "depends_on": [("deepiri-etcd-dev", 5), ("deepiri-minio-dev", 5)],
    })
    
    # Get ALL services (backend + frontend + AI)
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    
    # Backend services
    backend_services = get_backend_team_services(project_root, env, network_name, "dev")
    services.extend(backend_services)
    
    # Frontend services
    frontend_services = get_frontend_team_services(project_root, env, network_name, "dev")
    services.extend(frontend_services)
    
    # AI services
    ai_services = get_ai_team_services(project_root, env, network_name, "dev")
    services.extend(ai_services)
    
    # Start services
    print(f"{GREEN}Starting ALL services...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-dev")
    
    print()
    print(f"{GREEN}✅ Development Environment Started!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print()
    print("  🌐 Frontend & UI:")
    print("     - Frontend:        http://localhost:5173")
    print("     - Cyrex Interface: http://localhost:5175")
    print()
    print("  🔧 Backend Services:")
    print("     - API Gateway:     http://localhost:5100")
    print("     - Auth Service:    http://localhost:5001")
    print("     - Task Orchestrator: http://localhost:5002")
    print("     - Engagement:      http://localhost:5003")
    print("     - Analytics:       http://localhost:5004")
    print("     - Notifications:   http://localhost:5005")
    print("     - External Bridge: http://localhost:5006")
    print("     - Challenges:      http://localhost:5007")
    print("     - Realtime:        http://localhost:5008")
    print()
    print("  🤖 AI/ML Services:")
    print("     - Cyrex API:       http://localhost:8000")
    print("     - MLflow:          http://localhost:5500")
    print("     - Jupyter:         http://localhost:8888")
    print()
    print("  💾 Infrastructure:")
    print("     - pgAdmin:         http://localhost:5050")
    print("     - Adminer:         http://localhost:8080")
    print("     - InfluxDB:        http://localhost:8086")
    print("     - MinIO Console:   http://localhost:9001")
    print()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Interrupted by user{RESET}")
        sys.exit(1)
    except Exception as e:
        print(f"{YELLOW}❌ Error: {e}{RESET}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
