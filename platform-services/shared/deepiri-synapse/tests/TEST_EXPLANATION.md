# Test Suite Explanation

## Overview

This document explains the comprehensive test suite for the Schema Registry, Validation Middleware, and Dead Letter Queue components.

---

## Test Structure

### Test Files

1. **`test_schema_registry.py`** - Tests for Schema Registry component
2. **`test_validation_middleware.py`** - Tests for Validation Middleware component
3. **`test_dead_letter_queue.py`** - Tests for Dead Letter Queue component

---

## Test Architecture

### Mocking Strategy

All tests use **mocks** instead of real Redis connections to:
- **Speed**: Tests run faster without Redis dependency
- **Isolation**: Tests don't affect each other
- **Reliability**: Tests don't depend on external services
- **Control**: We can simulate various scenarios (success, failure, edge cases)

### Fixtures

Each test file uses pytest fixtures to:
- Create mock Redis clients
- Initialize component instances
- Set up test data
- Clean up after tests

---

## Schema Registry Tests (`test_schema_registry.py`)

### Test Coverage

#### 1. **Schema Registration**
- ✅ `test_register_schema_success` - Successful schema registration
- ✅ `test_register_schema_duplicate_version` - Preventing duplicate versions

**What it tests:**
- Schema registration workflow
- Redis storage operations
- Duplicate version detection

**Key Assertions:**
- Registration returns `True` on success
- Duplicate versions return `False`
- Redis operations are called correctly

#### 2. **Schema Retrieval**
- ✅ `test_get_schema_latest_version` - Get latest schema version
- ✅ `test_get_schema_specific_version` - Get specific version
- ✅ `test_get_schema_not_found` - Handle missing schemas

**What it tests:**
- Schema lookup functionality
- Version resolution (latest vs specific)
- Error handling for missing schemas

**Key Assertions:**
- Correct schema returned for version
- `None` returned for non-existent schemas
- Latest version resolution works

#### 3. **Version Management**
- ✅ `test_get_latest_version` - Get latest version number
- ✅ `test_list_versions` - List all versions
- ✅ `test_get_all_schemas` - Get all registered schemas

**What it tests:**
- Version tracking
- Schema enumeration
- Registry scanning

**Key Assertions:**
- Version lists are correct
- All schemas can be retrieved
- Version sorting works

#### 4. **Utility Functions**
- ✅ `test_version_to_score` - Version to numeric score conversion
- ✅ `test_schema_compatibility_enum` - Compatibility enum values

**What it tests:**
- Internal utility functions
- Enum definitions

**Key Assertions:**
- Version scoring for sorting
- Enum values are correct

---

## Validation Middleware Tests (`test_validation_middleware.py`)

### Test Coverage

#### 1. **Successful Validation**
- ✅ `test_validate_and_publish_success` - Valid event passes validation

**What it tests:**
- Event validation workflow
- Successful publishing
- Statistics tracking

**Key Assertions:**
- Validation succeeds
- Event published to Redis
- Stats incremented correctly

#### 2. **Validation Failures**
- ✅ `test_validate_and_publish_validation_failure` - Invalid event handling

**What it tests:**
- Validation error handling
- Dead letter queue integration
- Error propagation

**Key Assertions:**
- Invalid events rejected
- Events sent to DLQ
- Error messages captured

#### 3. **Schema Registry Integration**
- ✅ `test_validate_and_publish_with_schema_registry` - Schema version checking

**What it tests:**
- Schema registry integration
- Version metadata addition
- Compatibility checking

**Key Assertions:**
- Schema registry consulted
- Version metadata added to events

#### 4. **Configuration Options**
- ✅ `test_validate_and_publish_disabled_validation` - Disabled validation mode

**What it tests:**
- Feature toggles
- Bypass validation when disabled

**Key Assertions:**
- Validation can be disabled
- Events still published when disabled

#### 5. **Error Handling**
- ✅ `test_validate_and_publish_redis_error` - Redis connection errors

**What it tests:**
- Error recovery
- DLQ fallback on errors
- Exception handling

**Key Assertions:**
- Errors caught and handled
- Failed events go to DLQ
- Error messages preserved

#### 6. **Statistics and Monitoring**
- ✅ `test_get_stats` - Statistics retrieval
- ✅ `test_reset_stats` - Statistics reset

**What it tests:**
- Metrics tracking
- Statistics accuracy
- Reset functionality

**Key Assertions:**
- Stats calculated correctly
- Success rate computed
- Reset clears stats

#### 7. **Metadata Addition**
- ✅ `test_metadata_added_to_event` - Validation metadata in events

**What it tests:**
- Event enrichment
- Metadata tracking
- Timestamp addition

**Key Assertions:**
- Metadata added to events
- Validation timestamp present
- Validation flag set

---

## Dead Letter Queue Tests (`test_dead_letter_queue.py`)

### Test Coverage

#### 1. **Adding Failed Events**
- ✅ `test_add_failed_event` - Add event to DLQ
- ✅ `test_add_failed_event_max_retries` - Max retries handling

**What it tests:**
- DLQ storage
- Event metadata
- Retry tracking

**Key Assertions:**
- Events stored in DLQ
- Metadata preserved
- Retry flags set correctly

#### 2. **Retrieving Failed Events**
- ✅ `test_get_failed_events` - Get failed events
- ✅ `test_get_failed_events_filter_by_type` - Filter by failure type
- ✅ `test_get_failed_events_empty` - Empty DLQ handling

**What it tests:**
- Event retrieval
- Filtering capabilities
- Empty state handling

**Key Assertions:**
- Events retrieved correctly
- Filtering works
- Empty DLQ handled gracefully

#### 3. **Retry Mechanism**
- ✅ `test_retry_event_success` - Successful retry
- ✅ `test_retry_event_failure` - Failed retry increments count
- ✅ `test_retry_event_max_retries_exceeded` - Max retries handling

**What it tests:**
- Retry workflow
- Retry count tracking
- Max retries enforcement

**Key Assertions:**
- Successful retries remove from DLQ
- Failed retries increment count
- Max retries prevents further retries

#### 4. **Statistics**
- ✅ `test_get_dlq_stats_single_stream` - Single stream stats
- ✅ `test_get_dlq_stats_all_streams` - All streams stats
- ✅ `test_get_dlq_stats_stream_not_found` - Missing stream handling

**What it tests:**
- Statistics collection
- Multi-stream aggregation
- Error handling

**Key Assertions:**
- Stats calculated correctly
- Totals aggregated properly
- Missing streams handled

---

## Running the Tests

### Prerequisites

**IMPORTANT**: You must install dependencies before running tests!

```bash
# Install required dependencies
pip install -r ../requirements.txt

# Install test dependencies
pip install pytest pytest-asyncio
```

**Required packages:**
- `redis` - Redis client library
- `pydantic` - Data validation
- `pytest` - Test framework
- `pytest-asyncio` - Async test support

**Quick install:**
```bash
pip install redis pydantic pytest pytest-asyncio
```

### Run All Tests

```bash
# From the synapse directory
pytest tests/

# With verbose output
pytest tests/ -v

# With coverage
pytest tests/ --cov=app --cov-report=html
```

### Run Specific Test File

```bash
pytest tests/test_schema_registry.py
pytest tests/test_validation_middleware.py
pytest tests/test_dead_letter_queue.py
```

### Run Specific Test

```bash
pytest tests/test_schema_registry.py::test_register_schema_success
```

---

## Test Patterns Used

### 1. **Async Testing**
All tests use `@pytest.mark.asyncio` decorator because:
- Components use async/await
- Redis operations are async
- Real-world usage is async

### 2. **Mocking Redis**
```python
mock_redis = AsyncMock()
mock_redis.xadd = AsyncMock(return_value="123-0")
```

**Why:**
- No Redis dependency required
- Fast test execution
- Predictable behavior

### 3. **Patching External Dependencies**
```python
@patch('app.middleware.validation.validate_event')
async def test_validate_and_publish_success(mock_validate, ...):
```

**Why:**
- Isolate unit under test
- Control external behavior
- Test error scenarios

### 4. **Fixtures for Setup**
```python
@pytest.fixture
def validation_middleware(mock_redis, ...):
    return ValidationMiddleware(...)
```

**Why:**
- Reusable test setup
- Clean test code
- Consistent initialization

---

## Test Coverage Summary

### Schema Registry
- ✅ Registration (success, duplicates)
- ✅ Retrieval (latest, specific, not found)
- ✅ Version management (list, latest)
- ✅ Utility functions

### Validation Middleware
- ✅ Successful validation
- ✅ Validation failures
- ✅ Schema registry integration
- ✅ Configuration options
- ✅ Error handling
- ✅ Statistics
- ✅ Metadata addition

### Dead Letter Queue
- ✅ Adding failed events
- ✅ Retrieving failed events
- ✅ Retry mechanism
- ✅ Statistics

---

## Edge Cases Tested

1. **Empty States**
   - Empty DLQ
   - No registered schemas
   - No failed events

2. **Error Scenarios**
   - Redis connection errors
   - Validation failures
   - Max retries exceeded

3. **Boundary Conditions**
   - Duplicate versions
   - Missing schemas
   - Invalid event data

4. **Configuration Variations**
   - Validation enabled/disabled
   - Schema registry enabled/disabled
   - Different retry counts

---

## Integration Test Scenarios

While these are unit tests, they test integration points:

1. **Schema Registry → Validation Middleware**
   - Schema version lookup
   - Metadata addition

2. **Validation Middleware → Dead Letter Queue**
   - Failed event storage
   - Error message preservation

3. **Dead Letter Queue → Validation Middleware**
   - Retry mechanism
   - Event re-validation

---

## Best Practices Demonstrated

1. **Isolation**: Each test is independent
2. **Clarity**: Test names describe what they test
3. **Coverage**: All major paths tested
4. **Maintainability**: Uses fixtures and mocks
5. **Documentation**: Tests serve as examples

---

## Future Test Additions

Consider adding:

1. **Integration Tests**
   - Real Redis connection
   - End-to-end workflows
   - Performance tests

2. **Load Tests**
   - High-volume event processing
   - Concurrent operations
   - Stress testing

3. **Property-Based Tests**
   - Random valid/invalid events
   - Schema evolution scenarios
   - Fuzzing

---

## Troubleshooting Tests

### Common Issues

1. **`ModuleNotFoundError: No module named 'app'`**
   - **Solution**: The `conftest.py` file should handle this automatically
   - If still failing, ensure you're running pytest from the synapse directory:
     ```bash
     cd platform-services/shared/deepiri-synapse
     pytest tests/
     ```
   - Or set PYTHONPATH:
     ```bash
     PYTHONPATH=. pytest tests/
     ```

2. **`ModuleNotFoundError: No module named 'deepiri_modelkit'`**
   - **Solution**: This is expected if deepiri-modelkit is not installed
   - The validators handle this gracefully (MODELKIT_AVAILABLE flag)
   - Tests that require modelkit will be skipped or mocked
   - To install: `pip install -e ../deepiri-modelkit` (if available)

3. **`ModuleNotFoundError: No module named 'redis'`**
   - **Solution**: Install dependencies:
     ```bash
     pip install redis pydantic
     ```
   - Or install all requirements:
     ```bash
     pip install -r requirements.txt
     ```

4. **AsyncMock not working**
   - Ensure `pytest-asyncio` is installed: `pip install pytest-asyncio`
   - Check `@pytest.mark.asyncio` decorator is present

5. **Import errors**
   - Verify `conftest.py` exists in tests directory
   - Check that sys.path is set correctly
   - Try running: `python -m pytest tests/` instead of `pytest tests/`

6. **Mock not called**
   - Verify mock setup
   - Check call arguments
   - Use `mock_redis.xadd.assert_called()` to verify calls

### Debugging

```bash
# Run with print statements
pytest tests/ -s

# Run with pdb debugger
pytest tests/ --pdb

# Show test output
pytest tests/ -v -s
```

---

## Summary

This test suite provides:
- ✅ **Comprehensive coverage** of all components
- ✅ **Fast execution** using mocks
- ✅ **Clear examples** of component usage
- ✅ **Confidence** in component behavior
- ✅ **Documentation** through test code

The tests validate that:
1. Schema Registry manages versions correctly
2. Validation Middleware validates and routes events properly
3. Dead Letter Queue stores and retries failed events reliably

All components work together to provide a robust event validation and error handling system.

