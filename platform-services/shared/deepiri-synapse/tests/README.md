# Running Tests

## Quick Start

### Option 1: Install Dependencies (Recommended)

```bash
# Install test dependencies
pip install -r ../requirements.txt
pip install pytest pytest-asyncio

# Run tests
pytest tests/
```

### Option 2: Run with Mocks (No Dependencies)

The `conftest.py` file mocks missing dependencies, but you may still need to install some packages.

```bash
# Minimum required
pip install pytest pytest-asyncio

# Run tests
pytest tests/
```

## Test Files

- `test_schema_registry.py` - Schema Registry tests
- `test_validation_middleware.py` - Validation Middleware tests  
- `test_dead_letter_queue.py` - Dead Letter Queue tests
- `test_event_models.py` - Event model tests (requires deepiri-modelkit)

## Running Specific Tests

```bash
# Run all tests
pytest tests/

# Run specific test file
pytest tests/test_schema_registry.py

# Run specific test
pytest tests/test_schema_registry.py::test_register_schema_success

# Run with verbose output
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html
```

## Troubleshooting

### ModuleNotFoundError: No module named 'redis'

**Solution**: Install dependencies:
```bash
pip install redis pydantic
```

Or install all requirements:
```bash
pip install -r ../requirements.txt
```

### ModuleNotFoundError: No module named 'app'

**Solution**: Ensure you're running from the synapse directory:
```bash
cd platform-services/shared/deepiri-synapse
pytest tests/
```

### Import errors with deepiri_modelkit

The `test_event_models.py` file requires `deepiri-modelkit`. You can:
1. Skip it: `pytest tests/ -k "not test_event_models"`
2. Install modelkit if available
3. The validators handle missing modelkit gracefully

## Dependencies

### Required for Tests
- `pytest` - Test framework
- `pytest-asyncio` - Async test support

### Required for App (install for full functionality)
- `redis` - Redis client
- `pydantic` - Data validation
- `fastapi` - Web framework
- `uvicorn` - ASGI server

See `../requirements.txt` for full list.

---

## Docker Testing (Legacy)

### Build the image (from repository root)

```bash
docker build -f platform-services/shared/deepiri-synapse/Dockerfile -t deepiri-platform-services:dev .
```

### Run the single test file (one-liner)

```bash
docker run --rm -v "$PWD":/workspace -w /workspace \
  -e PYTHONPATH=./platform-services/shared/deepiri-synapse/app/deepiri-modelkit:./platform-services/shared:./ \
  deepiri-platform-services:dev bash -lc "python platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```

If the image does not include dev/test packages, install them first inside the container:

```bash
docker run --rm -v "$PWD":/workspace -w /workspace \
  -e PYTHONPATH=./platform-services/shared/deepiri-synapse/app/deepiri-modelkit:./platform-services/shared:./ \
  deepiri-platform-services:dev bash -lc "pip install -r requirements.txt && python platform-services/shared/deepiri-synapse/tests/test_event_models.py"
```
