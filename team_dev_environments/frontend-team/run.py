#!/usr/bin/env python3
"""
Frontend Team - Local Environment Runner
Uses docker_manager to create and run containers programmatically
Based on SERVICE_TEAM_MAPPING.md: Frontend, API Gateway, Realtime Gateway
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
from service_definitions import get_frontend_team_services
from port_mapping import get_port


def main():
    """Start frontend team services using docker_manager."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    print(f"{GREEN}🚀 Starting Frontend Team Environment...{RESET}")
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
    network_name = "deepiri-frontend-network"
    manager.network_name = network_name
    
    # Ensure network exists
    manager.ensure_network()
    
    # Create volumes
    volumes = ["postgres_frontend_data", "pgadmin_frontend_data", "redis_frontend_data"]
    for volume in volumes:
        create_volume_if_not_exists(volume)
    
    # Get base infrastructure services
    services = get_base_services("frontend-team", env, network_name, project_root)
    
    # Get frontend team services
    frontend_services = get_frontend_team_services(project_root, env, network_name, "frontend")
    services.extend(frontend_services)
    
    # Start services
    print(f"{GREEN}Starting services...{RESET}")
    started = manager.start_services(services, wait_for_dependencies=True)
    
    # Wait for PostgreSQL
    print(f"{CYAN}Waiting for PostgreSQL to be ready...{RESET}")
    wait_for_postgres("deepiri-postgres-frontend")
    
    print()
    print(f"{GREEN}✅ Frontend Team Environment Started!{RESET}")
    print()
    print(f"{YELLOW}Access your services:{RESET}")
    print(f"  - Frontend:        http://localhost:{get_port('frontend', 'frontend')}")
    print(f"  - API Gateway:     http://localhost:{get_port('api-gateway', 'frontend')}")
    print(f"  - Auth Service:    http://localhost:{get_port('auth-service', 'frontend')}")
    print(f"  - Realtime Gateway: http://localhost:{get_port('realtime-gateway', 'frontend')}")
    print(f"  - pgAdmin:         http://localhost:{get_port('pgadmin', 'frontend')}")
    print(f"  - Adminer:         http://localhost:{get_port('adminer', 'frontend')}")
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
