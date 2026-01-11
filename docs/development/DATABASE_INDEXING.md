# Database Indexing Implementation Guide

## Overview

This guide will take you from understanding the basics of database indexing to implementing a comprehensive indexing strategy for the Deepiri platform. By the end, you'll have optimized all frequently queried columns across your PostgreSQL database.

## Table of Contents

1. [Bootcamp: Understanding Database Indexes](#bootcamp-understanding-database-indexes)
2. [Identifying Query Patterns](#identifying-query-patterns)
3. [Basic Index Implementation](#basic-index-implementation)
4. [Advanced Index Strategies](#advanced-index-strategies)
5. [Performance Monitoring](#performance-monitoring)
6. [Full Implementation Plan](#full-implementation-plan)
7. [Maintenance and Optimization](#maintenance-and-optimization)

---

## Bootcamp: Understanding Database Indexes

### What is a Database Index?

Think of a database index like the index in a book. Without an index, to find information about "authentication" you'd have to read every page. With an index, you can jump directly to the relevant pages.

In database terms:
- **Without an index**: PostgreSQL scans every row (full table scan) - slow for large tables
- **With an index**: PostgreSQL uses a data structure (usually B-tree) to quickly locate rows - fast even for millions of rows

### Why Indexes Matter

Consider this query on a users table with 1 million rows:

```sql
SELECT * FROM users WHERE email = 'user@example.com';
```

**Without index on email:**
- PostgreSQL scans all 1,000,000 rows
- Average time: 500-2000ms
- CPU usage: High

**With index on email:**
- PostgreSQL uses index to find exact row
- Average time: 1-5ms
- CPU usage: Minimal

### Types of Indexes in PostgreSQL

1. **B-tree Index** (default, most common)
   - Best for: Equality and range queries
   - Example: `WHERE status = 'active'`, `WHERE created_at > '2024-01-01'`

2. **Hash Index**
   - Best for: Simple equality checks only
   - Example: `WHERE id = 123`

3. **GIN Index** (Generalized Inverted Index)
   - Best for: Full-text search, arrays, JSONB
   - Example: `WHERE metadata @> '{"key": "value"}'`

4. **GiST Index** (Generalized Search Tree)
   - Best for: Geometric data, full-text search
   - Example: Geographic queries, complex data types

5. **BRIN Index** (Block Range Index)
   - Best for: Very large tables with sorted data
   - Example: Time-series data, log tables

### Index Trade-offs

**Benefits:**
- Faster SELECT queries
- Faster JOINs
- Faster WHERE clause filtering
- Faster ORDER BY operations

**Costs:**
- Slower INSERT/UPDATE/DELETE (indexes must be updated)
- Additional disk space (typically 10-20% of table size)
- Maintenance overhead

**Rule of thumb:** Index columns that are frequently queried but rarely updated.

---

## Identifying Query Patterns

### Step 1: Enable Query Logging

Before creating indexes, you need to understand what queries are actually running. Let's enable PostgreSQL's query logging.

**Task 1.1: Enable Slow Query Logging**

Connect to your PostgreSQL database:

```bash
docker exec -it deepiri-postgres psql -U deepiri -d deepiri
```

Or if using a local connection:

```bash
psql -U deepiri -d deepiri
```

Enable logging in PostgreSQL configuration. Check current settings:

```sql
SHOW log_min_duration_statement;
SHOW log_statement;
```

For development, enable logging of all queries taking longer than 100ms:

```sql
ALTER SYSTEM SET log_min_duration_statement = 100;
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

**Task 1.2: Analyze Application Code**

Search your codebase for database queries. Look for patterns like:

```bash
# Find all database queries in Python files
grep -r "SELECT\|WHERE\|JOIN" --include="*.py" deepiri-platform/

# Find all database queries in TypeScript files
grep -r "SELECT\|WHERE\|JOIN" --include="*.ts" deepiri-platform/
```

**Task 1.3: Identify Common Query Patterns**

Create a file `docs/indexing-query-analysis.md` and document:

1. Most frequent WHERE clauses
2. Most frequent JOIN conditions
3. Most frequent ORDER BY columns
4. Most frequent GROUP BY columns

Example analysis:

```
Frequent Queries Found:
- users.email (WHERE email = ?) - 500 queries/hour
- users.status (WHERE status = ?) - 300 queries/hour
- projects.owner_id (JOIN on owner_id) - 200 queries/hour
- projects.status (WHERE status = ?) - 150 queries/hour
- users.created_at (ORDER BY created_at DESC) - 100 queries/hour
```

### Step 2: Use EXPLAIN ANALYZE

For each identified query, use `EXPLAIN ANALYZE` to see the execution plan:

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'test@example.com';
```

Look for:
- **Seq Scan** (bad) - means no index is being used
- **Index Scan** (good) - means index is being used
- **Index Only Scan** (best) - means all data comes from index

**Task 2.1: Analyze Top 10 Queries**

Run EXPLAIN ANALYZE on your top 10 most frequent queries and document the results.

---

## Basic Index Implementation

### Step 3: Create Single-Column Indexes

Let's start with the simplest case: indexing a single column that's frequently queried.

**Task 3.1: Index the users.email Column**

The users table already has an index on email (we saw this in `postgres-init.sql`). But let's verify it exists and understand it:

```sql
-- Check existing indexes on users table
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'users';

-- Verify the index is being used
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'test@example.com';
```

If the index doesn't exist, create it:

```sql
CREATE INDEX idx_users_email ON users(email);
```

**Task 3.2: Create Missing Basic Indexes**

Based on the schema analysis, create indexes for other frequently queried columns:

```sql
-- Index for user status filtering
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- Index for project owner lookups
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON projects(owner_id);

-- Index for project status filtering
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);

-- Index for date range queries
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);
```

**Task 3.3: Test Index Performance**

Before and after creating indexes, test query performance:

```sql
-- Test query without index (if you drop it temporarily)
-- DROP INDEX idx_users_email;  -- Don't run this in production!
-- EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- Test query with index
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

Compare the execution times. You should see significant improvement.

### Step 4: Composite Indexes

When queries filter on multiple columns, a composite index can be more efficient than multiple single-column indexes.

**Task 4.1: Identify Multi-Column Query Patterns**

Look for queries like:

```sql
SELECT * FROM projects 
WHERE owner_id = '123' AND status = 'active'
ORDER BY created_at DESC;
```

This query benefits from a composite index.

**Task 4.2: Create Composite Indexes**

```sql
-- Composite index for owner + status queries
CREATE INDEX idx_projects_owner_status 
ON projects(owner_id, status);

-- Composite index for owner + status + date ordering
CREATE INDEX idx_projects_owner_status_created 
ON projects(owner_id, status, created_at DESC);
```

**Important:** Column order matters in composite indexes. Put the most selective column first (the one that filters out the most rows).

**Task 4.3: Understand Index Column Order**

Test different column orders:

```sql
-- If queries are: WHERE status = ? AND owner_id = ?
CREATE INDEX idx_projects_status_owner ON projects(status, owner_id);

-- If queries are: WHERE owner_id = ? AND status = ?
CREATE INDEX idx_projects_owner_status ON projects(owner_id, status);
```

The order should match your query patterns.

---

## Advanced Index Strategies

### Step 5: Partial Indexes

Partial indexes only index a subset of rows, making them smaller and faster.

**Use case:** Index only active users instead of all users.

**Task 5.1: Create Partial Indexes**

```sql
-- Index only active users (smaller, faster)
CREATE INDEX idx_users_active_email 
ON users(email) 
WHERE status = 'active';

-- Index only active projects
CREATE INDEX idx_projects_active_owner 
ON projects(owner_id, created_at DESC) 
WHERE status = 'active';
```

**Task 5.2: Verify Partial Index Usage**

```sql
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE email = 'test@example.com' AND status = 'active';
-- Should use idx_users_active_email

EXPLAIN ANALYZE
SELECT * FROM users 
WHERE email = 'test@example.com' AND status = 'inactive';
-- Won't use idx_users_active_email (different status)
```

### Step 6: Expression Indexes

Index the result of an expression, not just the column value.

**Use case:** Case-insensitive email searches, date truncation.

**Task 6.1: Create Expression Indexes**

```sql
-- Case-insensitive email index
CREATE INDEX idx_users_email_lower 
ON users(LOWER(email));

-- Index on truncated dates (for daily aggregations)
CREATE INDEX idx_users_created_date 
ON users(DATE_TRUNC('day', created_at));
```

**Task 6.2: Update Queries to Use Expression Indexes**

Your queries must match the expression:

```sql
-- This will use the index
SELECT * FROM users WHERE LOWER(email) = LOWER('Test@Example.com');

-- This won't use the index
SELECT * FROM users WHERE email = 'Test@Example.com';
```

### Step 7: JSONB Indexing

The Deepiri schema uses JSONB columns (metadata, theme, rewards). These need special indexing.

**Task 7.1: Create GIN Indexes for JSONB**

```sql
-- GIN index for JSONB containment queries
CREATE INDEX idx_users_metadata_gin 
ON users USING GIN (metadata);

-- GIN index for JSONB path queries
CREATE INDEX idx_projects_metadata_gin 
ON projects USING GIN (metadata);
```

**Task 7.2: Query JSONB Efficiently**

```sql
-- These queries will use the GIN index
SELECT * FROM users WHERE metadata @> '{"key": "value"}';
SELECT * FROM users WHERE metadata ? 'key';
SELECT * FROM users WHERE metadata->>'key' = 'value';
```

**Task 7.3: Create JSONB Path Indexes**

For specific JSONB paths that are frequently queried:

```sql
-- Index specific JSONB path
CREATE INDEX idx_users_metadata_preferences 
ON users((metadata->>'preferences'));
```

### Step 8: Full-Text Search Indexes

If you have text search requirements, use full-text search indexes.

**Task 8.1: Create Full-Text Search Indexes**

```sql
-- Add tsvector column for full-text search
ALTER TABLE users ADD COLUMN search_vector tsvector;

-- Create trigger to update search_vector
CREATE OR REPLACE FUNCTION users_search_vector_update() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.email, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.bio, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_search_vector_trigger 
BEFORE INSERT OR UPDATE ON users 
FOR EACH ROW EXECUTE FUNCTION users_search_vector_update();

-- Create GIN index on search_vector
CREATE INDEX idx_users_search_vector 
ON users USING GIN (search_vector);

-- Update existing rows
UPDATE users SET search_vector = 
    setweight(to_tsvector('english', COALESCE(name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(email, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(bio, '')), 'C');
```

**Task 8.2: Use Full-Text Search**

```sql
-- Full-text search query
SELECT * FROM users 
WHERE search_vector @@ to_tsquery('english', 'john & smith')
ORDER BY ts_rank(search_vector, to_tsquery('english', 'john & smith')) DESC;
```

---

## Performance Monitoring

### Step 9: Monitor Index Usage

You need to know which indexes are actually being used and which are just taking up space.

**Task 9.1: Check Index Usage Statistics**

```sql
-- View index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;  -- Indexes with 0 scans might be unused
```

**Task 9.2: Identify Unused Indexes**

Indexes that are never scanned are candidates for removal:

```sql
-- Find unused indexes (no scans in current session)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Task 9.3: Check Index Sizes**

Monitor how much space indexes are using:

```sql
-- Index sizes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Step 10: Query Performance Analysis

Regularly analyze slow queries to identify missing indexes.

**Task 10.1: Enable pg_stat_statements Extension**

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- View slowest queries
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

**Task 10.2: Analyze Query Plans**

For slow queries, get detailed execution plans:

```sql
-- Enable detailed query planning
SET enable_seqscan = off;  -- Temporarily to see if index would help
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT * FROM users WHERE email = 'test@example.com';
SET enable_seqscan = on;
```

---

## Full Implementation Plan

Now that you understand the concepts, let's implement a comprehensive indexing strategy for the Deepiri platform.

### Phase 1: Audit Current State

**Task 11.1: Document All Existing Indexes**

Create a script to export all current indexes:

```sql
-- Export all indexes to a file
\copy (
    SELECT 
        schemaname,
        tablename,
        indexname,
        indexdef
    FROM pg_indexes
    WHERE schemaname IN ('public', 'analytics', 'audit')
    ORDER BY schemaname, tablename, indexname
) TO '/tmp/current_indexes.csv' WITH CSV HEADER;
```

**Task 11.2: Identify Missing Indexes**

Based on your query analysis, create a list of missing indexes. Review the `postgres-init.sql` file and identify gaps.

### Phase 2: Implement Core Indexes

**Task 12.1: Create Index Migration Script**

Create a new file: `scripts/postgres-indexes.sql`

```sql
-- ===========================
-- DEEPIRI DATABASE INDEXES
-- Comprehensive Indexing Strategy
-- ===========================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- ===========================
-- USERS TABLE INDEXES
-- ===========================

-- Primary lookup indexes (already exist, but verify)
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at DESC);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_status_created 
ON public.users(status, created_at DESC);

-- Partial index for active users (most common query)
CREATE INDEX IF NOT EXISTS idx_users_active_email 
ON public.users(email) 
WHERE status = 'active';

-- Expression index for case-insensitive email
CREATE INDEX IF NOT EXISTS idx_users_email_lower 
ON public.users(LOWER(email));

-- JSONB index (already exists, verify)
CREATE INDEX IF NOT EXISTS idx_users_metadata_gin 
ON public.users USING GIN (metadata);

-- ===========================
-- PROJECTS TABLE INDEXES
-- ===========================

-- Foreign key indexes (already exist, verify)
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON public.projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON public.projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_priority ON public.projects(priority);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_projects_owner_status 
ON public.projects(owner_id, status);

CREATE INDEX IF NOT EXISTS idx_projects_owner_status_created 
ON public.projects(owner_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_projects_status_priority 
ON public.projects(status, priority, created_at DESC);

-- Partial index for active projects
CREATE INDEX IF NOT EXISTS idx_projects_active_owner 
ON public.projects(owner_id, created_at DESC) 
WHERE status = 'active';

-- Date range queries
CREATE INDEX IF NOT EXISTS idx_projects_dates 
ON public.projects(start_date, end_date) 
WHERE start_date IS NOT NULL;

-- JSONB index (already exists, verify)
CREATE INDEX IF NOT EXISTS idx_projects_metadata_gin 
ON public.projects USING GIN (metadata);

-- ===========================
-- ROLES TABLE INDEXES
-- ===========================

CREATE INDEX IF NOT EXISTS idx_roles_name ON public.roles(name);

-- ===========================
-- SEASONS TABLE INDEXES
-- ===========================

CREATE INDEX IF NOT EXISTS idx_seasons_is_active ON public.seasons(is_active);
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON public.seasons(start_date, end_date);

-- Partial index for active seasons
CREATE INDEX IF NOT EXISTS idx_seasons_active_dates 
ON public.seasons(start_date, end_date) 
WHERE is_active = true;

-- ===========================
-- AUDIT TABLE INDEXES
-- ===========================

-- If audit.activity_logs exists, index it
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity 
ON audit.activity_logs(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_activity_logs_action 
ON audit.activity_logs(action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user 
ON audit.activity_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_logs_created 
ON audit.activity_logs(created_at DESC);

-- ===========================
-- ANALYZE TABLES
-- ===========================

-- Update table statistics for query planner
ANALYZE public.users;
ANALYZE public.projects;
ANALYZE public.roles;
ANALYZE public.seasons;
```

**Task 12.2: Run the Index Migration**

```bash
# Connect to database and run migration
docker exec -i deepiri-postgres psql -U deepiri -d deepiri < scripts/postgres-indexes.sql
```

Or if using local PostgreSQL:

```bash
psql -U deepiri -d deepiri -f scripts/postgres-indexes.sql
```

**Task 12.3: Verify Index Creation**

```sql
-- Verify all indexes were created
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname IN ('public', 'analytics', 'audit')
ORDER BY schemaname, tablename, indexname;
```

### Phase 3: Application-Specific Indexes

**Task 13.1: Index Cyrex Tables**

If you have Cyrex-specific tables, add indexes:

```sql
-- Example: Cyrex vendor intelligence indexes
CREATE INDEX IF NOT EXISTS idx_cyrex_vendors_risk_score 
ON cyrex_vendors(current_risk_score DESC);

CREATE INDEX IF NOT EXISTS idx_cyrex_vendors_risk_level 
ON cyrex_vendors(risk_level);

CREATE INDEX IF NOT EXISTS idx_cyrex_invoices_vendor 
ON cyrex_invoices(vendor_id, analyzed_at DESC);

CREATE INDEX IF NOT EXISTS idx_cyrex_invoices_fraud 
ON cyrex_invoices(fraud_detected, analyzed_at DESC) 
WHERE fraud_detected = true;
```

**Task 13.2: Index Task Orchestrator Tables**

For task-related tables:

```sql
-- Example indexes for task tables
CREATE INDEX IF NOT EXISTS idx_tasks_user_status 
ON tasks(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
ON tasks(due_date) 
WHERE due_date IS NOT NULL;
```

### Phase 4: Advanced Optimizations

**Task 14.1: Create Covering Indexes**

Covering indexes include all columns needed for a query, allowing "index-only scans":

```sql
-- If you frequently query: SELECT id, email, status FROM users WHERE email = ?
-- Create covering index
CREATE INDEX idx_users_email_covering 
ON users(email) INCLUDE (id, status);
```

**Task 14.2: Optimize JOIN Queries**

For frequently joined tables, ensure foreign keys are indexed:

```sql
-- Verify foreign key indexes exist
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    CASE WHEN idx.indexname IS NOT NULL THEN 'Indexed' ELSE 'NOT INDEXED' END as index_status
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
LEFT JOIN pg_indexes idx 
  ON idx.tablename = tc.table_name 
  AND idx.indexdef LIKE '%' || kcu.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema = 'public';
```

**Task 14.3: Implement Index Maintenance Routine**

Create a maintenance script: `scripts/maintain-indexes.sql`

```sql
-- Rebuild indexes that are bloated
-- Run VACUUM ANALYZE regularly
VACUUM ANALYZE;

-- For heavily updated tables, consider REINDEX
-- REINDEX TABLE CONCURRENTLY users;
-- REINDEX TABLE CONCURRENTLY projects;
```

---

## Maintenance and Optimization

### Step 15: Regular Index Maintenance

**Task 15.1: Create Index Maintenance Script**

Create `scripts/index-maintenance.sh`:

```bash
#!/bin/bash
# Index Maintenance Script

DB_NAME="deepiri"
DB_USER="deepiri"

# Vacuum and analyze
psql -U $DB_USER -d $DB_NAME -c "VACUUM ANALYZE;"

# Check for unused indexes
psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
"

# Check index bloat
psql -U $DB_USER -d $DB_NAME -c "
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
"
```

**Task 15.2: Schedule Regular Maintenance**

Add to your cron or scheduled tasks:

```bash
# Run weekly index maintenance
0 2 * * 0 /path/to/scripts/index-maintenance.sh
```

### Step 16: Monitor and Adjust

**Task 16.1: Create Index Monitoring Dashboard Query**

```sql
-- Comprehensive index monitoring query
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as total_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        WHEN idx_scan < 1000 THEN 'MEDIUM USAGE'
        ELSE 'HIGH USAGE'
    END as usage_status
FROM pg_stat_user_indexes
WHERE schemaname IN ('public', 'analytics', 'audit')
ORDER BY 
    CASE 
        WHEN idx_scan = 0 THEN 0
        ELSE 1
    END,
    pg_relation_size(indexrelid) DESC;
```

**Task 16.2: Set Up Alerts**

Monitor for:
- Unused indexes taking significant space
- Missing indexes causing slow queries
- Index bloat (indexes growing too large)

### Step 17: Documentation

**Task 17.1: Document Index Strategy**

Update your documentation with:
- Why each index exists
- What queries it optimizes
- When it was added
- Performance impact

**Task 17.2: Create Index Decision Matrix**

Create a decision guide for future indexes:

```
Should I create an index?

1. Is the column used in WHERE clauses frequently? → YES: Create index
2. Is the column used in JOIN conditions? → YES: Create index
3. Is the column used in ORDER BY? → YES: Consider index
4. Is the table updated frequently? → MAYBE: Weigh insert/update cost
5. Is the column highly selective? → YES: Index will be effective
6. Is the column rarely NULL? → YES: Index is more useful
```

---

## Implementation Checklist

Use this checklist to ensure complete implementation:

### Phase 1: Preparation
- [ ] Enable query logging
- [ ] Analyze application code for query patterns
- [ ] Document frequent queries
- [ ] Run EXPLAIN ANALYZE on top queries
- [ ] Identify missing indexes

### Phase 2: Basic Indexes
- [ ] Create single-column indexes for WHERE clauses
- [ ] Create indexes for foreign keys
- [ ] Create indexes for ORDER BY columns
- [ ] Verify indexes are being used

### Phase 3: Advanced Indexes
- [ ] Create composite indexes for multi-column queries
- [ ] Create partial indexes for filtered subsets
- [ ] Create expression indexes for computed values
- [ ] Create GIN indexes for JSONB columns
- [ ] Create full-text search indexes if needed

### Phase 4: Optimization
- [ ] Create covering indexes for common queries
- [ ] Optimize JOIN queries with proper indexes
- [ ] Implement index maintenance routine
- [ ] Set up monitoring and alerts

### Phase 5: Validation
- [ ] Verify all indexes are created
- [ ] Test query performance improvements
- [ ] Monitor index usage statistics
- [ ] Remove unused indexes
- [ ] Document index strategy

---

## Common Pitfalls and Solutions

### Pitfall 1: Over-Indexing

**Problem:** Creating too many indexes slows down INSERT/UPDATE operations.

**Solution:** Only index columns that are frequently queried. Monitor index usage and remove unused ones.

### Pitfall 2: Wrong Column Order in Composite Indexes

**Problem:** Composite index column order doesn't match query patterns.

**Solution:** Put the most selective column first. Match the order to your WHERE clause order.

### Pitfall 3: Not Updating Statistics

**Problem:** Query planner makes poor decisions because statistics are outdated.

**Solution:** Run `ANALYZE` regularly, especially after bulk data changes.

### Pitfall 4: Ignoring Index Maintenance

**Problem:** Indexes become bloated and inefficient over time.

**Solution:** Regular VACUUM and REINDEX operations. Monitor index sizes.

### Pitfall 5: Indexing Low-Selectivity Columns

**Problem:** Indexing a column with only 2-3 distinct values (like a boolean) may not help.

**Solution:** Use partial indexes instead, or combine with other columns in a composite index.

---

## Next Steps

After completing this guide:

1. **Monitor Performance:** Set up regular monitoring of query performance
2. **Iterate:** As your application evolves, review and adjust indexes
3. **Document:** Keep your index documentation up to date
4. **Automate:** Create scripts to automate index maintenance
5. **Educate:** Share this knowledge with your team

Remember: Database indexing is an ongoing process, not a one-time task. As your data grows and query patterns change, you'll need to adjust your indexing strategy.

---

## Resources

- PostgreSQL Index Documentation: https://www.postgresql.org/docs/current/indexes.html
- Using EXPLAIN: https://www.postgresql.org/docs/current/using-explain.html
- Index Types: https://www.postgresql.org/docs/current/indexes-types.html
- pg_stat_statements: https://www.postgresql.org/docs/current/pgstatstatements.html

---

## Summary

You've now learned:
- What database indexes are and why they matter
- How to identify which columns need indexing
- How to create basic and advanced indexes
- How to monitor and maintain indexes
- How to implement a comprehensive indexing strategy

The key to effective indexing is understanding your query patterns and continuously monitoring performance. Start with the basics, measure the impact, and gradually implement more advanced strategies as needed.

