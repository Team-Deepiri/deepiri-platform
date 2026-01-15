"""
Tests for Validation Middleware
"""
import pytest
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

# Ensure we can import app module
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.middleware.validation import ValidationMiddleware
from app.schemas.registry import SchemaRegistry
from app.streams.dead_letter_queue import DeadLetterQueue


@pytest.fixture
def mock_redis():
    """Create a mock Redis client"""
    redis_mock = AsyncMock()
    redis_mock.xadd = AsyncMock(return_value="1234567890-0")
    return redis_mock


@pytest.fixture
def mock_schema_registry():
    """Create a mock SchemaRegistry"""
    registry_mock = AsyncMock()
    registry_mock.get_latest_version = AsyncMock(return_value="1.0.0")
    return registry_mock


@pytest.fixture
def mock_dead_letter_queue():
    """Create a mock DeadLetterQueue"""
    dlq_mock = AsyncMock()
    dlq_mock.add_failed_event = AsyncMock(return_value="dlq-123")
    return dlq_mock


@pytest.fixture
def validation_middleware(mock_redis, mock_schema_registry, mock_dead_letter_queue):
    """Create ValidationMiddleware instance"""
    return ValidationMiddleware(
        redis_client=mock_redis,
        schema_registry=mock_schema_registry,
        dead_letter_queue=mock_dead_letter_queue,
        enable_validation=True,
        enable_schema_registry=True
    )


@pytest.mark.asyncio
@patch('app.middleware.validation.validate_event')
async def test_validate_and_publish_success(mock_validate, validation_middleware, mock_redis):
    """Test successful validation and publishing"""
    # Mock successful validation
    mock_validate.return_value = {
        "event": "model-ready",
        "model_name": "classifier",
        "version": "1.0.0"
    }
    
    event_data = {
        "event": "model-ready",
        "model_name": "classifier",
        "version": "1.0.0"
    }
    
    success, message_id, error = await validation_middleware.validate_and_publish(
        stream_name="model-events",
        event_data=event_data
    )
    
    assert success is True
    assert message_id == "1234567890-0"
    assert error is None
    assert mock_redis.xadd.called
    assert validation_middleware.stats["validated"] == 1


@pytest.mark.asyncio
@patch('app.middleware.validation.validate_event')
async def test_validate_and_publish_validation_failure(
    mock_validate,
    validation_middleware,
    mock_redis,
    mock_dead_letter_queue
):
    """Test validation failure sends event to DLQ"""
    # Mock validation failure
    mock_validate.side_effect = ValueError("Invalid event schema: missing required field")
    
    event_data = {
        "event": "model-ready",
        # Missing required fields
    }
    
    success, message_id, error = await validation_middleware.validate_and_publish(
        stream_name="model-events",
        event_data=event_data
    )
    
    assert success is False
    assert message_id is None
    assert error is not None
    assert "Validation failed" in error
    assert mock_dead_letter_queue.add_failed_event.called
    assert validation_middleware.stats["invalid"] == 1
    assert validation_middleware.stats["sent_to_dlq"] == 1


@pytest.mark.asyncio
async def test_validate_and_publish_with_schema_registry(
    validation_middleware,
    mock_redis,
    mock_schema_registry
):
    """Test schema registry integration"""
    with patch('app.middleware.validation.validate_event') as mock_validate:
        mock_validate.return_value = {"event": "model-ready"}
        
        event_data = {"event": "model-ready", "model_name": "classifier"}
        
        await validation_middleware.validate_and_publish(
            stream_name="model-events",
            event_data=event_data
        )
        
        # Verify schema registry was checked
        mock_schema_registry.get_latest_version.assert_called_once_with(
            "model-events",
            "model-ready"
        )


@pytest.mark.asyncio
async def test_validate_and_publish_disabled_validation(
    mock_redis,
    mock_schema_registry,
    mock_dead_letter_queue
):
    """Test with validation disabled"""
    middleware = ValidationMiddleware(
        redis_client=mock_redis,
        schema_registry=mock_schema_registry,
        dead_letter_queue=mock_dead_letter_queue,
        enable_validation=False
    )
    
    event_data = {"event": "model-ready"}
    
    success, message_id, error = await middleware.validate_and_publish(
        stream_name="model-events",
        event_data=event_data
    )
    
    assert success is True
    assert message_id is not None
    # Validation should be skipped
    assert middleware.stats["validated"] == 0


@pytest.mark.asyncio
async def test_validate_and_publish_redis_error(
    validation_middleware,
    mock_redis,
    mock_dead_letter_queue
):
    """Test handling Redis errors"""
    with patch('app.middleware.validation.validate_event') as mock_validate:
        mock_validate.return_value = {"event": "model-ready"}
        
        # Mock Redis error
        mock_redis.xadd.side_effect = Exception("Redis connection error")
        
        event_data = {"event": "model-ready"}
        
        success, message_id, error = await validation_middleware.validate_and_publish(
            stream_name="model-events",
            event_data=event_data
        )
        
        assert success is False
        assert error is not None
        assert mock_dead_letter_queue.add_failed_event.called


@pytest.mark.asyncio
async def test_get_stats(validation_middleware):
    """Test getting validation statistics"""
    # Set some stats
    validation_middleware.stats = {
        "validated": 100,
        "invalid": 5,
        "sent_to_dlq": 5
    }
    
    stats = validation_middleware.get_stats()
    
    assert stats["validated"] == 100
    assert stats["invalid"] == 5
    assert stats["sent_to_dlq"] == 5
    assert stats["total_processed"] == 105
    assert "success_rate_percent" in stats


@pytest.mark.asyncio
async def test_reset_stats(validation_middleware):
    """Test resetting statistics"""
    validation_middleware.stats = {
        "validated": 100,
        "invalid": 5,
        "sent_to_dlq": 5
    }
    
    validation_middleware.reset_stats()
    
    assert validation_middleware.stats["validated"] == 0
    assert validation_middleware.stats["invalid"] == 0
    assert validation_middleware.stats["sent_to_dlq"] == 0


@pytest.mark.asyncio
async def test_metadata_added_to_event(validation_middleware, mock_redis):
    """Test that validation metadata is added to events"""
    with patch('app.middleware.validation.validate_event') as mock_validate:
        mock_validate.return_value = {"event": "model-ready"}
        
        event_data = {"event": "model-ready"}
        
        await validation_middleware.validate_and_publish(
            stream_name="model-events",
            event_data=event_data
        )
        
        # Check that xadd was called with metadata
        call_args = mock_redis.xadd.call_args
        published_data = call_args[0][1]  # Second argument is the event data
        
        assert "metadata" in published_data
        assert published_data["metadata"]["validated"] is True
        assert "validated_at" in published_data["metadata"]

