"""
Schema Registry with Versioning
Manages event schema versions and provides schema lookup
"""
import redis.asyncio as redis
from typing import Dict, Any, Optional, List
from datetime import datetime
import json
from enum import Enum


class SchemaCompatibility(Enum):
    """Schema compatibility levels"""
    BACKWARD = "backward"  # New schema can read old data
    FORWARD = "forward"    # Old schema can read new data
    FULL = "full"         # Both backward and forward compatible
    NONE = "none"         # No compatibility


class SchemaRegistry:
    """Manages event schema versions and compatibility"""
    
    def __init__(self, redis_client: redis.Redis):
        """Initialize schema registry"""
        self.redis = redis_client
        self.registry_key_prefix = "schema:registry:"
        self.version_key_prefix = "schema:version:"
    
    async def register_schema(
        self,
        stream_name: str,
        event_type: str,
        schema_version: str,
        schema_definition: Dict[str, Any],
        compatibility: SchemaCompatibility = SchemaCompatibility.BACKWARD
    ) -> bool:
        """
        Register a new schema version
        
        Args:
            stream_name: Stream name (e.g., "model-events")
            event_type: Event type (e.g., "model-ready")
            schema_version: Schema version (e.g., "1.0.0")
            schema_definition: Schema definition (JSON Schema or Pydantic model schema)
            compatibility: Compatibility level
        
        Returns:
            True if registered successfully
        """
        schema_key = f"{stream_name}:{event_type}"
        version_key = f"{self.version_key_prefix}{schema_key}"
        registry_key = f"{self.registry_key_prefix}{schema_key}"
        
        # Check if version already exists
        existing_version = await self.redis.hget(version_key, schema_version)
        if existing_version:
            return False  # Version already exists
        
        # Get latest version
        latest_version = await self.get_latest_version(stream_name, event_type)
        
        # Validate compatibility if not first version
        if latest_version:
            if not await self._check_compatibility(
                latest_version,
                schema_definition,
                compatibility
            ):
                raise ValueError(
                    f"Schema version {schema_version} is not compatible with "
                    f"latest version {latest_version}"
                )
        
        # Store schema definition
        schema_data = {
            "version": schema_version,
            "schema": json.dumps(schema_definition),
            "compatibility": compatibility.value,
            "registered_at": datetime.utcnow().isoformat(),
            "stream_name": stream_name,
            "event_type": event_type
        }
        
        # Store in Redis hash
        await self.redis.hset(
            version_key,
            mapping={schema_version: json.dumps(schema_data)}
        )
        
        # Update registry with latest version
        await self.redis.hset(
            registry_key,
            mapping={
                "latest_version": schema_version,
                "updated_at": datetime.utcnow().isoformat()
            }
        )
        
        # Add to version list
        await self.redis.zadd(
            f"{registry_key}:versions",
            {schema_version: self._version_to_score(schema_version)}
        )
        
        return True
    
    async def get_schema(
        self,
        stream_name: str,
        event_type: str,
        version: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Get schema definition for a specific version
        
        Args:
            stream_name: Stream name
            event_type: Event type
            version: Schema version (None for latest)
        
        Returns:
            Schema definition or None if not found
        """
        schema_key = f"{stream_name}:{event_type}"
        version_key = f"{self.version_key_prefix}{schema_key}"
        
        if version is None:
            version = await self.get_latest_version(stream_name, event_type)
            if not version:
                return None
        
        schema_data = await self.redis.hget(version_key, version)
        if not schema_data:
            return None
        
        return json.loads(schema_data)
    
    async def get_latest_version(
        self,
        stream_name: str,
        event_type: str
    ) -> Optional[str]:
        """Get latest schema version"""
        schema_key = f"{stream_name}:{event_type}"
        registry_key = f"{self.registry_key_prefix}{schema_key}"
        
        return await self.redis.hget(registry_key, "latest_version")
    
    async def list_versions(
        self,
        stream_name: str,
        event_type: str
    ) -> List[str]:
        """List all versions for a schema"""
        schema_key = f"{stream_name}:{event_type}"
        version_key = f"{self.version_key_prefix}{schema_key}"
        
        versions = await self.redis.hkeys(version_key)
        return sorted(versions, key=self._version_to_score, reverse=True)
    
    async def get_all_schemas(self) -> Dict[str, Any]:
        """Get all registered schemas"""
        pattern = f"{self.registry_key_prefix}*"
        keys = await self._scan_keys(pattern)
        
        schemas = {}
        for key in keys:
            # Extract stream_name and event_type from key
            parts = key.replace(self.registry_key_prefix, "").split(":")
            if len(parts) >= 2:
                stream_name = parts[0]
                event_type = ":".join(parts[1:])
                schema_key = f"{stream_name}:{event_type}"
                
                latest_version = await self.get_latest_version(stream_name, event_type)
                if latest_version:
                    schema = await self.get_schema(stream_name, event_type, latest_version)
                    if schema:
                        schemas[schema_key] = {
                            "latest_version": latest_version,
                            "schema": schema
                        }
        
        return schemas
    
    async def _check_compatibility(
        self,
        old_version: str,
        new_schema: Dict[str, Any],
        compatibility: SchemaCompatibility
    ) -> bool:
        """
        Check schema compatibility
        
        For now, returns True (full compatibility check would require
        JSON Schema validation library)
        """
        # TODO: Implement proper compatibility checking
        # This would involve comparing field additions/removals
        # and checking compatibility rules
        return True
    
    def _version_to_score(self, version: str) -> float:
        """Convert semantic version to numeric score for sorting"""
        try:
            parts = version.split(".")
            major = int(parts[0]) if len(parts) > 0 else 0
            minor = int(parts[1]) if len(parts) > 1 else 0
            patch = int(parts[2]) if len(parts) > 2 else 0
            
            # Score = major * 1000000 + minor * 1000 + patch
            return major * 1000000 + minor * 1000 + patch
        except (ValueError, IndexError):
            return 0.0
    
    async def _scan_keys(self, pattern: str) -> List[str]:
        """Scan Redis keys matching pattern"""
        keys = []
        cursor = 0
        while True:
            cursor, batch = await self.redis.scan(cursor, match=pattern, count=100)
            keys.extend(batch)
            if cursor == 0:
                break
        return keys

