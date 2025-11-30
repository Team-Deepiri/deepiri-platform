"""
Shared Docker utilities for team dev environments
Provides helper functions for creating and managing containers
"""

import sys
import subprocess
import time
from pathlib import Path

# Add py_environment_startup_scripts to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'py_environment_startup_scripts'))

try:
    from docker_manager import DockerServiceManager, load_env_file
except ImportError:
    print("Warning: Could not import docker_manager. Some features may not work.")
    DockerServiceManager = None
    load_env_file = None

# Import port mapping
from port_mapping import get_port

# Colors for output
GREEN = '\033[92m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
GRAY = '\033[90m'
RESET = '\033[0m'


def wait_for_postgres(container_name: str = "postgres", max_attempts: int = 30, delay: int = 2):
    """Wait for PostgreSQL to be ready by checking the container directly."""
    import docker
    try:
        client = docker.from_env()
        attempts = 0
        while attempts < max_attempts:
            try:
                container = client.containers.get(container_name)
                # Check if container is running
                if container.status == "running":
                    # Try to execute pg_isready
                    result = container.exec_run(
                        "pg_isready -U deepiri",
                        user="postgres"
                    )
                    if result.exit_code == 0:
                        print(f"{GREEN}✓ PostgreSQL is ready!{RESET}")
                        return True
            except Exception:
                pass
            attempts += 1
            if attempts < max_attempts:
                print(f"{GRAY}Waiting for PostgreSQL... ({attempts}/{max_attempts}){RESET}")
                time.sleep(delay)
        
        print(f"{YELLOW}⚠ PostgreSQL may not be fully ready{RESET}")
        return False
    except Exception as e:
        print(f"{YELLOW}⚠ Could not check PostgreSQL status: {e}{RESET}")
        return False


def create_volume_if_not_exists(volume_name: str):
    """Create a Docker volume if it doesn't exist."""
    import docker
    try:
        client = docker.from_env()
        try:
            client.volumes.get(volume_name)
        except docker.errors.NotFound:
            client.volumes.create(volume_name)
            print(f"{GREEN}✓ Created volume: {volume_name}{RESET}")
    except Exception as e:
        print(f"{YELLOW}⚠ Could not create volume {volume_name}: {e}{RESET}")


def get_base_services(team_name: str, env: dict, network_name: str, project_root: Path):
    """Get base infrastructure services (postgres, pgadmin, adminer, redis) for a team."""
    # Handle team name variations
    if team_name.endswith('-team'):
        team_suffix = team_name.replace('-team', '')
    elif team_name == 'platform-engineers':
        team_suffix = 'platform'
    elif team_name == 'infrastructure-team':
        team_suffix = 'infrastructure'
    elif team_name == 'dev':
        team_suffix = 'dev'
    else:
        team_suffix = team_name
    init_script = project_root / "scripts" / "postgres-init.sql"
    
    # Get unique ports for this team
    postgres_host_port = get_port("postgres", team_suffix)
    pgadmin_host_port = get_port("pgadmin", team_suffix)
    adminer_host_port = get_port("adminer", team_suffix)
    redis_host_port = get_port("redis", team_suffix)
    
    services = [
        # PostgreSQL
        {
            "image": "postgres:16-alpine",
            "name": f"deepiri-postgres-{team_suffix}",
            "ports": {"5432/tcp": postgres_host_port},
            "environment": {
                "POSTGRES_USER": env.get("POSTGRES_USER", "deepiri"),
                "POSTGRES_PASSWORD": env.get("POSTGRES_PASSWORD", "deepiripassword"),
                "POSTGRES_DB": env.get("POSTGRES_DB", "deepiri"),
            },
            "volumes": {
                f"postgres_{team_suffix}_data": "/var/lib/postgresql/data",
            },
            "network": network_name,
        },
        # pgAdmin
        {
            "image": "dpage/pgadmin4:latest",
            "name": f"deepiri-pgadmin-{team_suffix}",
            "ports": {"80/tcp": pgadmin_host_port},
            "environment": {
                "PGADMIN_DEFAULT_EMAIL": env.get("PGADMIN_EMAIL", "admin@deepiri.local"),
                "PGADMIN_DEFAULT_PASSWORD": env.get("PGADMIN_PASSWORD", "admin"),
                "PGADMIN_CONFIG_SERVER_MODE": "False",
            },
            "volumes": {
                f"pgadmin_{team_suffix}_data": "/var/lib/pgadmin"
            },
            "network": network_name,
            "depends_on": [(f"deepiri-postgres-{team_suffix}", 5)],
        },
        # Adminer
        {
            "image": "adminer:latest",
            "name": f"deepiri-adminer-{team_suffix}",
            "ports": {"8080/tcp": adminer_host_port},
            "environment": {
                "ADMINER_DEFAULT_SERVER": "postgres",
            },
            "network": network_name,
            "depends_on": [(f"deepiri-postgres-{team_suffix}", 3)],
        },
        # Redis
        {
            "image": "redis:7.2-alpine",
            "name": f"deepiri-redis-{team_suffix}",
            "ports": {"6379/tcp": redis_host_port},
            "command": f"redis-server --requirepass {env.get('REDIS_PASSWORD', 'redispassword')}",
            "volumes": {
                f"redis_{team_suffix}_data": "/data"
            },
            "network": network_name,
        },
    ]
    
    # Add init script volume if it exists
    if init_script.exists():
        services[0]["volumes"][str(init_script)] = {
            "bind": "/docker-entrypoint-initdb.d/init.sql",
            "mode": "ro"
        }
    
    return services

