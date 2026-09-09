# deepiri-jobs

Async job runner for the Deepiri platform.

## Job types

| Type | Description |
|------|-------------|
| `helox.train` | Dispatch training run to Helox |
| `platform.pg_backup` | Nightly (or on-demand) Postgres dump to a gzip file |

## `platform.pg_backup`

Replaces the standalone `pg-backup` compose service. Scheduled via in-process cron when `PG_BACKUP_SCHEDULER_ENABLED=true`.

### Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `PG_BACKUP_SCHEDULER_ENABLED` | `false` | Enable daily cron enqueue |
| `PG_BACKUP_CRON` | `0 2 * * *` | Cron schedule (UTC in container) |
| `PG_BACKUP_HOST` | `postgres` | Postgres host |
| `PG_BACKUP_PORT` | `5432` | Postgres port |
| `PG_BACKUP_DB` | `platform_core` | Database name |
| `PG_BACKUP_USER` | `deepiri` | Dump user |
| `PG_BACKUP_PASSWORD` | — | Required; falls back to `POSTGRES_PASSWORD` / `POSTGRES_CORE_PASSWORD` |
| `PG_BACKUP_DIR` | `/backups/postgres` | Output directory (mount a volume here) |
| `PG_BACKUP_RETENTION_DAYS` | `30` | Delete local `.sql.gz` older than this |

### Manual trigger

```bash
curl -X POST http://localhost:5007/api/jobs \
  -H 'Content-Type: application/json' \
  -d '{"type":"platform.pg_backup"}'
```

Scheduled runs use idempotency key `platform.pg_backup:YYYY-MM-DD` (one per calendar day).

### Offsite sync

Optional `pg-backup-offsite` sidecar reads the same `postgres_backups` volume at `/backups/postgres`.

## Endpoints

- `GET /health`
- `GET /api/jobs`
- `POST /api/jobs`
- `GET /api/jobs/:id`
- `GET /api/jobs/:id/logs`
- `POST /api/jobs/:id/cancel`
- `POST /api/jobs/:id/retry`
- `GET /api/queues/stats`
