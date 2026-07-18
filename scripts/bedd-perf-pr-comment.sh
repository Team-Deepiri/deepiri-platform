#!/usr/bin/env bash
# Capture Bedd mock perf and print a PR-ready markdown comment.
set -euo pipefail
BEDD_ROOT="${BEDD_ROOT:-$(cd "$(dirname "$0")/../../deepiri-bedd" 2>/dev/null && pwd || true)}"
if [[ -z "${BEDD_ROOT}" || ! -x "${BEDD_ROOT}/zig-out/bin/bedd" ]]; then
  echo "Set BEDD_ROOT to a built deepiri-bedd checkout" >&2
  exit 1
fi
OUT=$(mktemp -d)
BEDD_BIN="${BEDD_ROOT}/zig-out/bin/bedd" "${BEDD_ROOT}/scripts/perf-matrix.sh" "$OUT" >/dev/null
cat "$OUT/REPORT.md"
echo
echo "### Integration note"
echo "Overlay: \`docker-compose.bedd.yml\` on platform PR #184 base."
echo "LIS document bus cohesion is separate (LIS PR #64) — Bedd is optional there."
echo
echo "**Final verdict:** Bedd is healthy as an optional skill worker; do not force it onto every bus hop."
