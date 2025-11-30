#!/usr/bin/env python3
"""
Backend Team - Local Environment Runner
Uses docker_manager to create and run containers programmatically
Based on SERVICE_TEAM_MAPPING.md: All backend microservices
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
from service_definitions import get_backend_team_services
from port_mapping import get_port


def main():
    """Start backend team services using docker_manager."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    print(f"{GREEN}🚀 Starting Backend Team Environment...{RESET}")
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
    network_name = "deepiri-backend-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = [
        "postgres_backend_data", "pgadmin_backend_data", 
        "redis_backend_data", "influxdb_backend_data"
    ]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("backend-team", env, network_name, project_root)
    
    # Add InfluxDB
    influxdb_host_port = get_port("influxdb", "backend")
    services.append({
        "image": "influxdb:2.7",
        "name": "deepiri-influxdb-backend",
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
            "influxdb_backend_data": "/var/lib/influxdb2"
        },
        "network": network_name,
    })
    
    # Get all backend microservices
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    microservices = get_backend_team_services(project_root, env, network_name)
    services.extend(microservices)
    
    # Start services
    print(f"{GREEN}Starting infrastructure services...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-backend")
    
    print()
    print(f"{GREEN}✅ Backend Team Environment Started!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print(f"  - API Gateway:     http://localhost:{get_port('api-gateway', 'backend')}")
    print(f"  - Auth Service:    http://localhost:{get_port('auth-service', 'backend')}")
    print(f"  - Task Orchestrator: http://localhost:{get_port('task-orchestrator', 'backend')}")
    print(f"  - Engagement Service: http://localhost:{get_port('engagement-service', 'backend')}")
    print(f"  - Analytics Service: http://localhost:{get_port('platform-analytics-service', 'backend')}")
    print(f"  - Notification Service: http://localhost:{get_port('notification-service', 'backend')}")
    print(f"  - External Bridge: http://localhost:{get_port('external-bridge-service', 'backend')}")
    print(f"  - Challenge Service: http://localhost:{get_port('challenge-service', 'backend')}")
    print(f"  - Realtime Gateway: http://localhost:{get_port('realtime-gateway', 'backend')}")
    print(f"  - pgAdmin:         http://localhost:{get_port('pgadmin', 'backend')}")
    print(f"  - Adminer:         http://localhost:{get_port('adminer', 'backend')}")
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
