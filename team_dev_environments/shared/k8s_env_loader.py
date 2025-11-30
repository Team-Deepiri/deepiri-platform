"""
K8s Environment Loader - Shared utility for loading ConfigMaps and Secrets
Mimics Kubernetes secret/configmap injection into containers
"""

import yaml
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
    
    try:
        with open(yaml_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        # Handle empty or invalid YAML
        if not config or not isinstance(config, dict):
            return {}
        
        env_vars = {}
        
        # Extract from ConfigMap (data section)
        if 'data' in config and isinstance(config['data'], dict):
            for key, value in config['data'].items():
                env_vars[key] = str(value)
        
        # Extract from Secret (stringData section)
        if 'stringData' in config and isinstance(config['stringData'], dict):
            for key, value in config['stringData'].items():
                env_vars[key] = str(value)
        
        return env_vars
    except Exception as e:
        print(f"{YELLOW}   ⚠️  Warning: Could not load {yaml_file.name}: {e}{RESET}")
        return {}


def load_all_configmaps_and_secrets(project_root=None):
    """Load all ConfigMaps and Secrets from ops/k8s/"""
    if project_root is None:
        # Assume we're running from team_dev_environments/<team>/
        script_dir = Path(__file__).parent
        project_root = script_dir.parent.parent
    else:
        project_root = Path(project_root)
    
    k8s_dir = project_root / 'ops' / 'k8s'
    
    all_env_vars = {}
    
    # Load all ConfigMaps
    configmaps_dir = k8s_dir / 'configmaps'
    if configmaps_dir.exists():
        for configmap_file in sorted(configmaps_dir.glob('*.yaml')):
            env_vars = load_k8s_config(configmap_file)
            if env_vars:
                all_env_vars.update(env_vars)
                print(f"{GRAY}   ✓ Loaded {len(env_vars)} vars from {configmap_file.name}{RESET}")
    
    # Load all Secrets
    secrets_dir = k8s_dir / 'secrets'
    if secrets_dir.exists():
        for secret_file in sorted(secrets_dir.glob('*.yaml')):
            # Skip example files
            if secret_file.name.endswith('.example'):
                continue
            env_vars = load_k8s_config(secret_file)
            if env_vars:
                all_env_vars.update(env_vars)
                print(f"{GRAY}   ✓ Loaded {len(env_vars)} vars from {secret_file.name}{RESET}")
    
    return all_env_vars

