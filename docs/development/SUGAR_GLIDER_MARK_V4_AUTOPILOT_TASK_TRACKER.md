# Sugar Glider Mark v4 Autopilot Task Tracker

Updated: 2026-05-02 (UTC)

## Purpose

Track the Mark v4 autoplay execution with linked artifacts and continuation decisions.

## Task Status

- [x] Task 01: Enable websocket native-addon path in RTG runtime
- [x] Task 02: Run full websocket-native matrix benchmark
- [x] Task 03: Run full websocket-no-native matrix benchmark + comparison
- [x] Task 04: Lock mini-task roadmap and execution order
- [x] Task 05: RTG ACK/in-flight 32KB sweep
- [x] Task 06: Sidecar dispatcher 32KB sweep
- [x] Task 07: Cross-layer retune on top of Task 06 winner
- [x] Task 08: Full websocket matrix run 1 (autoplay)
- [x] Task 09: Full websocket matrix run 2 (autoplay)
- [x] Task 10: Comparison package and gate check
- [x] Task 11: Final decision note and documentation pass
- [x] Task 12: Restored fast-path full websocket run 1
- [x] Task 13: Restored fast-path full websocket run 2
- [x] Task 14: Restored fast-path comparison package
- [x] Task 15: Restored fast-path decision note
- [x] Task 16: Heavy-path CPU/RAM profile capture
- [x] Task 17: Optimization backlog and execution priorities
- [x] Task 18: Benchmark runtime pinning and runtime-evidence capture
- [x] Task 19: Mark v3 vs Mark v4 speed-signature bottleneck scan
- [x] Task 20: RTG socket hot-path instrumentation for heavy benchmark buckets
- [x] Task 21: RTG hot-path profile capture on heavy websocket probe
- [x] Task 22: Sidecar dispatcher/ack micro-timing capture
- [x] Task 23: Publish-to-delivery overlap extraction on recent heavy probes
- [x] Task 24: Queue-depth and backpressure telemetry snapshots
- [x] Task 25: RTG emit-path targeted micro A/B
- [x] Task 26: Sidecar ACK pipeline targeted micro A/B
- [x] Task 27: Promotion gate check (heavy gains + guardrail lanes)
- [x] Task 28: V3/V4 battlefield lock against frozen Mark v3 controls
- [x] Task 29: Guardrail recovery sweep on `1024/8192 c50`
- [x] Task 30: Heavy-preservation check on `32768 c10/c50`
- [x] Task 31: Full-matrix promotion gate on locked V4 profile
- [x] Task 32: Breakthrough tracks for lane profiles, parser tests, ACK compression, and direct broadcast
- [x] Task 33: Release readiness package and stable fast-gate validation

## Task 01-04 Summary

These setup/proving steps were completed before this autoplay continuation and established the websocket-native benchmark lane:

- Runtime and compose support for websocket-native controls in RTG.
- Full websocket-native and websocket-no-native benchmark evidence.
- No-native path showed significant regression and was rejected.

Key artifact:

- `benchmarks/end-to-end/20260427T003237Z-v4-websocket-no-native-full/native_vs_no_native_comparison.md`

## Task 05

- `benchmarks/end-to-end/20260427T010430Z-task5-32kb-ack-inflight-sweep.md`
- Outcome: no RTG ACK/in-flight profile beat baseline at 32KB.

## Task 06

- `benchmarks/end-to-end/20260427T011857Z-task6-sidecar-dispatcher-sweep.md`
- Outcome: aggressive sidecar dispatcher profile won targeted 32KB sweep.

## Task 07

- `benchmarks/end-to-end/20260427T012831Z-task7-crosslayer-retune.md`
- Outcome: no RTG retune beat baseline on top of Task 06 winner.

## Task 08

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK08_FULL_WEBSOCKET_RUN1.md`

## Task 09

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK09_FULL_WEBSOCKET_RUN2.md`

## Task 10

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK10_COMPARISON_PACKAGE.md`

## Task 11

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK11_DECISION_NOTE.md`

## Final Standing

The autoplay sequence completed all remaining tasks, generated full artifacts, and recorded a no-go decision for promotion because full-matrix throughput stayed below the `2.7x` target despite clean reliability.

## Continuation (Task 12-15)

After Task 11, a continuation pass restored the sidecar fast-path defaults and re-ran two full websocket matrices:

- `20260427T020235Z-v4-iteration3-fastpath-run1`
- `20260427T020718Z-v4-iteration3-fastpath-run2`

This continuation improved throughput over Task 08/09 (about `+3.96%` pair-mean ratio), but still failed the `2.7x` target and remained below v3 fixed repeat2 and the prior v4 websocket-native reference.

Continuation docs:

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK12_FASTPATH_RUN1.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK13_FASTPATH_RUN2.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK14_FASTPATH_COMPARISON_PACKAGE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK15_FASTPATH_DECISION_NOTE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK16_HEAVYPATH_PROFILE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK17_OPTIMIZATION_BACKLOG.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK18_RUNTIME_PINNING.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK19_V3_SPEED_SIGNATURE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK20_RTG_SOCKET_HOTPATH_INSTRUMENTATION.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK21_RTG_HOTPATH_PROFILE_CAPTURE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK22_SIDECAR_MICROTIMING_CAPTURE.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK23_PUBLISH_DELIVERY_OVERLAP.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK24_QUEUE_BACKPRESSURE_SNAPSHOTS.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK25_RTG_EMITPATH_AB.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK26_SIDECAR_ACK_AB.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK27_PROMOTION_GATE_CHECK.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK28_BATTLEFIELD_LOCK.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK29_GUARDRAIL_RECOVERY.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK30_HEAVY_PRESERVATION.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK31_FULL_MATRIX_PROMOTION.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK32_BREAKTHROUGH_TRACKS.md`
- `docs/development/SUGAR_GLIDER_MARK_V4_TASK33_RELEASE_READINESS.md`

## Task 22

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK22_SIDECAR_MICROTIMING_CAPTURE.md`
- Outcome: sidecar timing confirms ACK flush pipeline execution dominates ACK flush duration under heavy websocket load.

## Task 23

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK23_PUBLISH_DELIVERY_OVERLAP.md`
- Outcome: overlap analysis shows heavy-path downstream latency share remains dominant, especially at `32768:c50`.

## Task 24

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK24_QUEUE_BACKPRESSURE_SNAPSHOTS.md`
- Outcome: live snapshot telemetry added for queue depth/counter deltas during heavy websocket probes.

## Task 25

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK25_RTG_EMITPATH_AB.md`
- Outcome: `STREAM_EXTRACT_USER_FROM_PAYLOAD=false` is decisively faster than `true` for heavy benchmark lanes.

## Task 26

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK26_SIDECAR_ACK_AB.md`
- Outcome: ACK tuning variant (`512/12/4`) did not beat baseline sidecar profile overall.

## Task 27

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK27_PROMOTION_GATE_CHECK.md`
- Outcome: heavy-lane gains passed, guardrail lanes regressed; full-matrix rerun not yet approved.

## Task 28

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK28_BATTLEFIELD_LOCK.md`
- `benchmarks/end-to-end/20260429T015420Z-task28-v3-v4-battlefield-lock/v3_v4_speed_signature.md`
- Outcome: direct Mark v3 battlefield comparison is **NO-GO**; `32768 c10`, `32768 c50`, and `8192 c50` pass, but `1024 c50` fails and five full-matrix cells remain untested.
- Next recommended task: guardrail recovery starting with `1024 c50`, not a full promotion rerun.

## Task 29

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK29_GUARDRAIL_RECOVERY.md`
- `benchmarks/end-to-end/20260502T024312Z-task29-guardrail-recovery/guardrail_sweep_summary.md`
- Outcome: guardrail recovery passed; the original `1024 c50` failure did not reproduce after a clean service restart, and `STREAM_SUBSCRIBE_BATCH_SIZE=256` was the fastest confirmed guardrail-safe profile.
- Next recommended task: heavy-preservation check on `32768 c10/c50` with the selected `sub256` profile.

## Task 30

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK30_HEAVY_PRESERVATION.md`
- `benchmarks/end-to-end/20260502T025459Z-task30-heavy-preservation/heavy_preservation_summary.md`
- Outcome: `STREAM_SUBSCRIBE_BATCH_SIZE=256` was rejected because it lost `32768 c10` against the current V4 heavy winner; the locked profile for the next gate is the baseline heavy-winner profile (`STREAM_SUBSCRIBE_BATCH_SIZE=128`, `STREAM_EXTRACT_USER_FROM_PAYLOAD=false`).
- Next recommended task: full-matrix validation on the locked baseline heavy-winner profile.

## Task 31

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK31_FULL_MATRIX_PROMOTION.md`
- `benchmarks/end-to-end/20260502T030058Z-task31-full-matrix-promotion/v3_v4_promotion_table.md`
- Outcome: **GO**. Two locked-profile full matrices beat frozen Mark v3 in all `9/9` cells with clean reliability.
- Promotion metrics: mean V4/V3 throughput ratio `2.1101x`, minimum ratio `1.5472x`, heavy-path mean ratio `1.7528x`, guardrail `c50` mean ratio `1.6912x`.
- Next recommended task: package the Mark v4 release/PR while keeping Mark v3 frozen as rollback.

## Task 32

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK32_BREAKTHROUGH_TRACKS.md`
- Outcome: breakthrough tracks are implemented behind no-op-by-default flags. RTG can now expose lane-aware counters, optional Socket.IO MessagePack parser status, and lab-only direct broadcast payload modes; Sugar Glider now exposes ACK dedupe and contiguous-span opportunity metrics.
- Safety classification: lane/ACK observability is production-safe; MessagePack and direct payload broadcast stay lab-only until client compatibility and full-matrix gates pass.
- Next recommended task: run short lane-observe, ACK-opportunity, and direct-heavy lab probes, then only promote a winning breakthrough through the full Task 31-style V3 comparison gate.

## Task 33

- `docs/development/SUGAR_GLIDER_MARK_V4_TASK33_RELEASE_READINESS.md`
- Outcome: Mark v4 release-readiness package finalized with locked shipping profile, baseline-vs-v3 positioning, and validated runtime state (`SOCKET_IO_PARSER=default`, breakthrough flags off).
- Gate reliability: `rtg-gate` now pre-creates dedicated smoke consumer groups at stream tail (`$`) before HTTP/gRPC smoke to avoid backlog-driven flakes.
- Validation: `npm build`, `go test ./...`, and `make rtg-sugar-gate` all pass.
- Next recommended task: submit the release PR to the team dev branch with Task 31 + Task 33 artifacts and keep Task 32 flags disabled in production.
