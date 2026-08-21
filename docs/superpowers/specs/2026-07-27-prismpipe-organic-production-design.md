# PrismPipe Organic Production Design

**Date:** 2026-07-27  
**Status:** Implemented (Phases 1–3)

## Thesis

Requests become durable computational organisms with **correct shared computation**, inheritable knowledge, and measurable reuse.

## Priority order

1. Extend PrismPipe until Organic claims are real
2. Benchmarks that prove or kill those claims
3. Integration + regression as go/no-go before Deepiri wiring
4. Deepiri wiring (Gateway/LIS/Cyrex) out of scope until GO

## Architecture

- **ComputationGraph** stores and restores capability outputs on hit
- **OrganismExecutor** wires Mutation, Watcher, EventBus
- **SwarmCoordinator** runs workers through the router then reduces
- **TimeSplitter** cancels losers; branch timeout budget
- **OrganismPersistence** async hibernate/wake via Memory / Redis / Postgres
- **HTTP** organism protocol on `:5011` with `/metrics`

## Non-goals

RAFT, Gravity RPC, genetic hyperparams, package publish, replacing all REST endpoints.
