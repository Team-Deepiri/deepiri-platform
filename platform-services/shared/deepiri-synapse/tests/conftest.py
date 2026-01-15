"""
Pytest configuration and fixtures
Sets up Python path for imports and mocks missing dependencies
"""
import sys
from pathlib import Path
from unittest.mock import MagicMock

# Mock missing dependencies before importing app modules
# This allows tests to run without installing all dependencies
_mock_modules = {}

# Mock redis if not available (must be before any imports)
if 'redis' not in sys.modules:
    try:
        import redis
    except ImportError:
        redis_mock = MagicMock()
        redis_mock.asyncio = MagicMock()
        redis_mock.asyncio.Redis = MagicMock
        redis_mock.asyncio.ResponseError = type('ResponseError', (Exception,), {})
        sys.modules['redis'] = redis_mock
        sys.modules['redis.asyncio'] = redis_mock.asyncio

# Mock pydantic if not available (must be before any imports)
if 'pydantic' not in sys.modules:
    try:
        import pydantic
    except ImportError:
        pydantic_mock = MagicMock()
        pydantic_mock.BaseModel = MagicMock
        pydantic_mock.Field = MagicMock
        pydantic_mock.validator = MagicMock
        pydantic_mock.ValidationError = type('ValidationError', (Exception,), {})
        sys.modules['pydantic'] = pydantic_mock

# Add parent directory to Python path so we can import 'app'
synapse_dir = Path(__file__).parent.parent.resolve()
if str(synapse_dir) not in sys.path:
    sys.path.insert(0, str(synapse_dir))

# Also add the app directory
app_dir = synapse_dir / "app"
if str(app_dir) not in sys.path:
    sys.path.insert(0, str(app_dir))

# Try to add deepiri-modelkit if it exists locally
modelkit_dir = synapse_dir / "app" / "deepiri-modelkit"
if modelkit_dir.exists() and str(modelkit_dir) not in sys.path:
    sys.path.insert(0, str(modelkit_dir))

