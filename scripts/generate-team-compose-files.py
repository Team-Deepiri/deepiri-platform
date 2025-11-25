#!/usr/bin/env python3
"""
Generate team-specific docker-compose files from docker-compose.dev.yml
Each team's compose file will only include the services they need.
"""

import yaml
import sys
from pathlib import Path

# Team service mappings (from their start.sh scripts)
TEAM_SERVICES = {
    'ai-team': [
        'mongodb', 'influxdb', 'redis', 'etcd', 'minio', 'milvus',
        'cyrex', 'jupyter', 'mlflow', 'challenge-service'
    ],
    'ml-team': [
        'mongodb', 'influxdb', 'redis',
        'cyrex', 'jupyter', 'mlflow', 'platform-analytics-service'
    ],
    'backend-team': [
        'mongodb', 'redis', 'influxdb',
        'api-gateway', 'auth-service', 'task-orchestrator',
        'engagement-service', 'platform-analytics-service',
        'notification-service', 'external-bridge-service',
        'challenge-service', 'realtime-gateway'
    ],
    'frontend-team': [
        'mongodb', 'redis', 'influxdb',
        'api-gateway', 'auth-service', 'task-orchestrator',
        'engagement-service', 'platform-analytics-service',
        'notification-service', 'external-bridge-service',
        'challenge-service', 'realtime-gateway', 'frontend-dev'
    ],
    'infrastructure-team': None,  # All services
    'platform-engineers': None,  # All services
    'qa-team': None,  # All services
}

# Team name mappings for container/volume/network names
TEAM_NAMES = {
    'ai-team': 'ai',
    'ml-team': 'ml',
    'backend-team': 'backend',
    'frontend-team': 'frontend',
    'infrastructure-team': 'infrastructure',
    'platform-engineers': 'platform',
    'qa-team': 'qa',
}

def update_container_names(service_def, team_suffix):
    """Update container names in service definition"""
    if 'container_name' in service_def:
        # Replace -dev with -{team_suffix}
        service_def['container_name'] = service_def['container_name'].replace('-dev', f'-{team_suffix}')
    return service_def

def update_volumes(volumes_dict, team_suffix):
    """Update volume names"""
    updated = {}
    for vol_name, vol_def in volumes_dict.items():
        # Replace _dev_data with _{team_suffix}_data, or _cache with _{team_suffix}_cache
        new_name = vol_name.replace('_dev_data', f'_{team_suffix}_data')
        new_name = new_name.replace('_cache', f'_{team_suffix}_cache')
        updated[new_name] = vol_def
    return updated

def update_volume_refs_in_service(service_def, team_suffix):
    """Update volume references in service definition"""
    if 'volumes' in service_def:
        updated_volumes = []
        for vol in service_def['volumes']:
            if isinstance(vol, str) and ':' in vol:
                # Named volume reference (e.g., mongodb_dev_data:/data/db)
                parts = vol.split(':')
                if len(parts) == 2:
                    vol_name = parts[0]
                    # Update volume name
                    new_vol_name = vol_name.replace('_dev_data', f'_{team_suffix}_data')
                    new_vol_name = new_vol_name.replace('_cache', f'_{team_suffix}_cache')
                    updated_volumes.append(f'{new_vol_name}:{parts[1]}')
                else:
                    updated_volumes.append(vol)
            else:
                updated_volumes.append(vol)
        service_def['volumes'] = updated_volumes
    return service_def

def generate_team_compose(team_name, services_list, compose_data):
    """Generate a team-specific docker-compose file"""
    team_suffix = TEAM_NAMES[team_name]
    
    # Create new compose structure
    new_compose = {
        'name': f'deepiri-{team_suffix}',
        'x-build-args': compose_data.get('x-build-args', {}),
        'x-logging': compose_data.get('x-logging', {}),
        'services': {},
        'volumes': {},
        'networks': {}
    }
    
    # Copy header comments
    if services_list is None:
        # All services
        new_compose['services'] = compose_data['services'].copy()
        new_compose['volumes'] = compose_data['volumes'].copy()
        new_compose['networks'] = compose_data['networks'].copy()
    else:
        # Only selected services
        for service_name in services_list:
            if service_name in compose_data['services']:
                service_def = compose_data['services'][service_name].copy()
                # Update container names
                service_def = update_container_names(service_def, team_suffix)
                # Update volume references
                service_def = update_volume_refs_in_service(service_def, team_suffix)
                # Update network references
                if 'networks' in service_def:
                    service_def['networks'] = [f'deepiri-{team_suffix}-network']
                new_compose['services'][service_name] = service_def
        
        # Add required volumes (only those used by selected services)
        used_volumes = set()
        for service_def in new_compose['services'].values():
            if 'volumes' in service_def:
                for vol in service_def['volumes']:
                    if isinstance(vol, str) and ':' in vol and not vol.startswith('./') and not vol.startswith('/'):
                        vol_name = vol.split(':')[0]
                        used_volumes.add(vol_name)
        
        # Copy volume definitions
        for vol_name, vol_def in compose_data['volumes'].items():
            # Check if this volume is used (or a variant of it)
            for used_vol in used_volumes:
                if vol_name.replace('_dev_data', '') in used_vol.replace(f'_{team_suffix}_data', ''):
                    new_vol_name = vol_name.replace('_dev_data', f'_{team_suffix}_data')
                    new_vol_name = new_vol_name.replace('_cache', f'_{team_suffix}_cache')
                    new_compose['volumes'][new_vol_name] = vol_def
                    break
    
    # Update network name
    if 'networks' in compose_data:
        network_name = list(compose_data['networks'].keys())[0]
        new_compose['networks'][f'deepiri-{team_suffix}-network'] = compose_data['networks'][network_name].copy()
    
    return new_compose

def main():
    repo_root = Path(__file__).parent.parent
    dev_compose_path = repo_root / 'docker-compose.dev.yml'
    
    # Read docker-compose.dev.yml
    with open(dev_compose_path, 'r') as f:
        compose_data = yaml.safe_load(f)
    
    # Generate each team's compose file
    for team_name, services_list in TEAM_SERVICES.items():
        new_compose = generate_team_compose(team_name, services_list, compose_data)
        
        # Write to file
        output_path = repo_root / f'docker-compose.{team_name}.yml'
        with open(output_path, 'w') as f:
            # Write header comment
            f.write(f"# {team_name.replace('-', ' ').title()} Docker Compose Configuration\n")
            f.write(f"# Generated from docker-compose.dev.yml\n")
            f.write(f"# Services: {', '.join(services_list) if services_list else 'ALL SERVICES'}\n\n")
            
            # Write YAML
            yaml.dump(new_compose, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        print(f"✅ Generated {output_path}")

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

