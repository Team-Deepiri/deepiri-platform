"""
Pytest Configuration for AI Tests
"""
import pytest
import asyncio
import os
from pathlib import Path

@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(autouse=True)
def setup_test_env(monkeypatch):
    """Setup test environment variables."""
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("NODE_ENV", "test")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")

@pytest.fixture
def test_data_dir(tmp_path):
    """Create temporary test data directory."""
    data_dir = tmp_path / "test_data"
    data_dir.mkdir()
    return data_dir

@pytest.fixture
def mock_openai_response(monkeypatch):
    """Mock OpenAI API response."""
    class MockResponse:
        def __init__(self):
            self.choices = [type('obj', (object,), {
                'message': type('obj', (object,), {
                    'content': '{"type": "code", "complexity": "medium", "estimated_duration": 30}'
                })()
            })()]
            self.model = "gpt-4"
            self.usage = type('obj', (object,), {'total_tokens': 100})()
    
    def mock_create(*args, **kwargs):
        return MockResponse()
    
    monkeypatch.setattr("openai.OpenAI.chat.completions.create", mock_create)

