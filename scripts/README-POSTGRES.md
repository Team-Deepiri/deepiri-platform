## 🗄️ PostgreSQL Database Scripts

Complete PostgreSQL database management for Deepiri platform.

---

### 📋 Available Scripts

#### 1. **postgres-init.sql** - Database Initialization
Complete production-ready schema with:
- **Schemas**: `public`, `analytics`, `audit`
- **Core Tables**: Users, roles, tasks, projects, quests
- **Analytics**: Momentum, streaks, boosts, achievements
- **Audit**: Activity logs, task completions
- **Triggers**: Auto-update timestamps, audit logging
- **Indexes**: Optimized for performance
- **JSONB**: AI suggestions, metadata storage

**Usage:**
```bash
# Automatically runs on container start via docker-compose
# Or run manually:
psql -h localhost -p 5432 -U deepiri -d deepiri -f scripts/postgres-init.sql
```

#### 2. **postgres-seed.sql** - Development Seed Data
Creates test data including:
- 5 test users (admin, alice, bob, carol, dave)
- Sample projects and quests
- Tasks with AI suggestions
- Momentum, streaks, and achievements
- All passwords: `password123`

**Usage:**
```bash
psql -h localhost -p 5432 -U deepiri -d deepiri -f scripts/postgres-seed.sql
```

**Test Users:**
```
admin@deepiri.com - Admin User (full access)
alice@deepiri.com - Product Manager
bob@deepiri.com - Senior Developer
carol@deepiri.com - UX Designer
dave@deepiri.com - DevOps Engineer
```

#### 3. **postgres-backup.sh** - Backup Script
Automated PostgreSQL backups with:
- Compressed .sql.gz files
- Timestamp naming
- Retention policy (30 days default)
- Latest symlink
- Size reporting

**Usage:**
```bash
# Basic backup
./scripts/postgres-backup.sh

# Custom backup location
BACKUP_DIR=/path/to/backups ./scripts/postgres-backup.sh

# Custom retention
BACKUP_RETENTION_DAYS=60 ./scripts/postgres-backup.sh
```

**Environment Variables:**
```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=deepiri
POSTGRES_USER=deepiri
POSTGRES_PASSWORD=deepiripassword
BACKUP_DIR=./backups/postgres
BACKUP_RETENTION_DAYS=30
```

#### 4. **postgres-restore.sh** - Restore Script
Safe database restoration with:
- Interactive backup selection
- Safety backup before restore
- Database recreation
- Verification checks
- VACUUM ANALYZE optimization

**Usage:**
```bash
# Interactive mode (choose from list)
./scripts/postgres-restore.sh

# Restore specific backup
./scripts/postgres-restore.sh deepiri_backup_20250129_120000.sql.gz

# Restore latest
./scripts/postgres-restore.sh ./backups/postgres/latest.sql.gz
```

---

### 🚀 Quick Start Guide

#### **First Time Setup**

1. **Start PostgreSQL:**
```bash
docker-compose up postgres pgadmin -d
```

2. **Initialize Database:**
```bash
# Already happens automatically on first start
# Check logs:
docker logs deepiri-postgres-dev
```

3. **Seed Test Data:**
```bash
docker exec -i deepiri-postgres-dev psql -U deepiri -d deepiri < scripts/postgres-seed.sql
```

4. **Access pgAdmin:**
- URL: http://localhost:5050
- Email: admin@deepiri.com
- Password: admin

---

### 🔄 Regular Operations

#### **Daily Backup (Cron)**
```bash
# Add to crontab
0 2 * * * /path/to/deepiri/scripts/postgres-backup.sh >> /var/log/deepiri-backup.log 2>&1
```

#### **Weekly Backup with Upload to S3**
```bash
# Set AWS credentials
export AWS_S3_BACKUP_BUCKET=my-deepiri-backups
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx

# Run backup (uncomment S3 section in script)
./scripts/postgres-backup.sh
```

#### **Restore from Backup**
```bash
# Always creates safety backup first
./scripts/postgres-restore.sh
```

---

### 📊 Database Schema Overview

#### **Public Schema** (Core Data)
```
users ─┬─ user_roles ─── roles ─── role_abilities
       ├─ sessions
       ├─ projects ─── project_milestones
       ├─ quests
       └─ tasks ─┬─ subtasks
                 ├─ task_dependencies
                 └─ task_versions
```

#### **Analytics Schema** (Gamification)
```
momentum ─┬─ level_progress
          └─ achievements

streaks ─── cashed_in_streaks

boosts ─┬─ active_boosts
        └─ boost_history
```

#### **Audit Schema** (Tracking)
```
activity_logs (auto-populated via triggers)
task_completions
user_activity_summary
```

---

### 🔍 Useful Queries

#### **Check Database Size**
```sql
SELECT pg_size_pretty(pg_database_size('deepiri'));
```

#### **List All Tables**
```sql
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname IN ('public', 'analytics', 'audit')
ORDER BY schemaname, tablename;
```

#### **User Statistics**
```sql
SELECT 
    u.name,
    m.total_momentum,
    m.current_level,
    s.daily_current as daily_streak,
    b.boost_credits
FROM public.users u
LEFT JOIN analytics.momentum m ON m.user_id = u.id
LEFT JOIN analytics.streaks s ON s.user_id = u.id
LEFT JOIN analytics.boosts b ON b.user_id = u.id
WHERE u.email LIKE '%@deepiri.com';
```

#### **Top Tasks by Momentum**
```sql
SELECT title, momentum_reward, status, tags
FROM public.tasks
ORDER BY momentum_reward DESC
LIMIT 10;
```

#### **Recent Activity**
```sql
SELECT 
    entity_type,
    action,
    created_at
FROM audit.activity_logs
ORDER BY created_at DESC
LIMIT 20;
```

---

### 🛠️ Maintenance

#### **VACUUM and ANALYZE**
```bash
docker exec deepiri-postgres-dev psql -U deepiri -d deepiri -c "VACUUM ANALYZE;"
```

#### **Reindex**
```bash
docker exec deepiri-postgres-dev psql -U deepiri -d deepiri -c "REINDEX DATABASE deepiri;"
```

#### **Check for Bloat**
```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname IN ('public', 'analytics', 'audit')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

### 🔒 Security Best Practices

1. **Change Default Passwords**
```bash
# In .env file or environment
POSTGRES_PASSWORD=your-strong-password-here
PGADMIN_PASSWORD=different-strong-password
```

2. **Restrict Network Access**
```yaml
# In docker-compose.yml - remove port exposure for production
# postgres:
#   ports:
#     - "5432:5432"  # Comment this out
```

3. **Use Read-Only Replicas**
```sql
-- Create read-only user for analytics
CREATE ROLE analytics_readonly WITH LOGIN PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE deepiri TO analytics_readonly;
GRANT USAGE ON SCHEMA public, analytics TO analytics_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public, analytics TO analytics_readonly;
```

4. **Enable SSL**
```bash
# In production, configure SSL certificates
POSTGRES_SSL_MODE=require
```

---

### 📈 Performance Tuning

#### **postgresql.conf Recommendations**
```ini
# Memory
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

# Connections
max_connections = 100

# Checkpoints
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Query planner
random_page_cost = 1.1  # For SSD
effective_io_concurrency = 200
```

#### **Connection Pooling (PgBouncer)**
```ini
[databases]
deepiri = host=postgres port=5432 dbname=deepiri

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

---

### 🚨 Troubleshooting

#### **"Connection refused"**
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check logs
docker logs deepiri-postgres-dev
```

#### **"Out of disk space"**
```bash
# Clean old backups
find ./backups/postgres -name "*.sql.gz" -mtime +30 -delete

# Vacuum full (reclaim space)
docker exec deepiri-postgres-dev psql -U deepiri -d deepiri -c "VACUUM FULL;"
```

#### **"Too many connections"**
```bash
# Check current connections
docker exec deepiri-postgres-dev psql -U deepiri -d deepiri -c \
  "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker exec deepiri-postgres-dev psql -U deepiri -d deepiri -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle';"
```

---

### 🔗 Related Documentation

- [MONGODB_TO_POSTGRESQL_MIGRATION.md](../MONGODB_TO_POSTGRESQL_MIGRATION.md) - Migration guide
- [ENVIRONMENT_VARIABLES.md](../ENVIRONMENT_VARIABLES.md) - Configuration
- [docker-compose files](../) - Infrastructure setup

---

### 📞 Support

For issues or questions:
1. Check logs: `docker logs deepiri-postgres-dev`
2. Review pgAdmin: http://localhost:5050
3. Check connection: `psql -h localhost -U deepiri -d deepiri`
4. Consult PostgreSQL docs: https://www.postgresql.org/docs/

---

**Last Updated:** 2025-01-29
**Database Version:** PostgreSQL 16
**Schema Version:** 1.0.0

