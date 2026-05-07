# Sugar Glider Final Push - Task 06 Fallback Path Hardening

Updated: 2026-04-23 (UTC)

## Objective

Harden non-happy publish paths so reliability behavior stays deterministic under queue pressure, shutdown, and timeout/cancel conditions.

## Hardening Implemented

Code touched:

- `platform-services/shared/deepiri-sugar-glider/internal/service/service.go`
- `platform-services/shared/deepiri-sugar-glider/internal/service/grpc.go`

Behavior:

1. Queue pressure fallback:
   - If publish pipeline returns queue-full or stopped, request falls back to direct publish path immediately.
2. Fallback failure accounting:
   - If direct fallback publish fails, pipeline error counter increments.
3. Cancellation/timeout path:
   - Publish cancellation/deadline errors return `http.StatusGatewayTimeout` and skip WAL append.
4. gRPC status mapping:
   - `504` now maps to `codes.DeadlineExceeded`.

## Why This Matters

- Prevents queue pressure from becoming user-visible failure by default.
- Keeps timeout/cancel semantics clean (no accidental WAL queue on canceled request).
- Preserves durability behavior for real Redis failures through existing WAL append path.

## Outcome

Task 06 completed.

