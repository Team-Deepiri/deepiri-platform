#!/usr/bin/env python3
"""
ML Team - Local Environment Runner
Uses docker_manager to create and run containers programmatically
Based on SERVICE_TEAM_MAPPING.md: Cyrex, Jupyter, MLflow, Analytics Service
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
from service_definitions import get_ml_team_services
from port_mapping import get_port
from port_mapping import get_port


def main():
    """Start ML team services using docker_manager."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    print(f"{GREEN}🚀 Starting ML Team Environment...{RESET}")
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
    network_name = "deepiri-ml-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = [
        "postgres_ml_data", "pgadmin_ml_data", 
        "redis_ml_data", "influxdb_ml_data",
        "mlflow_ml_data", "cyrex_ml_cache"
    ]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("ml-team", env, network_name, project_root)
    
    # Add InfluxDB
    influxdb_host_port = get_port("influxdb", "ml")
    services.append({
        "image": "influxdb:2.7",
        "name": "deepiri-influxdb-ml",
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
            "influxdb_ml_data": "/var/lib/influxdb2"
        },
        "network": network_name,
    })
    
    # Get ML team services
    ml_services = get_ml_team_services(project_root, env, network_name, "ml")
    services.extend(ml_services)
    
    # Start services
    print(f"{GREEN}Starting services...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-ml")
    
    print()
    print(f"{GREEN}✅ ML Team Environment Started!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print(f"  - Cyrex API:       http://localhost:{get_port('cyrex', 'ml')}")
    print(f"  - MLflow:          http://localhost:{get_port('mlflow', 'ml')}")
    print(f"  - Jupyter:         http://localhost:{get_port('jupyter', 'ml')}")
    print(f"  - Analytics Service: http://localhost:{get_port('platform-analytics-service', 'ml')}")
    print(f"  - pgAdmin:         http://localhost:{get_port('pgadmin', 'ml')}")
    print(f"  - Adminer:         http://localhost:{get_port('adminer', 'ml')}")
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
