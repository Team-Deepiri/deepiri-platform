# Cyrex PostgreSQL migrations

Hand-written, versioned SQL for the Cyrex AGI artifact plane (`cyrex_db`).

This is the production path for Cyrex schema evolution. It is intentionally
**not** Prisma/Alembic — Cyrex owns a large SQL surface and a checksummed
ledger (`cyrex.schema_migrations`).

## Layout

| File | Layer |
|------|-------|
| `001_schema_meta.sql` | Extensions, schema, migration ledger, producer registry |
| `002_producer_registry_seed.sql` | Week 2 producer seed |
| `010_documents.sql` | Document ingest spine |
| `020_artifacts.sql` | Artifact graph |
| `030_pipeline.sql` | Pipeline runs / stages |
| `070_reckoning.sql` | Reckoning read models |
| `080_pressure.sql` | Pressure read models |
| `110_learning.sql` | Corrections / learning |
| `120_helox_bridge.sql` | Helox training bridge |

Number gaps (`040`–`060`, `090`, `100`, …) are reserved for later Phase 1/2
layers from the Cyrex AGI design plan. Do not renumber applied files.

## Rules

1. **Immutable after apply** — never edit a migration that has shipped to a
   shared environment. Add a new numbered file instead.
2. **One concern per file** — keep domain boundaries (documents vs pressure).
3. **Self-contained SQL** — extensions and DDL belong in `.sql` files, not the
   Python runner.
4. **Expand/contract** — prefer additive `ALTER` / new tables; destructive
   changes get their own reviewed migration plus a backup.
5. **Checksum enforcement** — the runner refuses to continue if an applied
   file's contents change.
6. **Init vs migrate** — `postgres-init-cyrex.sql` owns runtime ops tables
   (agents/workflows/memories/events). These migrations own the AGI plane.
   Do not duplicate AGI DDL in the init script.

## Apply

From the platform repo (host with `psql`, Cyrex DB on published port 5434):

```bash
python scripts/database/run-cyrex-migrations.py \
  --host localhost --port 5434 \
  --database cyrex_db \
  --user deepiri_cyrex \
  --password "$POSTGRES_CYREX_PASSWORD"
```

In Docker Compose, apply after `postgres-cyrex` is up (same idea as
`prisma migrate deploy` on Node service boot — run the runner, don't add a
separate migrate service):

```bash
docker compose -f docker-compose.dev.yml exec postgres-cyrex \
  pg_isready -U deepiri_cyrex

python scripts/database/run-cyrex-migrations.py \
  --host localhost --port 5434 \
  --database cyrex_db \
  --user deepiri_cyrex \
  --password "$POSTGRES_CYREX_PASSWORD"
```

## Verify

```bash
python -m pytest scripts/database/tests/test_cyrex_migrations.py -q
```

Optional live smoke (requires reachable Postgres + `psql`):

```bash
CYREX_MIGRATION_SMOKE_TEST=1 POSTGRES_PORT=5434 \
  python -m pytest scripts/database/tests/test_cyrex_migrations.py -q
```
