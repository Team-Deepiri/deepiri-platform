#!/usr/bin/env python3
"""
AI Team - Local Environment Runner
Mimics Kubernetes by injecting ConfigMaps and Secrets into Docker Compose
"""

import os
import sys
import subprocess
from pathlib import Path

# Import shared k8s loader
from k8s_env_loader import load_all_configmaps_and_secrets, GREEN, YELLOW, CYAN, GRAY, RESET


def run_docker_compose():
    """Run docker-compose with injected environment variables"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    print(f"{GREEN}🚀 Starting AI Team Environment...{RESET}")
    print(f"{CYAN}   (Loading k8s ConfigMaps & Secrets from ops/k8s/){RESET}")
    print()
    
    # Load all k8s config
    env_vars = load_all_configmaps_and_secrets(project_root)
    
    print()
    print(f"{GREEN}📦 Loaded {len(env_vars)} environment variables{RESET}")
    print()
    
    # Inject into current environment
    os.environ.update(env_vars)
    
    # Run docker-compose
    compose_file = project_root / 'docker-compose.ai-team.yml'
    
    try:
        subprocess.run(
            ['docker', 'compose', '-f', str(compose_file), 'up', '-d'],
            cwd=project_root,
            check=True
        )
        
        print()
        print(f"{GREEN}✅ AI Team Environment Started!{RESET}")
        print()
        print(f"{YELLOW}Access your services:{RESET}")
        print("  - Cyrex API:       http://localhost:8000")
        print("  - Cyrex Interface: http://localhost:5175")
        print("  - MLflow:          http://localhost:5500")
        print("  - Jupyter:         http://localhost:8888")
        print("  - MinIO Console:   http://localhost:9001")
        print()
        print(f"{GRAY}View logs:{RESET}")
        print("  docker compose -f docker-compose.ai-team.yml logs -f")
        print()
        
    except subprocess.CalledProcessError as e:
        print(f"{YELLOW}❌ Error starting services: {e}{RESET}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"{YELLOW}❌ Error: 'docker' command not found. Is Docker installed?{RESET}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    run_docker_compose()
