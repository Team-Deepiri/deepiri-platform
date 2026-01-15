"""
Tests for Dead Letter Queue
"""
import pytest
import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
from datetime import datetime

# Ensure we can import app module
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.streams.dead_letter_queue import DeadLetterQueue


@pytest.fixture
def mock_redis():
    """Create a mock Redis client"""
    redis_mock = AsyncMock()
    redis_mock.xadd = AsyncMock(return_value="dlq-1234567890-0")
    redis_mock.xrevrange = AsyncMock(return_value=[])
    redis_mock.xrange = AsyncMock(return_value=[])
    redis_mock.xlen = AsyncMock(return_value=0)
    redis_mock.xdel = AsyncMock()
    redis_mock.hincrby = AsyncMock()
    redis_mock.hset = AsyncMock()
    redis_mock.scan = AsyncMock(return_value=(0, []))
    return redis_mock


@pytest.fixture
def dead_letter_queue(mock_redis):
    """Create DeadLetterQueue instance"""
    return DeadLetterQueue(mock_redis)


@pytest.mark.asyncio
async def test_add_failed_event(dead_letter_queue, mock_redis):
    """Test adding failed event to DLQ"""
    event_data = {
        "event": "model-ready",
        "model_name": "classifier"
    }
    
    message_id = await dead_letter_queue.add_failed_event(
        stream_name="model-events",
        event_data=event_data,
        error_message="Validation failed: missing required field",
        failure_type="validation_error"
    )
    
    assert message_id == "dlq-1234567890-0"
    assert mock_redis.xadd.called
    
    # Check that DLQ event contains required fields
    call_args = mock_redis.xadd.call_args
    dlq_event = call_args[0][1]  # Second argument is the event data
    
    assert dlq_event["original_stream"] == "model-events"
    assert "validation failed" in dlq_event["error_message"].lower()
    assert dlq_event["failure_type"] == "validation_error"
    assert dlq_event["can_retry"] == "true"


@pytest.mark.asyncio
async def test_add_failed_event_max_retries(dead_letter_queue, mock_redis):
    """Test adding failed event with max retries exceeded"""
    event_data = {"event": "model-ready"}
    
    message_id = await dead_letter_queue.add_failed_event(
        stream_name="model-events",
        event_data=event_data,
        error_message="Error",
        failure_type="validation_error",
        retry_count=3,
        max_retries=3
    )
    
    assert message_id is not None
    
    call_args = mock_redis.xadd.call_args
    dlq_event = call_args[0][1]
    
    assert dlq_event["can_retry"] == "false"


@pytest.mark.asyncio
async def test_get_failed_events(dead_letter_queue, mock_redis):
    """Test retrieving failed events"""
    # Mock DLQ messages
    mock_messages = [
        (
            "1234567890-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Validation failed",
                "failure_type": "validation_error",
                "retry_count": "0",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "true"
            }
        )
    ]
    
    mock_redis.xrevrange.return_value = mock_messages
    
    failed_events = await dead_letter_queue.get_failed_events(
        stream_name="model-events",
        count=10
    )
    
    assert len(failed_events) == 1
    assert failed_events[0]["original_stream"] == "model-events"
    assert failed_events[0]["error_message"] == "Validation failed"
    assert failed_events[0]["can_retry"] is True


@pytest.mark.asyncio
async def test_get_failed_events_filter_by_type(dead_letter_queue, mock_redis):
    """Test filtering failed events by failure type"""
    mock_messages = [
        (
            "1234567890-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Validation failed",
                "failure_type": "validation_error",
                "retry_count": "0",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "true"
            }
        ),
        (
            "1234567891-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Processing failed",
                "failure_type": "processing_error",
                "retry_count": "0",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "true"
            }
        )
    ]
    
    mock_redis.xrevrange.return_value = mock_messages
    
    failed_events = await dead_letter_queue.get_failed_events(
        stream_name="model-events",
        count=10,
        failure_type="validation_error"
    )
    
    assert len(failed_events) == 1
    assert failed_events[0]["failure_type"] == "validation_error"


@pytest.mark.asyncio
async def test_get_failed_events_empty(dead_letter_queue, mock_redis):
    """Test getting failed events when DLQ is empty"""
    mock_redis.xrevrange.return_value = []
    
    failed_events = await dead_letter_queue.get_failed_events(
        stream_name="model-events"
    )
    
    assert len(failed_events) == 0


@pytest.mark.asyncio
async def test_retry_event_success(dead_letter_queue, mock_redis):
    """Test successful retry of failed event"""
    from app.middleware.validation import ValidationMiddleware
    
    # Mock DLQ message
    mock_messages = [
        (
            "1234567890-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Validation failed",
                "failure_type": "validation_error",
                "retry_count": "0",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "true"
            }
        )
    ]
    
    mock_redis.xrange.return_value = mock_messages
    
    # Mock validation middleware
    mock_middleware = AsyncMock()
    mock_middleware.validate_and_publish = AsyncMock(
        return_value=(True, "new-1234567890-0", None)
    )
    
    success, new_msg_id, error = await dead_letter_queue.retry_event(
        stream_name="model-events",
        dlq_message_id="1234567890-0",
        validation_middleware=mock_middleware
    )
    
    assert success is True
    assert new_msg_id == "new-1234567890-0"
    assert error is None
    # Verify old DLQ entry was deleted
    assert mock_redis.xdel.called


@pytest.mark.asyncio
async def test_retry_event_failure(dead_letter_queue, mock_redis):
    """Test retry failure increments retry count"""
    # Mock DLQ message
    mock_messages = [
        (
            "1234567890-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Validation failed",
                "failure_type": "validation_error",
                "retry_count": "0",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "true"
            }
        )
    ]
    
    mock_redis.xrange.return_value = mock_messages
    
    # Mock validation middleware that fails
    mock_middleware = AsyncMock()
    mock_middleware.validate_and_publish = AsyncMock(
        return_value=(False, None, "Still invalid")
    )
    
    success, new_msg_id, error = await dead_letter_queue.retry_event(
        stream_name="model-events",
        dlq_message_id="1234567890-0",
        validation_middleware=mock_middleware
    )
    
    assert success is False
    assert error is not None
    # Verify new DLQ entry was created with incremented retry count
    assert mock_redis.xadd.called


@pytest.mark.asyncio
async def test_retry_event_max_retries_exceeded(dead_letter_queue, mock_redis):
    """Test retry when max retries exceeded"""
    # Mock DLQ message with max retries exceeded
    mock_messages = [
        (
            "1234567890-0",
            {
                "original_stream": "model-events",
                "event_data": json.dumps({"event": "model-ready"}),
                "error_message": "Validation failed",
                "failure_type": "validation_error",
                "retry_count": "3",
                "max_retries": "3",
                "failed_at": datetime.utcnow().isoformat(),
                "can_retry": "false"
            }
        )
    ]
    
    mock_redis.xrange.return_value = mock_messages
    
    mock_middleware = AsyncMock()
    
    success, new_msg_id, error = await dead_letter_queue.retry_event(
        stream_name="model-events",
        dlq_message_id="1234567890-0",
        validation_middleware=mock_middleware
    )
    
    assert success is False
    assert "Max retries exceeded" in error


@pytest.mark.asyncio
async def test_get_dlq_stats_single_stream(dead_letter_queue, mock_redis):
    """Test getting DLQ stats for single stream"""
    mock_redis.xlen.return_value = 5
    
    stats = await dead_letter_queue.get_dlq_stats(stream_name="model-events")
    
    assert stats["stream"] == "model-events"
    assert stats["failed_events_count"] == 5
    assert "dlq_stream" in stats


@pytest.mark.asyncio
async def test_get_dlq_stats_all_streams(dead_letter_queue, mock_redis):
    """Test getting DLQ stats for all streams"""
    # Mock scan to return DLQ stream keys
    mock_redis.scan.return_value = (0, ["dlq:model-events", "dlq:inference-events"])
    mock_redis.xlen.side_effect = [10, 5]
    
    stats = await dead_letter_queue.get_dlq_stats()
    
    assert stats["total_failed_events"] == 15
    assert "streams" in stats
    assert "model-events" in stats["streams"]
    assert "inference-events" in stats["streams"]


@pytest.mark.asyncio
async def test_get_dlq_stats_stream_not_found(dead_letter_queue, mock_redis):
    """Test getting DLQ stats for non-existent stream"""
    mock_redis.xlen.side_effect = Exception("Stream not found")
    
    stats = await dead_letter_queue.get_dlq_stats(stream_name="nonexistent")
    
    assert stats["failed_events_count"] == 0

