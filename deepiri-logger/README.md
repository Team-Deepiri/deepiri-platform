# Deepiri Logger

Unified, multi-language logging foundation for Deepiri services.

## Repository Layout

- `shared/`: language-agnostic logging contract
- `python/`: Python adapter (`deepiri_logger`)
- `nodejs/`: Node.js adapter (`@deepiri/logger`)
- `rust/`: Rust adapter (`deepiri_logger_rs`)

## Golden Schema

All adapters emit the same event shape:

- `timestamp`: ISO8601 timestamp
- `level`: `DEBUG|INFO|WARNING|ERROR|CRITICAL`
- `service_name`: microservice identifier
- `version`: service/application version
- `trace_id`: request trace identifier
- `message`: readable event message
- `context`: structured metadata object

Schema source of truth: `shared/schema.json`.

## PII Policy

PII masking patterns are defined in `shared/pii-patterns.yml` and should be mirrored by all adapters.

## Initial Scope

This bootstrap provides:

- shared schema and PII policy files
- Python adapter scaffold with masking and init entrypoint
- Node.js adapter scaffold with formatter and middleware
- Rust adapter scaffold with subscriber setup hooks

Service integrations are intentionally out of scope for this pitstop and should be done in follow-up PRs.
