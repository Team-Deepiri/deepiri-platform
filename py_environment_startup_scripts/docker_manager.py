"""
Docker Management Utility for Deepiri Services
Provides functions to start, stop, and manage Docker containers for different team roles.
"""
import os
import sys
import time
import docker
from pathlib import Path
from typing import List, Dict, Optional, Any
from docker.errors import NotFound, APIError

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Try to use existing utils_docker if available
try:
    from utils_docker import DOCKER_CLIENT, ensure_network, wait_for_mongo
except ImportError:
    # Fallback: create Docker client
    try:
        DOCKER_CLIENT = docker.from_env()
    except Exception as e:
        print(f"Error connecting to Docker: {e}")
        print("Please ensure Docker is running.")
        sys.exit(1)

    def ensure_network(network_name: str):
        """Ensure the Docker network exists."""
        try:
            DOCKER_CLIENT.networks.get(network_name)
            print(f"Network {network_name} already exists.")
        except NotFound:
            DOCKER_CLIENT.networks.create(network_name)
            print(f"Network {network_name} created.")

    def wait_for_mongo(network: str, db_url: str, db_user: str = "admin", 
                      db_password: str = "password", max_attempts: int = 30, delay: int = 2):
        """Wait for MongoDB to be ready."""
        import subprocess
        host, port = db_url.split(":")
        attempts = 0
        while attempts < max_attempts:
            try:
                subprocess.run(
                    ["docker", "run", "--rm", "--network", network, "mongo:7.0",
                     "mongosh", f"mongodb://{db_user}:{db_password}@{host}:{port}/admin",
                     "--eval", "db.adminCommand('ping')"],
                    check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
                print(f"MongoDB is accepting connections on {db_url}!")
                return
            except subprocess.CalledProcessError:
                print(f"Waiting for MongoDB... ({attempts + 1}/{max_attempts})")
                time.sleep(delay)
                attempts += 1
        raise RuntimeError(f"MongoDB did not become ready after {max_attempts} attempts.")


class DockerServiceManager:
    """Manages Docker services for Deepiri."""
    
    def __init__(self, project_root: Optional[str] = None):
        self.project_root = project_root or Path(__file__).parent.parent
        self.network_name = "deepiri-network"
        self.containers: Dict[str, Any] = {}
        
    def ensure_network(self):
        """Ensure the Docker network exists."""
        ensure_network(self.network_name)
        
    def get_container(self, container_name: str):
        """Get a container by name."""
        try:
            return DOCKER_CLIENT.containers.get(container_name)
        except NotFound:
            return None
            
    def is_running(self, container_name: str) -> bool:
        """Check if a container is running."""
        container = self.get_container(container_name)
        return container is not None and container.status == "running"
        
    def stop_container(self, container_name: str):
        """Stop a container."""
        container = self.get_container(container_name)
        if container:
            if container.status == "running":
                print(f"Stopping {container_name}...")
                container.stop()
                print(f"✓ Stopped {container_name}")
            else:
                print(f"{container_name} is not running (status: {container.status})")
        else:
            print(f"{container_name} not found")
            
    def remove_container(self, container_name: str):
        """Remove a container."""
        container = self.get_container(container_name)
        if container:
            if container.status == "running":
                container.stop()
            container.remove()
            print(f"✓ Removed {container_name}")
        else:
            print(f"{container_name} not found")
            
    def start_container(self, config: Dict[str, Any], wait_for_ready: bool = False):
        """Start a container from configuration."""
        container_name = config.get("name")
        
        if not container_name:
            raise ValueError("Container config must include 'name'")
            
        # Check if already running
        if self.is_running(container_name):
            print(f"✓ {container_name} is already running")
            return self.get_container(container_name)
            
        # Remove existing container if it exists
        existing = self.get_container(container_name)
        if existing:
            print(f"Removing existing {container_name}...")
            self.remove_container(container_name)
            
        # Ensure network exists
        network_name = config.get("network", self.network_name)
        if network_name:
            self.ensure_network()
        
        # Handle image building if needed
        image = config.get("image")
        if image is None and "build" in config:
            print(f"Building image for {container_name}...")
            build_config = config["build"]
            image, _ = DOCKER_CLIENT.images.build(**build_config)
            image = image.tags[0] if image.tags else image.id
            print(f"✓ Built image: {image}")
        elif image is None:
            raise ValueError(f"Container {container_name} must have either 'image' or 'build' config")
        
        # Prepare container run parameters
        run_config = {
            "image": image,
            "name": container_name,
            "detach": config.get("detach", True),
            "restart_policy": config.get("restart_policy", {"Name": "unless-stopped"}),
        }
        
        # Add network (use network_mode or network parameter)
        if network_name:
            run_config["network"] = network_name
        
        # Add ports if specified
        if "ports" in config:
            run_config["ports"] = config["ports"]
        
        # Add environment variables
        if "environment" in config:
            run_config["environment"] = config["environment"]
        
        # Add volumes (handle both dict and list formats)
        if "volumes" in config:
            volumes = {}
            for vol_key, vol_value in config["volumes"].items():
                if isinstance(vol_value, dict):
                    # Already in correct format
                    volumes[vol_key] = vol_value
                elif isinstance(vol_value, str):
                    # Host path to container path mapping
                    volumes[vol_key] = {"bind": vol_value, "mode": "rw"}
                else:
                    # Named volume - use volume name as both key and bind path
                    volumes[vol_key] = {"bind": f"/{vol_key}", "mode": "rw"}
            run_config["volumes"] = volumes
        
        # Add command if specified
        if "command" in config:
            run_config["command"] = config["command"]
        
        print(f"Starting {container_name}...")
        try:
            container = DOCKER_CLIENT.containers.run(**run_config)
            print(f"✓ Started {container_name}")
            
            if wait_for_ready:
                self.wait_for_service(container_name, config.get("wait_url"))
                
            return container
        except Exception as e:
            print(f"✗ Error starting {container_name}: {e}")
            import traceback
            traceback.print_exc()
            raise
            
    def wait_for_service(self, container_name: str, health_url: Optional[str] = None, 
                        max_attempts: int = 30, delay: int = 2):
        """Wait for a service to be ready."""
        if health_url:
            import subprocess
            attempts = 0
            while attempts < max_attempts:
                try:
                    result = subprocess.run(
                        ["docker", "run", "--rm", "--network", self.network_name,
                         "curlimages/curl:latest", "-f", health_url],
                        capture_output=True, timeout=5
                    )
                    if result.returncode == 0:
                        print(f"✓ {container_name} is ready")
                        return
                except Exception:
                    pass
                attempts += 1
                print(f"Waiting for {container_name}... ({attempts}/{max_attempts})")
                time.sleep(delay)
            print(f"⚠ {container_name} may not be fully ready")
        else:
            # Just wait a bit for container to start
            time.sleep(2)
            
    def start_services(self, services: List[Dict[str, Any]], wait_for_dependencies: bool = True):
        """Start multiple services in order."""
        self.ensure_network()
        
        started = []
        for service in services:
            try:
                container = self.start_container(service)
                started.append(service["name"])
                
                # Wait for dependencies if needed
                if wait_for_dependencies:
                    deps = service.get("depends_on", [])
                    for dep in deps:
                        if isinstance(dep, str):
                            wait_time = 3
                        else:
                            dep_name, wait_time = dep
                        print(f"Waiting {wait_time}s for {dep} to initialize...")
                        time.sleep(wait_time)
                        
            except Exception as e:
                print(f"✗ Failed to start {service.get('name', 'unknown')}: {e}")
                
        return started
        
    def stop_services(self, container_names: List[str]):
        """Stop multiple containers."""
        for name in container_names:
            self.stop_container(name)
            
    def list_running(self) -> List[str]:
        """List all running Deepiri containers."""
        running = []
        try:
            containers = DOCKER_CLIENT.containers.list(filters={"name": "deepiri"})
            for container in containers:
                if container.status == "running":
                    running.append(container.name)
        except Exception as e:
            print(f"Error listing containers: {e}")
        return running
        
    def get_status(self) -> Dict[str, str]:
        """Get status of all Deepiri containers."""
        status = {}
        try:
            containers = DOCKER_CLIENT.containers.list(all=True, filters={"name": "deepiri"})
            for container in containers:
                status[container.name] = container.status
        except Exception as e:
            print(f"Error getting status: {e}")
        return status


def load_env_file(env_file: str = ".env") -> Dict[str, str]:
    """Load environment variables from .env file."""
    env_vars = {}
    env_path = Path(__file__).parent.parent / env_file
    
    if env_path.exists():
        with open(env_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    env_vars[key.strip()] = value.strip().strip('"').strip("'")
    
    # Also load from actual environment
    import os
    for key in env_vars:
        if key in os.environ:
            env_vars[key] = os.environ[key]
            
    return env_vars

