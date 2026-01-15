"""
Tests for Schema Registry
"""
import pytest
import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

# Ensure we can import app module
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.schemas.registry import SchemaRegistry, SchemaCompatibility


@pytest.fixture
def mock_redis():
    """Create a mock Redis client"""
    redis_mock = AsyncMock()
    redis_mock.hget = AsyncMock(return_value=None)
    redis_mock.hset = AsyncMock()
    redis_mock.hkeys = AsyncMock(return_value=[])
    redis_mock.zadd = AsyncMock()
    redis_mock.scan = AsyncMock(return_value=(0, []))
    return redis_mock


@pytest.fixture
def schema_registry(mock_redis):
    """Create SchemaRegistry instance with mock Redis"""
    return SchemaRegistry(mock_redis)


@pytest.mark.asyncio
async def test_register_schema_success(schema_registry, mock_redis):
    """Test successful schema registration"""
    schema_def = {
        "type": "object",
        "properties": {
            "event": {"type": "string"},
            "model_name": {"type": "string"}
        }
    }
    
    # Mock: version doesn't exist
    mock_redis.hget.return_value = None
    
    result = await schema_registry.register_schema(
        stream_name="model-events",
        event_type="model-ready",
        schema_version="1.0.0",
        schema_definition=schema_def,
        compatibility=SchemaCompatibility.BACKWARD
    )
    
    assert result is True
    # Verify Redis operations were called
    assert mock_redis.hset.called
    assert mock_redis.zadd.called


@pytest.mark.asyncio
async def test_register_schema_duplicate_version(schema_registry, mock_redis):
    """Test registering duplicate schema version"""
    # Mock: version already exists
    mock_redis.hget.return_value = json.dumps({"version": "1.0.0"})
    
    result = await schema_registry.register_schema(
        stream_name="model-events",
        event_type="model-ready",
        schema_version="1.0.0",
        schema_definition={},
        compatibility=SchemaCompatibility.BACKWARD
    )
    
    assert result is False


@pytest.mark.asyncio
async def test_get_schema_latest_version(schema_registry, mock_redis):
    """Test getting latest schema version"""
    schema_data = {
        "version": "1.0.0",
        "schema": json.dumps({"type": "object"}),
        "compatibility": "backward",
        "registered_at": "2024-01-01T00:00:00",
        "stream_name": "model-events",
        "event_type": "model-ready"
    }
    
    # Mock: latest version exists
    mock_redis.hget.side_effect = [
        "1.0.0",  # get_latest_version call
        json.dumps(schema_data)  # get_schema call
    ]
    
    schema = await schema_registry.get_schema(
        stream_name="model-events",
        event_type="model-ready"
    )
    
    assert schema is not None
    assert schema["version"] == "1.0.0"


@pytest.mark.asyncio
async def test_get_schema_specific_version(schema_registry, mock_redis):
    """Test getting specific schema version"""
    schema_data = {
        "version": "1.0.0",
        "schema": json.dumps({"type": "object"}),
        "compatibility": "backward"
    }
    
    mock_redis.hget.return_value = json.dumps(schema_data)
    
    schema = await schema_registry.get_schema(
        stream_name="model-events",
        event_type="model-ready",
        version="1.0.0"
    )
    
    assert schema is not None
    assert schema["version"] == "1.0.0"


@pytest.mark.asyncio
async def test_get_schema_not_found(schema_registry, mock_redis):
    """Test getting non-existent schema"""
    mock_redis.hget.return_value = None
    
    schema = await schema_registry.get_schema(
        stream_name="model-events",
        event_type="model-ready",
        version="999.0.0"
    )
    
    assert schema is None


@pytest.mark.asyncio
async def test_get_latest_version(schema_registry, mock_redis):
    """Test getting latest version"""
    mock_redis.hget.return_value = "1.0.0"
    
    version = await schema_registry.get_latest_version(
        stream_name="model-events",
        event_type="model-ready"
    )
    
    assert version == "1.0.0"


@pytest.mark.asyncio
async def test_list_versions(schema_registry, mock_redis):
    """Test listing all versions"""
    mock_redis.hkeys.return_value = ["1.0.0", "1.1.0", "2.0.0"]
    
    versions = await schema_registry.list_versions(
        stream_name="model-events",
        event_type="model-ready"
    )
    
    assert len(versions) == 3
    assert "1.0.0" in versions
    assert "2.0.0" in versions


@pytest.mark.asyncio
async def test_get_all_schemas(schema_registry, mock_redis):
    """Test getting all registered schemas"""
    # Mock scan to return registry keys
    mock_redis.scan.return_value = (0, ["schema:registry:model-events:model-ready"])
    mock_redis.hget.side_effect = [
        "1.0.0",  # latest_version
        json.dumps({  # schema
            "version": "1.0.0",
            "schema": json.dumps({"type": "object"}),
            "compatibility": "backward"
        })
    ]
    
    schemas = await schema_registry.get_all_schemas()
    
    assert isinstance(schemas, dict)


@pytest.mark.asyncio
async def test_version_to_score(schema_registry):
    """Test version to score conversion"""
    score_1 = schema_registry._version_to_score("1.0.0")
    score_2 = schema_registry._version_to_score("1.1.0")
    score_3 = schema_registry._version_to_score("2.0.0")
    
    assert score_1 < score_2 < score_3
    assert score_1 == 1000000  # 1 * 1000000 + 0 * 1000 + 0


@pytest.mark.asyncio
async def test_schema_compatibility_enum():
    """Test SchemaCompatibility enum values"""
    assert SchemaCompatibility.BACKWARD.value == "backward"
    assert SchemaCompatibility.FORWARD.value == "forward"
    assert SchemaCompatibility.FULL.value == "full"
    assert SchemaCompatibility.NONE.value == "none"

