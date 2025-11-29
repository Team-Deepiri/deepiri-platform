#!/usr/bin/env python3
"""
ML Team - Local Environment Runner
Mimics Kubernetes by injecting ConfigMaps and Secrets into Docker Compose
"""

import os
import sys
import yaml
import subprocess
from pathlib import Path

# Colors for output
GREEN = '\033[92m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
GRAY = '\033[90m'
RESET = '\033[0m'

def load_k8s_config(yaml_file):
    """Load environment variables from k8s ConfigMap or Secret YAML"""
    if not yaml_file.exists():
        return {}
    
    with open(yaml_file, 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)
    
    env_vars = {}
    
    # Extract from ConfigMap (data section)
    if 'data' in config:
        for key, value in config['data'].items():
            env_vars[key] = str(value)
    
    # Extract from Secret (stringData section)
    if 'stringData' in config:
        for key, value in config['stringData'].items():
            env_vars[key] = str(value)
    
    return env_vars

def load_all_configmaps_and_secrets():
    """Load all ConfigMaps and Secrets from ops/k8s/"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    k8s_dir = project_root / 'ops' / 'k8s'
    
    all_env_vars = {}
    
    # Load all ConfigMaps
    configmaps_dir = k8s_dir / 'configmaps'
    if configmaps_dir.exists():
        for configmap_file in configmaps_dir.glob('*.yaml'):
            env_vars = load_k8s_config(configmap_file)
            all_env_vars.update(env_vars)
            print(f"{GRAY}   ✓ Loaded {len(env_vars)} vars from {configmap_file.name}{RESET}")
    
    # Load all Secrets
    secrets_dir = k8s_dir / 'secrets'
    if secrets_dir.exists():
        for secret_file in secrets_dir.glob('*.yaml'):
            if secret_file.name.endswith('.example'):
                continue  # Skip example files
            env_vars = load_k8s_config(secret_file)
            all_env_vars.update(env_vars)
            print(f"{GRAY}   ✓ Loaded {len(env_vars)} vars from {secret_file.name}{RESET}")
    
    return all_env_vars

def run_docker_compose():
    """Run docker-compose with injected environment variables"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    print(f"{GREEN}🚀 Starting ML Team Environment...{RESET}")
    print(f"{CYAN}   (Loading k8s ConfigMaps & Secrets from ops/k8s/){RESET}")
    print()
    
    # Load all k8s config
    env_vars = load_all_configmaps_and_secrets()
    
    print()
    print(f"{GREEN}📦 Loaded {len(env_vars)} environment variables{RESET}")
    print()
    
    # Inject into current environment
    os.environ.update(env_vars)
    
    # Run docker-compose
    compose_file = project_root / 'docker-compose.ml-team.yml'
    
    try:
        subprocess.run(
            ['docker', 'compose', '-f', str(compose_file), 'up', '-d'],
            cwd=project_root,
            check=True
        )
        
        print()
        print(f"{GREEN}✅ ML Team Environment Started!{RESET}")
        print()
        print(f"{YELLOW}Access your services:{RESET}")
        print("  - Cyrex API:       http://localhost:8000")
        print("  - Jupyter:         http://localhost:8888")
        print("  - MLflow:          http://localhost:5500")
        print("  - Platform Analytics: http://localhost:5004")
        print()
        print(f"{GRAY}View logs:{RESET}")
        print("  docker compose -f docker-compose.ml-team.yml logs -f")
        print()
        
    except subprocess.CalledProcessError as e:
        print(f"{YELLOW}❌ Error starting services: {e}{RESET}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    run_docker_compose()

