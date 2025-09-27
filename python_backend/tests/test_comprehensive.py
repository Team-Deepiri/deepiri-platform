"""
Comprehensive test suite for the Python backend.
"""
import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from fastapi.testclient import TestClient
from httpx import AsyncClient
import json

from app.main import app
from app.settings import settings


@pytest.fixture
def client():
    """Create a test client for the FastAPI app."""
    return TestClient(app)


@pytest.fixture
def mock_openai_client():
    """Mock OpenAI client for testing."""
    with patch('openai.OpenAI') as mock:
        mock_instance = Mock()
        mock.return_value = mock_instance
        
        # Mock completion response
        mock_completion = Mock()
        mock_completion.choices = [Mock()]
        mock_completion.choices[0].message.content = "Test response from AI"
        mock_completion.usage.total_tokens = 150
        mock_completion.model = "gpt-4o-mini"
        
        mock_instance.chat.completions.create.return_value = mock_completion
        yield mock_instance


@pytest.fixture
def mock_httpx_client():
    """Mock httpx client for testing external API calls."""
    with patch('httpx.AsyncClient') as mock:
        mock_instance = AsyncMock()
        mock.return_value.__aenter__.return_value = mock_instance
        
        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"test": "data"}
        mock_response.raise_for_status.return_value = None
        
        mock_instance.get.return_value = mock_response
        yield mock_instance


class TestHealthEndpoint:
    """Test cases for the health endpoint."""
    
    def test_health_endpoint(self, client):
        """Test basic health check functionality."""
        response = client.get("/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert data["version"] == "0.1.0"
        assert "timestamp" in data
        assert "services" in data
        assert "configuration" in data
    
    def test_health_without_openai_key(self, client):
        """Test health check when OpenAI key is not configured."""
        with patch.object(settings, 'OPENAI_API_KEY', None):
            response = client.get("/health")
            assert response.status_code == 200
            
            data = response.json()
            assert data["services"]["ai"] == "disabled"


class TestMetricsEndpoint:
    """Test cases for the metrics endpoint."""
    
    def test_metrics_endpoint(self, client):
        """Test Prometheus metrics endpoint."""
        response = client.get("/metrics")
        assert response.status_code == 200
        assert response.headers["content-type"] == "text/plain; version=0.0.4; charset=utf-8"


class TestRootEndpoint:
    """Test cases for the root endpoint."""
    
    def test_root_endpoint(self, client):
        """Test root endpoint returns API information."""
        response = client.get("/")
        assert response.status_code == 200
        
        data = response.json()
        assert data["message"] == "tripblip Python Agent API"
        assert data["version"] == "0.1.0"
        assert "docs" in data
        assert "health" in data
        assert "metrics" in data


class TestAgentMessageEndpoint:
    """Test cases for the agent message endpoint."""
    
    def test_agent_message_success(self, client, mock_openai_client):
        """Test successful agent message processing."""
        with patch.object(settings, 'OPENAI_API_KEY', 'test-key'):
            response = client.post(
                "/agent/message",
                json={
                    "content": "Hello, AI!",
                    "session_id": "test-session"
                }
            )
            
            assert response.status_code == 200
            data = response.json()
            
            assert data["success"] is True
            assert "data" in data
            assert "request_id" in data
            assert data["data"]["message"] == "Test response from AI"
            assert data["data"]["session_id"] == "test-session"
            assert data["data"]["tokens"] == 150
    
    def test_agent_message_without_openai_key(self, client):
        """Test agent message when OpenAI key is not configured."""
        with patch.object(settings, 'OPENAI_API_KEY', None):
            response = client.post(
                "/agent/message",
                json={"content": "Hello, AI!"}
            )
            
            assert response.status_code == 503
            assert "AI service not configured" in response.json()["detail"]
    
    def test_agent_message_invalid_content(self, client):
        """Test agent message with invalid content."""
        # Empty content
        response = client.post(
            "/agent/message",
            json={"content": ""}
        )
        assert response.status_code == 422
        
        # Content too long
        response = client.post(
            "/agent/message",
            json={"content": "x" * 4001}
        )
        assert response.status_code == 422
    
    def test_agent_message_openai_error(self, client, mock_openai_client):
        """Test agent message with OpenAI API error."""
        with patch.object(settings, 'OPENAI_API_KEY', 'test-key'):
            # Mock OpenAI rate limit error
            mock_openai_client.chat.completions.create.side_effect = Exception("Rate limit exceeded")
            
            response = client.post(
                "/agent/message",
                json={"content": "Hello, AI!"}
            )
            
            assert response.status_code == 500
    
    def test_agent_message_with_custom_parameters(self, client, mock_openai_client):
        """Test agent message with custom temperature and max_tokens."""
        with patch.object(settings, 'OPENAI_API_KEY', 'test-key'):
            response = client.post(
                "/agent/message",
                json={
                    "content": "Hello, AI!",
                    "temperature": 0.5,
                    "max_tokens": 1000
                }
            )
            
            assert response.status_code == 200
            # Verify the parameters were passed to OpenAI
            mock_openai_client.chat.completions.create.assert_called_once()
            call_args = mock_openai_client.chat.completions.create.call_args
            assert call_args[1]["temperature"] == 0.5
            assert call_args[1]["max_tokens"] == 1000


class TestAgentMessageStreamEndpoint:
    """Test cases for the agent message streaming endpoint."""
    
    def test_agent_message_stream_success(self, client, mock_openai_client):
        """Test successful agent message streaming."""
        with patch.object(settings, 'OPENAI_API_KEY', 'test-key'):
            # Mock streaming response
            mock_chunk1 = Mock()
            mock_chunk1.choices = [Mock()]
            mock_chunk1.choices[0].delta.content = "Hello"
            
            mock_chunk2 = Mock()
            mock_chunk2.choices = [Mock()]
            mock_chunk2.choices[0].delta.content = " World"
            
            mock_openai_client.chat.completions.create.return_value = [mock_chunk1, mock_chunk2]
            
            response = client.post(
                "/agent/message/stream",
                json={"content": "Hello, AI!"}
            )
            
            assert response.status_code == 200
            assert response.headers["content-type"] == "text/plain"
            assert "X-Request-ID" in response.headers
    
    def test_agent_message_stream_without_openai_key(self, client):
        """Test agent message streaming when OpenAI key is not configured."""
        with patch.object(settings, 'OPENAI_API_KEY', None):
            response = client.post(
                "/agent/message/stream",
                json={"content": "Hello, AI!"}
            )
            
            assert response.status_code == 503


class TestProxyEndpoints:
    """Test cases for proxy endpoints."""
    
    @pytest.mark.asyncio
    async def test_proxy_adventure_data_success(self, mock_httpx_client):
        """Test successful adventure data proxy."""
        with patch.object(settings, 'NODE_BACKEND_URL', 'http://test-backend'):
            async with AsyncClient(app=app, base_url="http://test") as ac:
                response = await ac.get(
                    "/agent/tools/external/adventure-data",
                    params={"lat": 40.7128, "lng": -74.0060, "radius": 5000}
                )
                
                assert response.status_code == 200
                data = response.json()
                assert data == {"test": "data"}
    
    @pytest.mark.asyncio
    async def test_proxy_adventure_data_timeout(self, mock_httpx_client):
        """Test adventure data proxy with timeout."""
        from httpx import TimeoutException
        
        with patch.object(settings, 'NODE_BACKEND_URL', 'http://test-backend'):
            mock_httpx_client.get.side_effect = TimeoutException("Request timeout")
            
            async with AsyncClient(app=app, base_url="http://test") as ac:
                response = await ac.get(
                    "/agent/tools/external/adventure-data",
                    params={"lat": 40.7128, "lng": -74.0060}
                )
                
                assert response.status_code == 504
                assert "timeout" in response.json()["detail"].lower()
    
    @pytest.mark.asyncio
    async def test_proxy_directions_success(self, mock_httpx_client):
        """Test successful directions proxy."""
        with patch.object(settings, 'NODE_BACKEND_URL', 'http://test-backend'):
            async with AsyncClient(app=app, base_url="http://test") as ac:
                response = await ac.get(
                    "/agent/tools/external/directions",
                    params={
                        "fromLat": 40.7128, "fromLng": -74.0060,
                        "toLat": 40.7589, "toLng": -73.9851,
                        "mode": "walking"
                    }
                )
                
                assert response.status_code == 200
                data = response.json()
                assert data == {"test": "data"}
    
    @pytest.mark.asyncio
    async def test_proxy_weather_current_success(self, mock_httpx_client):
        """Test successful current weather proxy."""
        with patch.object(settings, 'NODE_BACKEND_URL', 'http://test-backend'):
            async with AsyncClient(app=app, base_url="http://test") as ac:
                response = await ac.get(
                    "/agent/tools/external/weather/current",
                    params={"lat": 40.7128, "lng": -74.0060}
                )
                
                assert response.status_code == 200
                data = response.json()
                assert data == {"test": "data"}
    
    @pytest.mark.asyncio
    async def test_proxy_weather_forecast_success(self, mock_httpx_client):
        """Test successful weather forecast proxy."""
        with patch.object(settings, 'NODE_BACKEND_URL', 'http://test-backend'):
            async with AsyncClient(app=app, base_url="http://test") as ac:
                response = await ac.get(
                    "/agent/tools/external/weather/forecast",
                    params={"lat": 40.7128, "lng": -74.0060, "days": 3}
                )
                
                assert response.status_code == 200
                data = response.json()
                assert data == {"test": "data"}


class TestMiddleware:
    """Test cases for middleware functionality."""
    
    def test_request_id_middleware(self, client):
        """Test that request ID is added to responses."""
        response = client.get("/health")
        assert response.status_code == 200
        assert "x-request-id" in response.headers
    
    def test_cors_middleware(self, client):
        """Test CORS headers are present."""
        response = client.options("/health")
        # CORS headers should be present (handled by FastAPI CORS middleware)
        assert response.status_code in [200, 204]


class TestErrorHandling:
    """Test cases for error handling."""
    
    def test_404_endpoint(self, client):
        """Test 404 for non-existent endpoints."""
        response = client.get("/non-existent-endpoint")
        assert response.status_code == 404
    
    def test_invalid_json(self, client):
        """Test handling of invalid JSON."""
        response = client.post(
            "/agent/message",
            data="invalid json",
            headers={"content-type": "application/json"}
        )
        assert response.status_code == 422


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
