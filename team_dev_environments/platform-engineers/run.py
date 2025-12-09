#!/usr/bin/env python3
"""
Platform Engineers - Local Environment Runner (Full Stack)
Uses docker_manager to create and run containers programmatically
Based on SERVICE_TEAM_MAPPING.md: ALL SERVICES for platform development
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
from service_definitions import get_backend_team_services, get_frontend_team_services, get_ai_team_services
from port_mapping import get_port


def main():
    """Start platform engineers services using docker_manager - ALL SERVICES."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    print(f"{GREEN}🚀 Starting Platform Engineers Environment (Full Stack)...{RESET}")
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
    network_name = "deepiri-platform-engineers-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = [
        "postgres_platform_engineers_data", "pgadmin_platform_engineers_data", 
        "redis_platform_engineers_data", "influxdb_platform_engineers_data",
        "mlflow_platform_engineers_data", "cyrex_platform_engineers_cache",
        "milvus_platform_engineers_data", "etcd_platform_engineers_data", "minio_platform_engineers_data"
    ]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("platform-engineers", env, network_name, project_root)
    
    # Add InfluxDB
    influxdb_host_port = get_port("influxdb", "platform")
    services.append({
        "image": "influxdb:2.7",
        "name": "deepiri-influxdb-platform-engineers",
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
            "influxdb_platform_engineers_data": "/var/lib/influxdb2"
        },
        "network": network_name,
    })
    
    # Get ALL services (backend + frontend + AI)
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    
    # Backend services
    backend_services = get_backend_team_services(project_root, env, network_name, "platform-engineers")
    services.extend(backend_services)
    
    # Frontend services
    frontend_services = get_frontend_team_services(project_root, env, network_name, "platform-engineers")
    services.extend(frontend_services)
    
    # AI services
    ai_services = get_ai_team_services(project_root, env, network_name, "platform-engineers")
    services.extend(ai_services)
    
    # Start services
    print(f"{GREEN}Starting ALL services for platform development...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-platform-engineers")
    
    print()
    print(f"{GREEN}✅ Platform Engineers Environment Started (Full Stack)!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print(f"  - Frontend:        http://localhost:{get_port('frontend', 'platform')}")
    print(f"  - API Gateway:     http://localhost:{get_port('api-gateway', 'platform')}")
    print("  - All microservices available")
    print(f"  - Cyrex API:       http://localhost:{get_port('cyrex', 'platform')}")
    print(f"  - MLflow:          http://localhost:{get_port('mlflow', 'platform')}")
    print(f"  - Jupyter:         http://localhost:{get_port('jupyter', 'platform')}")
    print(f"  - pgAdmin:         http://localhost:{get_port('pgadmin', 'platform')}")
    print(f"  - Adminer:         http://localhost:{get_port('adminer', 'platform')}")
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
