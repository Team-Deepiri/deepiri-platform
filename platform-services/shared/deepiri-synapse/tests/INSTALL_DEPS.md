# Installing Dependencies for Tests

## Quick Fix

The tests require `redis` and `pydantic` to be installed. Install them:

```bash
pip install redis pydantic
```

Or install all requirements:

```bash
pip install -r ../requirements.txt
```

## Why This Is Needed

The app modules (`app/schemas/registry.py`, `app/middleware/validation.py`, etc.) import `redis` and `pydantic` at the module level. When pytest tries to import these modules to run tests, Python needs these packages to be installed.

## Alternative: Mocking (Advanced)

The `conftest.py` attempts to mock missing dependencies, but this doesn't work reliably because:
1. Modules import dependencies when they're loaded
2. By the time conftest.py runs, the imports may have already failed
3. Some modules need the actual classes (like `redis.asyncio.Redis`)

**Recommendation**: Just install the dependencies. They're lightweight and needed for the app to run anyway.

## Minimal Test Setup

```bash
# Install minimum required packages
pip install pytest pytest-asyncio redis pydantic

# Run tests
pytest tests/
```

## Full Setup

```bash
# Install all requirements
pip install -r ../requirements.txt
pip install pytest pytest-asyncio

# Run tests
pytest tests/ -v
```

