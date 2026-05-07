# Sugar Glider Final Push - Task 09 Unit Test Expansion

Updated: 2026-04-23 (UTC)

## Objective

Add focused unit tests for publish pipeline hardening and new configuration contract.

## Tests Added

### Service tests

File:

- `platform-services/shared/deepiri-sugar-glider/internal/service/publish_fallback_test.go`

Coverage:

- direct publish path when pipeline is disabled
- queue-full fallback to direct publish
- stopped-pipeline fallback and failure accounting
- non-fallback pipeline errors bypass direct publish
- canceled publish skips WAL queue
- Redis publish failure queues to WAL

### gRPC mapping test

File:

- `platform-services/shared/deepiri-sugar-glider/internal/service/grpc_test.go`

Coverage:

- HTTP `504` -> gRPC `DeadlineExceeded` mapping

### Config tests

File:

- `platform-services/shared/deepiri-sugar-glider/internal/config/config_test.go`

Coverage:

- publish pipeline defaults
- publish pipeline env overrides
- publish pipeline validation failure (`MAX_BATCH=0`)

## Outcome

Task 09 completed.

