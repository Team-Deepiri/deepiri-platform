# Database Transaction Management and Rollback Handling
## A Step-by-Step Guide for Beginners

This guide will walk you through implementing database transaction management and rollback handling in your application. We'll start with simple concepts and gradually build up to advanced patterns.

---

## Table of Contents

1. [Understanding the Problem](#understanding-the-problem)
2. [What Are Database Transactions?](#what-are-database-transactions)
3. [Why Do We Need Transactions?](#why-do-we-need-transactions)
4. [Step 1: Basic Transaction Concepts](#step-1-basic-transaction-concepts)
5. [Step 2: Simple Transaction Implementation](#step-2-simple-transaction-implementation)
6. [Step 3: Error Handling and Rollback](#step-3-error-handling-and-rollback)
7. [Step 4: Context Managers for Clean Code](#step-4-context-managers-for-clean-code)
8. [Step 5: Nested Transactions and Savepoints](#step-5-nested-transactions-and-savepoints)
9. [Step 6: Transaction Decorators and Helpers](#step-6-transaction-decorators-and-helpers)
10. [Step 7: Advanced Patterns](#step-7-advanced-patterns)
11. [Step 8: Testing Transactions](#step-8-testing-transactions)
12. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)

---

## Understanding the Problem

### The Scenario

Imagine you're building a feature where a user creates an account. This involves:
1. Inserting a record into the `users` table
2. Creating a default profile in the `profiles` table
3. Setting up initial preferences in the `user_preferences` table

What happens if step 2 succeeds but step 3 fails? You'd end up with:
- A user record (step 1 completed)
- A profile record (step 2 completed)
- No preferences (step 3 failed)

This leaves your database in an inconsistent state. The user exists but is missing critical data.

### The Solution

Database transactions solve this by grouping multiple operations into a single atomic unit. Either all operations succeed, or none of them do. If any step fails, everything is rolled back to the state before the transaction started.

---

## What Are Database Transactions?

A transaction is a sequence of database operations that are treated as a single unit of work. Transactions follow the ACID properties:

- **Atomicity**: All operations succeed or all fail
- **Consistency**: Database remains in a valid state
- **Isolation**: Concurrent transactions don't interfere with each other
- **Durability**: Committed changes are permanent

Think of it like a bank transfer: you can't have money leave one account without arriving in another. Both operations must succeed together or fail together.

---

## Why Do We Need Transactions?

### Without Transactions

```python
# BAD: No transaction management
async def create_user_account(user_data):
    # Step 1: Create user
    await postgres.execute(
        "INSERT INTO users (email, password) VALUES ($1, $2)",
        user_data['email'], user_data['password']
    )
    
    # Step 2: Create profile
    await postgres.execute(
        "INSERT INTO profiles (user_id, name) VALUES ($1, $2)",
        user_id, user_data['name']
    )
    
    # Step 3: Create preferences
    await postgres.execute(
        "INSERT INTO user_preferences (user_id, theme) VALUES ($1, $2)",
        user_id, 'default'
    )
```

**Problem**: If step 3 fails, steps 1 and 2 have already been committed. Your database is now inconsistent.

### With Transactions

```python
# GOOD: With transaction management
async def create_user_account(user_data):
    async with postgres.transaction() as tx:
        # Step 1: Create user
        await postgres.execute(...)
        
        # Step 2: Create profile
        await postgres.execute(...)
        
        # Step 3: Create preferences
        await postgres.execute(...)
        
        # If we reach here, all operations succeeded
        # Transaction automatically commits
```

**Solution**: If any step fails, the entire transaction rolls back. No partial data is saved.

---

## Step 1: Basic Transaction Concepts

### Understanding Transaction Lifecycle

Every transaction follows this lifecycle:

1. **BEGIN**: Start the transaction
2. **EXECUTE**: Perform database operations
3. **COMMIT**: Save all changes (if successful)
4. **ROLLBACK**: Undo all changes (if any operation fails)

### Manual Transaction Control

The most basic way to use transactions is manual control:

```python
# Manual transaction control
async def basic_transaction_example():
    postgres = await get_postgres_manager()
    
    # Start transaction
    async with postgres.acquire() as conn:
        # Begin transaction
        await conn.execute("BEGIN")
        
        try:
            # Perform operations
            await conn.execute("INSERT INTO users ...")
            await conn.execute("INSERT INTO profiles ...")
            
            # Commit if successful
            await conn.execute("COMMIT")
        except Exception as e:
            # Rollback on error
            await conn.execute("ROLLBACK")
            raise
```

**Key Points**:
- You must explicitly BEGIN, COMMIT, or ROLLBACK
- Errors must be caught to trigger rollback
- Connection must be held for the entire transaction

---

## Step 2: Simple Transaction Implementation

### Using asyncpg Transaction Context Manager

asyncpg provides a cleaner way to handle transactions:

```python
# Using asyncpg's transaction context manager
async def simple_transaction_example():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        async with conn.transaction():
            # All operations here are in a transaction
            await conn.execute("INSERT INTO users ...")
            await conn.execute("INSERT INTO profiles ...")
            # Transaction commits automatically when exiting the context
            # If an exception occurs, it rolls back automatically
```

**Advantages**:
- Automatic commit on success
- Automatic rollback on exception
- Cleaner code structure

### Adding to PostgreSQLManager

To make transactions easier to use, add a transaction method to your PostgreSQLManager:

```python
# In PostgreSQLManager class
@asynccontextmanager
async def transaction(self):
    """Create a transaction context manager"""
    async with self.acquire() as conn:
        async with conn.transaction():
            yield conn
```

**Usage**:
```python
async def create_user_account(user_data):
    postgres = await get_postgres_manager()
    
    async with postgres.transaction() as conn:
        # All operations use the same connection
        await conn.execute("INSERT INTO users ...")
        await conn.execute("INSERT INTO profiles ...")
```

---

## Step 3: Error Handling and Rollback

### Understanding Rollback Scenarios

Transactions should rollback when:
1. An exception is raised during execution
2. A constraint violation occurs (e.g., duplicate key)
3. A business logic validation fails
4. A timeout occurs

### Basic Error Handling

```python
async def transaction_with_error_handling():
    postgres = await get_postgres_manager()
    
    try:
        async with postgres.transaction() as conn:
            # Operation 1
            await conn.execute("INSERT INTO users ...")
            
            # Operation 2 - might fail
            await conn.execute("INSERT INTO profiles ...")
            
            # Operation 3
            await conn.execute("INSERT INTO preferences ...")
            
    except asyncpg.UniqueViolationError:
        # Handle duplicate key error
        logger.error("User already exists")
        raise
    except asyncpg.ForeignKeyViolationError:
        # Handle foreign key constraint error
        logger.error("Invalid reference")
        raise
    except Exception as e:
        # Handle any other error
        logger.error(f"Transaction failed: {e}")
        raise
```

### Custom Rollback Logic

Sometimes you need custom rollback logic:

```python
async def transaction_with_custom_rollback():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        tx = conn.transaction()
        await tx.start()
        
        try:
            # Perform operations
            await conn.execute("INSERT INTO users ...")
            
            # Business logic check
            result = await conn.fetchval("SELECT COUNT(*) FROM users WHERE ...")
            if result > 100:
                # Manually rollback for business reasons
                await tx.rollback()
                raise ValueError("Too many users")
            
            await conn.execute("INSERT INTO profiles ...")
            await tx.commit()
            
        except Exception as e:
            await tx.rollback()
            raise
```

---

## Step 4: Context Managers for Clean Code

### Creating a Reusable Transaction Manager

To make transactions even easier, create a reusable transaction manager:

```python
from contextlib import asynccontextmanager
from typing import AsyncGenerator

class TransactionManager:
    """Manages database transactions with automatic rollback"""
    
    def __init__(self, postgres_manager):
        self.postgres = postgres_manager
        self._connection = None
        self._transaction = None
    
    @asynccontextmanager
    async def begin(self) -> AsyncGenerator:
        """Begin a new transaction"""
        async with self.postgres.acquire() as conn:
            async with conn.transaction():
                self._connection = conn
                yield conn
                self._connection = None
    
    async def execute(self, query: str, *args):
        """Execute a query within the transaction"""
        if not self._connection:
            raise RuntimeError("Transaction not started")
        return await self._connection.execute(query, *args)
    
    async def fetch(self, query: str, *args):
        """Fetch rows within the transaction"""
        if not self._connection:
            raise RuntimeError("Transaction not started")
        return await self._connection.fetch(query, *args)
```

### Using the Transaction Manager

```python
async def create_user_with_manager(user_data):
    postgres = await get_postgres_manager()
    tx_manager = TransactionManager(postgres)
    
    async with tx_manager.begin() as conn:
        # All operations are automatically in a transaction
        user_id = await tx_manager.execute(
            "INSERT INTO users ... RETURNING id"
        )
        await tx_manager.execute(
            "INSERT INTO profiles (user_id, ...) VALUES ($1, ...)",
            user_id
        )
```

---

## Step 5: Nested Transactions and Savepoints

### Understanding Savepoints

Sometimes you need nested transactions. PostgreSQL supports this with savepoints:

```python
async def nested_transaction_example():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        async with conn.transaction():
            # Outer transaction
            await conn.execute("INSERT INTO users ...")
            
            # Create a savepoint (nested transaction)
            async with conn.transaction():
                # Inner transaction
                try:
                    await conn.execute("INSERT INTO profiles ...")
                    # If this fails, only rollback to savepoint
                except Exception:
                    # Rollback only affects the inner transaction
                    # Outer transaction continues
                    pass
            
            # Outer transaction continues
            await conn.execute("INSERT INTO preferences ...")
```

### Savepoint Helper Method

Add a savepoint method to your transaction manager:

```python
@asynccontextmanager
async def savepoint(self, name: str):
    """Create a savepoint for nested transactions"""
    if not self._connection:
        raise RuntimeError("No active transaction")
    
    await self._connection.execute(f"SAVEPOINT {name}")
    try:
        yield self._connection
        await self._connection.execute(f"RELEASE SAVEPOINT {name}")
    except Exception:
        await self._connection.execute(f"ROLLBACK TO SAVEPOINT {name}")
        raise
```

### Use Case: Partial Rollback

```python
async def complex_operation_with_savepoints():
    postgres = await get_postgres_manager()
    
    async with postgres.transaction() as conn:
        # Main operation
        await conn.execute("INSERT INTO users ...")
        
        # Try to create profile, but don't fail entire transaction if it fails
        async with conn.transaction():  # Creates savepoint
            try:
                await conn.execute("INSERT INTO profiles ...")
            except Exception:
                # Only rollback the profile insert
                # User insert remains committed
                logger.warning("Profile creation failed, continuing...")
        
        # This still executes even if profile creation failed
        await conn.execute("INSERT INTO preferences ...")
```

---

## Step 6: Transaction Decorators and Helpers

### Creating a Transaction Decorator

Decorators can automatically wrap functions in transactions:

```python
from functools import wraps
from typing import Callable, Any

def with_transaction(func: Callable) -> Callable:
    """Decorator to automatically wrap function in a transaction"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        postgres = await get_postgres_manager()
        async with postgres.transaction() as conn:
            # Pass connection as keyword argument
            return await func(*args, **kwargs, db_conn=conn)
    return wrapper

# Usage
@with_transaction
async def create_user_account(user_data, db_conn=None):
    await db_conn.execute("INSERT INTO users ...")
    await db_conn.execute("INSERT INTO profiles ...")
```

### Transaction Helper Function

For more flexibility, use a helper function:

```python
async def run_in_transaction(callback: Callable):
    """Run a callback function within a transaction"""
    postgres = await get_postgres_manager()
    
    async with postgres.transaction() as conn:
        return await callback(conn)

# Usage
async def create_user_account(user_data):
    async def do_create(conn):
        await conn.execute("INSERT INTO users ...")
        await conn.execute("INSERT INTO profiles ...")
        return user_id
    
    return await run_in_transaction(do_create)
```

### Retry Logic with Transactions

Add retry logic for transient failures:

```python
async def transaction_with_retry(
    callback: Callable,
    max_retries: int = 3,
    retry_delay: float = 1.0
):
    """Run transaction with automatic retry on transient errors"""
    postgres = await get_postgres_manager()
    
    for attempt in range(max_retries):
        try:
            async with postgres.transaction() as conn:
                return await callback(conn)
        except asyncpg.PostgresConnectionError as e:
            if attempt < max_retries - 1:
                logger.warning(f"Retry {attempt + 1}/{max_retries}: {e}")
                await asyncio.sleep(retry_delay * (2 ** attempt))
                continue
            raise
        except Exception:
            # Don't retry on non-transient errors
            raise
```

---

## Step 7: Advanced Patterns

### Distributed Transactions (Multiple Databases)

When working with multiple databases, you need two-phase commit:

```python
async def distributed_transaction():
    postgres = await get_postgres_manager()
    mongo = get_mongo_client()
    
    # Start PostgreSQL transaction
    async with postgres.transaction() as pg_conn:
        # Start MongoDB session (transaction)
        async with await mongo.start_session() as mongo_session:
            async with mongo_session.start_transaction():
                try:
                    # PostgreSQL operation
                    await pg_conn.execute("INSERT INTO users ...")
                    
                    # MongoDB operation
                    await mongo.users.insert_one(
                        {"user_id": user_id},
                        session=mongo_session
                    )
                    
                    # Both commit if successful
                    # Both rollback if any fails
                except Exception:
                    # Both transactions rollback
                    raise
```

### Transaction Isolation Levels

PostgreSQL supports different isolation levels:

```python
async def transaction_with_isolation_level():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        # Set isolation level
        await conn.execute("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        
        async with conn.transaction():
            # Operations with serializable isolation
            await conn.execute("INSERT INTO users ...")
```

**Isolation Levels**:
- `READ UNCOMMITTED`: Can read uncommitted data (not recommended)
- `READ COMMITTED`: Default, can only read committed data
- `REPEATABLE READ`: Consistent reads within transaction
- `SERIALIZABLE`: Highest isolation, prevents all anomalies

### Long-Running Transactions

For long-running operations, use savepoints to checkpoint progress:

```python
async def long_running_transaction():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        async with conn.transaction():
            # Process items in batches
            items = await conn.fetch("SELECT * FROM items WHERE processed = false")
            
            for i, item in enumerate(items):
                # Create savepoint for each item
                async with conn.transaction():
                    try:
                        await process_item(conn, item)
                        # Commit this item's changes
                    except Exception as e:
                        # Rollback only this item
                        logger.error(f"Failed to process item {item.id}: {e}")
                        continue
```

### Transaction Timeouts

Set timeouts to prevent transactions from running too long:

```python
async def transaction_with_timeout():
    postgres = await get_postgres_manager()
    
    async with postgres.acquire() as conn:
        # Set statement timeout
        await conn.execute("SET LOCAL statement_timeout = '30s'")
        
        async with conn.transaction():
            # Transaction will abort if it takes longer than 30 seconds
            await conn.execute("INSERT INTO users ...")
```

---

## Step 8: Testing Transactions

### Testing Transaction Rollback

Test that transactions properly rollback on errors:

```python
async def test_transaction_rollback():
    postgres = await get_postgres_manager()
    
    # Count initial records
    initial_count = await postgres.fetchval("SELECT COUNT(*) FROM users")
    
    try:
        async with postgres.transaction() as conn:
            await conn.execute("INSERT INTO users ...")
            await conn.execute("INSERT INTO users ...")
            # Force an error
            raise ValueError("Test error")
    except ValueError:
        pass
    
    # Verify rollback occurred
    final_count = await postgres.fetchval("SELECT COUNT(*) FROM users")
    assert initial_count == final_count, "Transaction did not rollback"
```

### Testing Nested Transactions

Test savepoint behavior:

```python
async def test_nested_transaction():
    postgres = await get_postgres_manager()
    
    async with postgres.transaction() as conn:
        # Outer transaction
        await conn.execute("INSERT INTO users ...")
        
        # Inner transaction that fails
        try:
            async with conn.transaction():
                await conn.execute("INSERT INTO profiles ...")
                raise ValueError("Inner transaction fails")
        except ValueError:
            pass
        
        # Verify outer transaction continues
        count = await conn.fetchval("SELECT COUNT(*) FROM users")
        assert count > 0, "Outer transaction should continue"
```

### Mocking Transactions in Tests

For unit tests, mock the transaction behavior:

```python
from unittest.mock import AsyncMock, MagicMock

async def test_with_mocked_transaction():
    # Mock the transaction
    mock_conn = AsyncMock()
    mock_transaction = MagicMock()
    mock_conn.transaction.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
    mock_conn.transaction.return_value.__aexit__ = AsyncMock(return_value=None)
    
    # Use mocked connection
    async with mock_conn.transaction():
        await mock_conn.execute("INSERT INTO users ...")
    
    # Verify transaction was used
    mock_conn.transaction.assert_called_once()
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Forgetting to Use Transactions

**Problem**: Multiple operations without transaction wrapper

```python
# BAD
await postgres.execute("INSERT INTO users ...")
await postgres.execute("INSERT INTO profiles ...")
```

**Solution**: Always wrap related operations in a transaction

```python
# GOOD
async with postgres.transaction() as conn:
    await conn.execute("INSERT INTO users ...")
    await conn.execute("INSERT INTO profiles ...")
```

### Pitfall 2: Using Different Connections

**Problem**: Each operation uses a different connection from the pool

```python
# BAD
async with postgres.acquire() as conn1:
    await conn1.execute("INSERT INTO users ...")
async with postgres.acquire() as conn2:
    await conn2.execute("INSERT INTO profiles ...")
```

**Solution**: Use the same connection for all operations in a transaction

```python
# GOOD
async with postgres.transaction() as conn:
    await conn.execute("INSERT INTO users ...")
    await conn.execute("INSERT INTO profiles ...")
```

### Pitfall 3: Catching Exceptions Too Broadly

**Problem**: Catching all exceptions prevents rollback

```python
# BAD
async with postgres.transaction() as conn:
    try:
        await conn.execute("INSERT INTO users ...")
    except Exception:
        pass  # Transaction still commits!
```

**Solution**: Let exceptions propagate to trigger rollback, or explicitly rollback

```python
# GOOD
async with postgres.transaction() as conn:
    try:
        await conn.execute("INSERT INTO users ...")
    except Exception as e:
        # Log error but let it propagate to rollback
        logger.error(f"Error: {e}")
        raise
```

### Pitfall 4: Long-Running Transactions

**Problem**: Holding transactions open for too long blocks other operations

```python
# BAD
async with postgres.transaction() as conn:
    await conn.execute("INSERT INTO users ...")
    await slow_external_api_call()  # Blocks transaction!
    await conn.execute("INSERT INTO profiles ...")
```

**Solution**: Do external calls outside the transaction, or use savepoints

```python
# GOOD
async with postgres.transaction() as conn:
    await conn.execute("INSERT INTO users ...")
    
# External call outside transaction
result = await slow_external_api_call()

# Continue with new transaction if needed
async with postgres.transaction() as conn:
    await conn.execute("INSERT INTO profiles ...")
```

### Pitfall 5: Not Handling Deadlocks

**Problem**: Concurrent transactions can cause deadlocks

**Solution**: Implement retry logic for deadlock errors

```python
async def transaction_with_deadlock_retry():
    postgres = await get_postgres_manager()
    max_retries = 3
    
    for attempt in range(max_retries):
        try:
            async with postgres.transaction() as conn:
                await conn.execute("INSERT INTO users ...")
                return
        except asyncpg.PostgresError as e:
            if "deadlock" in str(e).lower() and attempt < max_retries - 1:
                await asyncio.sleep(0.1 * (2 ** attempt))
                continue
            raise
```

---

## Implementation Checklist

When implementing transaction management, follow this checklist:

### Phase 1: Basic Setup
- [ ] Add transaction method to PostgreSQLManager
- [ ] Test basic transaction commit
- [ ] Test basic transaction rollback
- [ ] Add error handling

### Phase 2: Advanced Features
- [ ] Implement savepoint support
- [ ] Add transaction decorators
- [ ] Create transaction helper functions
- [ ] Add retry logic for transient errors

### Phase 3: Production Readiness
- [ ] Add transaction timeouts
- [ ] Implement deadlock detection and retry
- [ ] Add transaction logging
- [ ] Create transaction monitoring/metrics

### Phase 4: Testing
- [ ] Write unit tests for transactions
- [ ] Test rollback scenarios
- [ ] Test nested transactions
- [ ] Test concurrent transactions

---

## TypeScript/Prisma Implementation

For TypeScript services using Prisma, transactions work similarly:

### Basic Prisma Transaction

```typescript
// Basic transaction
async function createUserAccount(userData: UserData) {
  return await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: { email: userData.email }
    });
    
    await tx.profile.create({
      data: { userId: user.id, name: userData.name }
    });
    
    return user;
  });
}
```

### Prisma Transaction with Error Handling

```typescript
async function createUserWithErrorHandling(userData: UserData) {
  try {
    return await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({ data: userData });
      await tx.profile.create({ data: { userId: user.id } });
      return user;
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      throw new Error('User already exists');
    }
    throw error;
  }
}
```

### Prisma Transaction Options

```typescript
await prisma.$transaction(
  async (tx) => {
    // Operations
  },
  {
    maxWait: 5000,    // Max time to wait for transaction
    timeout: 10000,   // Max time transaction can run
    isolationLevel: Prisma.TransactionIsolationLevel.Serializable
  }
);
```

---

## Best Practices Summary

1. **Always use transactions for multi-step operations**
   - Any operation that modifies multiple tables
   - Any operation that must be atomic

2. **Keep transactions short**
   - Don't do external API calls inside transactions
   - Don't do heavy computation inside transactions

3. **Handle errors properly**
   - Let exceptions propagate to trigger rollback
   - Log errors before re-raising
   - Use specific exception types when possible

4. **Use appropriate isolation levels**
   - Default (READ COMMITTED) is usually sufficient
   - Use SERIALIZABLE only when necessary

5. **Monitor transaction performance**
   - Log long-running transactions
   - Set timeouts to prevent blocking
   - Track deadlock occurrences

6. **Test transaction behavior**
   - Test rollback scenarios
   - Test concurrent transactions
   - Test error handling

---

## Next Steps

After implementing basic transaction management:

1. **Add transaction monitoring**: Track transaction duration, success rates, and rollback frequency
2. **Implement distributed transactions**: If using multiple databases
3. **Add transaction pooling**: Optimize connection usage
4. **Create transaction utilities**: Build reusable helpers for common patterns
5. **Document transaction boundaries**: Clearly mark which operations require transactions

---

## Resources

- PostgreSQL Transaction Documentation: https://www.postgresql.org/docs/current/tutorial-transactions.html
- asyncpg Documentation: https://magicstack.github.io/asyncpg/current/
- Prisma Transactions: https://www.prisma.io/docs/concepts/components/prisma-client/transactions
- ACID Properties: https://en.wikipedia.org/wiki/ACID

---

## Conclusion

Transaction management is crucial for maintaining data consistency in your application. Start with simple transactions and gradually add more advanced features as needed. Remember:

- Transactions ensure atomicity: all or nothing
- Always wrap related operations in transactions
- Handle errors properly to trigger rollbacks
- Keep transactions short and focused
- Test your transaction logic thoroughly

By following this guide step by step, you'll build a robust transaction management system that ensures your database remains consistent even when errors occur.

