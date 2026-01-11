"""
Service definitions for each team based on SERVICE_TEAM_MAPPING.md
Provides functions to get all services needed by each team
"""

from pathlib import Path
from typing import List, Dict, Any
from port_mapping import get_port, get_container_port


def get_microservice_config(
    name: str,
    container_name: str,
    port: int,
    project_root: Path,
    service_path: str,
    database_url: str,
    redis_url: str = None,
    additional_env: Dict[str, str] = None,
    depends_on: List[str] = None,
    network_name: str = "deepiri-dev-network",
    team_suffix: str = "dev",
    command: str = None
) -> Dict[str, Any]:
    """Get configuration for a microservice."""
    # Get unique host port for this team
    host_port = get_port(name, team_suffix)
    container_port = get_container_port(name)
    
    env = {
        "NODE_ENV": "development",
        "PORT": str(container_port),
        "DATABASE_URL": database_url,
    }
    if redis_url:
        env["REDIS_URL"] = redis_url
    if additional_env:
        env.update(additional_env)
    
    # Map service names to container names
    service_to_container = {
        "postgres": f"deepiri-postgres-{team_suffix}",
        "redis": f"deepiri-redis-{team_suffix}",
        "influxdb": f"deepiri-influxdb-{team_suffix}",
    }
    
    deps = depends_on or ["postgres"]
    # Convert service names to container names
    mapped_deps = []
    for dep in deps:
        if dep in service_to_container:
            mapped_deps.append(service_to_container[dep])
        elif dep.startswith("deepiri-"):
            mapped_deps.append(dep)
        else:
            # Assume it's already a container name
            mapped_deps.append(dep)
    
    config = {
        "name": container_name,
        "build": {
            "path": str(project_root / service_path),
            "dockerfile": "Dockerfile",
        },
        "ports": {f"{container_port}/tcp": host_port},
        "environment": env,
        "volumes": {
            str(project_root / service_path): "/app",
            str(project_root / "platform-services" / "shared" / "deepiri-shared-utils"): "/shared-utils",
            "/app/node_modules": {}
        },
        "network": network_name,
        "depends_on": [(dep, 5) for dep in mapped_deps],
    }
    
    # Add /shared-utils/node_modules volume for services that use shared-utils
    if name in ["challenge-service", "auth-service", "engagement-service", "external-bridge-service", 
                "notification-service", "platform-analytics-service", "task-orchestrator", "realtime-gateway",
                "language-intelligence-service"]:
        config["volumes"]["/shared-utils/node_modules"] = {}
    
    # Add command if provided
    if command:
        config["command"] = command
    
    return config


def get_backend_team_services(project_root: Path, env: dict, network_name: str, team_suffix: str = "backend") -> List[Dict[str, Any]]:
    """Get all services for Backend Team."""
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    services = []
    
    # API Gateway
    services.append(get_microservice_config(
        "api-gateway",
        f"deepiri-api-gateway-{team_suffix}",
        5100,
        project_root,
        "platform-services/api-gateway",
        database_url,
        redis_url,
        {
            "AUTH_SERVICE_URL": f"http://deepiri-auth-service-{team_suffix}:5001",
            "TASK_ORCHESTRATOR_URL": f"http://deepiri-task-orchestrator-{team_suffix}:5002",
            "ENGAGEMENT_SERVICE_URL": f"http://deepiri-engagement-service-{team_suffix}:5003",
        },
        ["postgres", "redis"],
        network_name,
        team_suffix
    ))
    
    # Auth Service
    services.append(get_microservice_config(
        "auth-service",
        f"deepiri-auth-service-{team_suffix}",
        5001,
        project_root,
        "platform-services/backend/deepiri-auth-service",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    # Task Orchestrator
    services.append(get_microservice_config(
        "task-orchestrator",
        f"deepiri-task-orchestrator-{team_suffix}",
        5002,
        project_root,
        "platform-services/backend/deepiri-task-orchestrator",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    # Engagement Service
    services.append(get_microservice_config(
        "engagement-service",
        f"deepiri-engagement-service-{team_suffix}",
        5003,
        project_root,
        "platform-services/backend/deepiri-engagement-service",
        database_url,
        redis_url,
        None,
        ["postgres", "redis"],
        network_name,
        team_suffix
    ))
    
    # Platform Analytics Service
    services.append(get_microservice_config(
        "platform-analytics-service",
        f"deepiri-platform-analytics-service-{team_suffix}",
        5004,
        project_root,
        "platform-services/backend/deepiri-platform-analytics-service",
        database_url,
        None,
        None,
        ["postgres", "influxdb"],
        network_name,
        team_suffix
    ))
    
    # Notification Service
    services.append(get_microservice_config(
        "notification-service",
        f"deepiri-notification-service-{team_suffix}",
        5005,
        project_root,
        "platform-services/backend/deepiri-notification-service",
        database_url,
        redis_url,
        None,
        ["postgres", "redis"],
        network_name,
        team_suffix
    ))
    
    # External Bridge Service
    services.append(get_microservice_config(
        "external-bridge-service",
        f"deepiri-external-bridge-service-{team_suffix}",
        5006,
        project_root,
        "platform-services/backend/deepiri-external-bridge-service",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    # Challenge Service
    services.append(get_microservice_config(
        "challenge-service",
        f"deepiri-challenge-service-{team_suffix}",
        5007,
        project_root,
        "platform-services/backend/deepiri-challenge-service",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix,
        command="sh -c \"cd /shared-utils && rm -rf node_modules/.caniuse-lite* 2>/dev/null || true && npm cache clean --force && npm install --legacy-peer-deps && npm run build && cd /app && npm cache clean --force && npm install --legacy-peer-deps file:/shared-utils && npm run dev\""
    ))
    
    # Realtime Gateway
    services.append(get_microservice_config(
        "realtime-gateway",
        f"deepiri-realtime-gateway-{team_suffix}",
        5008,
        project_root,
        "platform-services/backend/deepiri-realtime-gateway",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    # Language Intelligence Service
    services.append(get_microservice_config(
        "language-intelligence-service",
        f"deepiri-language-intelligence-service-{team_suffix}",
        5003,
        project_root,
        "platform-services/backend/deepiri-language-intelligence-service",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    return services


def get_ai_team_services(project_root: Path, env: dict, network_name: str, team_suffix: str = "ai") -> List[Dict[str, Any]]:
    """Get all services for AI Team."""
    services = []
    
    # Cyrex AI Service
    cyrex_host_port = get_port("cyrex", team_suffix)
    services.append({
        "name": f"deepiri-cyrex-{team_suffix}",
        "build": {
            "path": str(project_root / "diri-cyrex"),
            "dockerfile": "Dockerfile",
        },
        "ports": {"8000/tcp": cyrex_host_port},
        "environment": {
            "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
            "OPENAI_MODEL": env.get("OPENAI_MODEL", "gpt-4o-mini"),
            "CORS_ORIGIN": "http://localhost:5173",
            "CYREX_API_KEY": env.get("CYREX_API_KEY", "change-me"),
            "MLFLOW_TRACKING_URI": env.get("MLFLOW_TRACKING_URI", f"http://deepiri-mlflow-{team_suffix}:5000"),
            "INFLUXDB_URL": f"http://deepiri-influxdb-{team_suffix}:8086",
            "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", ""),
            "INFLUXDB_ORG": env.get("INFLUXDB_ORG", "deepiri"),
            "INFLUXDB_BUCKET": env.get("INFLUXDB_BUCKET", "analytics"),
            "MILVUS_HOST": f"deepiri-milvus-{team_suffix}",
            "MILVUS_PORT": "19530",
        },
        "volumes": {
            str(project_root / "diri-cyrex" / "app"): "/app/app",
            str(project_root / "diri-cyrex" / "train"): "/app/train",
            str(project_root / "diri-cyrex" / "inference"): "/app/inference",
            f"cyrex_{team_suffix}_cache": "/app/.cache"
        },
        "network": network_name,
        "depends_on": [(f"deepiri-influxdb-{team_suffix}", 5), (f"deepiri-milvus-{team_suffix}", 10)],
    })
    
    # MLflow
    mlflow_host_port = get_port("mlflow", team_suffix)
    services.append({
        "image": "ghcr.io/mlflow/mlflow:v2.8.1",
        "name": f"deepiri-mlflow-{team_suffix}",
        "ports": {"5000/tcp": mlflow_host_port},
        "environment": {
            "BACKEND_STORE_URI": "file:/mlflow",
            "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
        },
        "volumes": {
            f"mlflow_{team_suffix}_data": "/mlflow"
        },
        "network": network_name,
    })
    
    # Jupyter
    jupyter_host_port = get_port("jupyter", team_suffix)
    services.append({
        "name": f"deepiri-jupyter-{team_suffix}",
        "build": {
            "path": str(project_root),
            "dockerfile": "deepiri-modelkit/Dockerfile.jupyter",
        },
        "ports": {"8888/tcp": jupyter_host_port},
        "environment": {
            "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
        },
        "volumes": {
            str(project_root / "diri-cyrex" / "train" / "notebooks"): "/app/notebooks",
            str(project_root / "diri-cyrex" / "train" / "data"): "/app/data",
        },
        "network": network_name,
    })
    
    # Challenge Service
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    services.append(get_microservice_config(
        "challenge-service",
        f"deepiri-challenge-service-{team_suffix}",
        5007,
        project_root,
        "platform-services/backend/deepiri-challenge-service",
        database_url,
        None,
        {"CYREX_URL": f"http://deepiri-cyrex-{team_suffix}:8000"},
        ["postgres", f"deepiri-cyrex-{team_suffix}"],
        network_name,
        team_suffix,
        command="sh -c \"cd /shared-utils && rm -rf node_modules/.caniuse-lite* 2>/dev/null || true && npm cache clean --force && npm install --legacy-peer-deps && npm run build && cd /app && npm cache clean --force && npm install --legacy-peer-deps file:/shared-utils && npm run dev\""
    ))
    
    return services


def get_ml_team_services(project_root: Path, env: dict, network_name: str, team_suffix: str = "ml") -> List[Dict[str, Any]]:
    """Get all services for ML Team."""
    services = []
    
    # Cyrex AI Service (same as AI team)
    cyrex_host_port = get_port("cyrex", team_suffix)
    services.append({
        "name": f"deepiri-cyrex-{team_suffix}",
        "build": {
            "path": str(project_root / "diri-cyrex"),
            "dockerfile": "Dockerfile",
        },
        "ports": {"8000/tcp": cyrex_host_port},
        "environment": {
            "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
            "MLFLOW_TRACKING_URI": env.get("MLFLOW_TRACKING_URI", f"http://deepiri-mlflow-{team_suffix}:5000"),
            "INFLUXDB_URL": f"http://deepiri-influxdb-{team_suffix}:8086",
            "INFLUXDB_TOKEN": env.get("INFLUXDB_TOKEN", ""),
        },
        "volumes": {
            str(project_root / "diri-cyrex" / "app"): "/app/app",
            str(project_root / "diri-cyrex" / "train"): "/app/train",
            f"cyrex_{team_suffix}_cache": "/app/.cache"
        },
        "network": network_name,
        "depends_on": [(f"deepiri-influxdb-{team_suffix}", 5)],
    })
    
    # MLflow
    mlflow_host_port = get_port("mlflow", team_suffix)
    services.append({
        "image": "ghcr.io/mlflow/mlflow:v2.8.1",
        "name": f"deepiri-mlflow-{team_suffix}",
        "ports": {"5000/tcp": mlflow_host_port},
        "environment": {
            "BACKEND_STORE_URI": "file:/mlflow",
            "DEFAULT_ARTIFACT_ROOT": "file:/mlflow/artifacts",
        },
        "volumes": {
            f"mlflow_{team_suffix}_data": "/mlflow"
        },
        "network": network_name,
    })
    
    # Jupyter
    jupyter_host_port = get_port("jupyter", team_suffix)
    services.append({
        "name": f"deepiri-jupyter-{team_suffix}",
        "build": {
            "path": str(project_root),
            "dockerfile": "deepiri-modelkit/Dockerfile.jupyter",
        },
        "ports": {"8888/tcp": jupyter_host_port},
        "environment": {
            "OPENAI_API_KEY": env.get("OPENAI_API_KEY", ""),
        },
        "volumes": {
            str(project_root / "diri-cyrex" / "train" / "notebooks"): "/app/notebooks",
            str(project_root / "diri-cyrex" / "train" / "data"): "/app/data",
        },
        "network": network_name,
    })
    
    # Platform Analytics Service
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    services.append(get_microservice_config(
        "platform-analytics-service",
        f"deepiri-platform-analytics-service-{team_suffix}",
        5004,
        project_root,
        "platform-services/backend/deepiri-platform-analytics-service",
        database_url,
        None,
        None,
        ["postgres", "influxdb"],
        network_name,
        team_suffix
    ))
    
    return services


def get_frontend_team_services(project_root: Path, env: dict, network_name: str, team_suffix: str = "frontend") -> List[Dict[str, Any]]:
    """Get all services for Frontend Team."""
    services = []
    
    # Frontend Service
    frontend_host_port = get_port("frontend", team_suffix)
    services.append({
        "name": f"deepiri-frontend-{team_suffix}",
        "image": "node:20-alpine",
        "ports": {"5173/tcp": frontend_host_port},
        "environment": {
            "VITE_API_BASE_URL": env.get("VITE_API_BASE_URL", f"http://localhost:{get_port('api-gateway', team_suffix)}"),
        },
        "volumes": {
            str(project_root / "deepiri-web-frontend"): "/app",
            "/app/node_modules": {}
        },
        "network": network_name,
        "command": "sh -c 'npm install --legacy-peer-deps && npm run dev -- --host 0.0.0.0 --port 5173'",
    })
    
    # Database URL for microservices
    database_url = f"postgresql://{env.get('POSTGRES_USER', 'deepiri')}:{env.get('POSTGRES_PASSWORD', 'deepiripassword')}@postgres:5432/{env.get('POSTGRES_DB', 'deepiri')}"
    redis_url = f"redis://:{env.get('REDIS_PASSWORD', 'redispassword')}@redis:6379"
    
    # Auth Service (needed by API Gateway)
    services.append(get_microservice_config(
        "auth-service",
        f"deepiri-auth-service-{team_suffix}",
        5001,
        project_root,
        "platform-services/backend/deepiri-auth-service",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    # API Gateway
    services.append(get_microservice_config(
        "api-gateway",
        f"deepiri-api-gateway-{team_suffix}",
        5100,
        project_root,
        "platform-services/backend/deepiri-api-gateway",
        database_url,
        redis_url,
        None,
        ["postgres", "redis", f"deepiri-auth-service-{team_suffix}"],
        network_name,
        team_suffix
    ))
    
    # Realtime Gateway
    services.append(get_microservice_config(
        "realtime-gateway",
        f"deepiri-realtime-gateway-{team_suffix}",
        5008,
        project_root,
        "platform-services/backend/deepiri-realtime-gateway",
        database_url,
        None,
        None,
        ["postgres"],
        network_name,
        team_suffix
    ))
    
    return services

