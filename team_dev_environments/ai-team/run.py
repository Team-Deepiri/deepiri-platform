#!/usr/bin/env python3
"""
AI Team - Local Environment Runner
Uses docker_manager to create and run containers programmatically
Based on SERVICE_TEAM_MAPPING.md: Cyrex, Jupyter, MLflow, Challenge Service
"""

import os
import sys
from pathlib import Path

# Add shared utilities to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'shared'))
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'py_environment_startup_scripts'))

from k8s_env_loader import load_all_configmaps_and_secrets, GREEN, YELLOW, CYAN, GRAY, RESET
from docker_manager import DockerServiceManager, load_env_file
from docker_utils import wait_for_postgres, get_base_services, create_volume_if_not_exists
from service_definitions import get_ai_team_services
from port_mapping import get_port


def main():
    """Start AI team services using docker_manager."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    print(f"{GREEN}🚀 Starting AI Team Environment...{RESET}")
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
    network_name = "deepiri-ai-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = [
        "postgres_ai_data", "pgadmin_ai_data", 
        "redis_ai_data", "influxdb_ai_data",
        "mlflow_ai_data", "cyrex_ai_cache",
        "milvus_ai_data", "etcd_ai_data", "minio_ai_data",
        "ollama_ai_data"
    ]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("ai-team", env, network_name, project_root)
    
    # Add InfluxDB
    influxdb_host_port = get_port("influxdb", "ai")
    services.append({
        "image": "influxdb:2.7",
        "name": "deepiri-influxdb-ai",
        "ports": {"8086/tcp": influxdb_host_port},
        "environment": {
            "DOCKER_INFLUXDB_INIT_MODE": "setup",
            "DOCKER_INFLUXDB_INIT_USERNAME": env.get("INFLUXDB_USER", "admin"),
            "DOCKER_INFLUXDB_INIT_PASSWORD": env.get("INFLUXDB_PASSWORD", "adminpassword"),
            "DOCKER_INFLUXDB_INIT_ORG": env.get("INFLUXDB_ORG", "deepiri"),
            "DOCKER_INFLUXDB_INIT_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN": env.get("INFLUXDB_TOKEN", "your-influxdb-token"),
        },
        "volumes": {
            "influxdb_ai_data": "/var/lib/influxdb2"
        },
        "network": network_name,
    })
    
    # Add etcd, MinIO, Milvus for AI services
    services.append({
        "image": "quay.io/coreos/etcd:v3.5.5",
        "name": "deepiri-etcd-ai",
        "environment": {
            "ETCD_AUTO_COMPACTION_MODE": "revision",
            "ETCD_AUTO_COMPACTION_RETENTION": "1000",
        },
        "volumes": {
            "etcd_ai_data": "/etcd"
        },
        "network": network_name,
        "command": "etcd -advertise-client-urls=http://127.0.0.1:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd",
    })
    
    minio_host_port = get_port("minio", "ai")
    minio_console_host_port = get_port("minio-console", "ai")
    services.append({
        "image": "minio/minio:latest",
        "name": "deepiri-minio-ai",
        "ports": {"9000/tcp": minio_host_port, "9001/tcp": minio_console_host_port},
        "environment": {
            "MINIO_ACCESS_KEY": env.get("MINIO_ACCESS_KEY", "minioadmin"),
            "MINIO_SECRET_KEY": env.get("MINIO_SECRET_KEY", "minioadmin"),
        },
        "volumes": {
            "minio_ai_data": "/data"
        },
        "network": network_name,
        "command": "minio server /data --console-address :9001",
    })
    
    milvus_host_port = get_port("milvus", "ai")
    milvus_metrics_host_port = get_port("milvus-metrics", "ai")
    services.append({
        "image": "milvusdb/milvus:v2.3.0",
        "name": "deepiri-milvus-ai",
        "ports": {"19530/tcp": milvus_host_port, "9091/tcp": milvus_metrics_host_port},
        "environment": {
            "ETCD_ENDPOINTS": "deepiri-etcd-ai:2379",
            "MINIO_ADDRESS": "deepiri-minio-ai:9000",
        },
        "volumes": {
            "milvus_ai_data": "/var/lib/milvus"
        },
        "network": network_name,
        "command": ["milvus", "run", "standalone"],
        "depends_on": [("deepiri-etcd-ai", 5), ("deepiri-minio-ai", 5)],
    })
    
    # Add Ollama service
    ollama_host_port = get_port("ollama", "ai")
    services.append({
        "image": "ollama/ollama:latest",
        "name": "deepiri-ollama-ai",
        "ports": {"11434/tcp": ollama_host_port},
        "volumes": {
            "ollama_ai_data": "/root/.ollama"
        },
        "network": network_name,
    })
    
    # Get AI team services
    ai_services = get_ai_team_services(project_root, env, network_name, "ai")
    services.extend(ai_services)
    
    # Start services
    print(f"{GREEN}Starting services...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-ai")
    
    print()
    print(f"{GREEN}✅ AI Team Environment Started!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print(f"  - Cyrex API:       http://localhost:{get_port('cyrex', 'ai')}")
    print(f"  - Ollama:          http://localhost:{get_port('ollama', 'ai')}")
    print(f"  - MLflow:          http://localhost:{get_port('mlflow', 'ai')}")
    print(f"  - Jupyter:         http://localhost:{get_port('jupyter', 'ai')}")
    print(f"  - Challenge Service: http://localhost:{get_port('challenge-service', 'ai')}")
    print(f"  - pgAdmin:         http://localhost:{get_port('pgadmin', 'ai')}")
    print(f"  - Adminer:         http://localhost:{get_port('adminer', 'ai')}")
    print(f"  - MinIO Console:   http://localhost:{get_port('minio-console', 'ai')}")
    print()
    print(f"{CYAN}💡 To pull models into Ollama: docker exec -it deepiri-ollama-ai ollama pull llama3:8b{RESET}")
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
