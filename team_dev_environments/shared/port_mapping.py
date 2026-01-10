"""
Port mapping configuration for each team to avoid conflicts.
Each team gets unique host ports so they can run simultaneously.
"""

# Port offsets per team (added to base ports)
TEAM_PORT_OFFSETS = {
    "backend": 0,      # Base ports: 5001-5008, 5100, 5173, etc.
    "frontend": 100,   # 5101-5108, 5200, 5273, etc.
    "ai": 200,         # 5201-5208, 5300, 5373, etc.
    "ml": 300,         # 5301-5308, 5400, 5473, etc.
    "qa": 400,         # 5401-5408, 5500, 5573, etc.
    "platform": 500,   # 5501-5508, 5600, 5673, etc.
    "infrastructure": 600,  # 5601-5608, 5700, 5773, etc.
}

# Base ports for services
BASE_PORTS = {
    "auth-service": 5001,
    "task-orchestrator": 5002,
    "engagement-service": 5003,
    "platform-analytics-service": 5004,
    "notification-service": 5005,
    "external-bridge-service": 5006,
    "challenge-service": 5007,
    "realtime-gateway": 5008,
    "api-gateway": 5100,
    "frontend": 5173,
    "cyrex": 8000,
    "mlflow": 5500,
    "jupyter": 8888,
    "postgres": 5432,
    "pgadmin": 5050,
    "adminer": 8080,
    "redis": 6379,
    "influxdb": 8086,
    "minio": 9000,
    "minio-console": 9001,
    "milvus": 19530,
    "milvus-metrics": 9091,
    "etcd": 2379,
}

# Special ports that should NOT be offset (shared infrastructure)
SHARED_PORTS = {
    "postgres": 5432,  # Each team uses different container, but can share host port via different networks
    "pgadmin": 5050,   # Each team gets their own instance
    "adminer": 8080,   # Each team gets their own instance
    "redis": 6379,     # Each team gets their own instance
    "influxdb": 8086,  # Each team gets their own instance
    "minio": 9000,
    "minio-console": 9001,
    "milvus": 19530,
    "milvus-metrics": 9091,
    "etcd": 2379,
}


def get_port(service_name: str, team_suffix: str) -> int:
    """
    Get the host port for a service based on team.
    
    Args:
        service_name: Name of the service (e.g., "auth-service", "api-gateway")
        team_suffix: Team suffix (e.g., "backend", "frontend", "ai")
    
    Returns:
        Host port number
    """
    # Normalize team suffix
    if team_suffix.endswith("-team"):
        team_suffix = team_suffix.replace("-team", "")
    if team_suffix == "platform-engineers":
        team_suffix = "platform"
    if team_suffix == "infrastructure-team":
        team_suffix = "infrastructure"
    
    # Get base port
    base_port = BASE_PORTS.get(service_name)
    if base_port is None:
        # Try to find by partial match
        for key, port in BASE_PORTS.items():
            if key in service_name or service_name in key:
                base_port = port
                break
    
    if base_port is None:
        raise ValueError(f"Unknown service: {service_name}")
    
    # Check if this is a shared port (infrastructure services)
    if service_name in SHARED_PORTS or any(key in service_name for key in SHARED_PORTS.keys()):
        # For shared services, use base port but teams use different containers/networks
        # However, to avoid conflicts on host, we still offset them
        offset = TEAM_PORT_OFFSETS.get(team_suffix, 0)
        # For infrastructure, use smaller offsets to keep ports reasonable
        if service_name in ["postgres", "pgadmin", "adminer"]:
            # Use different ports for these to avoid conflicts
            if team_suffix == "backend":
                return base_port
            elif team_suffix == "frontend":
                return base_port + 1
            elif team_suffix == "ai":
                return base_port + 2
            elif team_suffix == "ml":
                return base_port + 3
            elif team_suffix == "qa":
                return base_port + 4
            elif team_suffix == "platform":
                return base_port + 5
            elif team_suffix == "infrastructure":
                return base_port + 6
        elif service_name == "redis":
            # Redis: backend uses 6379, others use 6380+
            if team_suffix == "backend":
                return 6379
            elif team_suffix == "frontend":
                return 6380
            elif team_suffix == "ai":
                return 6381
            elif team_suffix == "ml":
                return 6382
            elif team_suffix == "qa":
                return 6383
            elif team_suffix == "platform":
                return 6384
            elif team_suffix == "infrastructure":
                return 6385
        elif service_name == "influxdb":
            # InfluxDB: increment by 1 per team
            if team_suffix == "backend":
                return 8086
            elif team_suffix == "frontend":
                return 8087
            elif team_suffix == "ai":
                return 8088
            elif team_suffix == "ml":
                return 8089
            elif team_suffix == "qa":
                return 8090
            elif team_suffix == "platform":
                return 8091
            elif team_suffix == "infrastructure":
                return 8092
        else:
            # Other shared services (minio, milvus, etc.) - use base port
            return base_port
    
    # For application services, apply offset
    offset = TEAM_PORT_OFFSETS.get(team_suffix, 0)
    return base_port + offset


def get_container_port(service_name: str) -> int:
    """
    Get the container-internal port for a service (doesn't change per team).
    
    Args:
        service_name: Name of the service
    
    Returns:
        Container port number
    """
    return BASE_PORTS.get(service_name, 5000)

