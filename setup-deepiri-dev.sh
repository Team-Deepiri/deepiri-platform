#!/usr/bin/env bash
# ============================================================================
# Deepiri Platform (cloud portal) — dev setup redirect
# ----------------------------------------------------------------------------
# Full local/lab stack (Cyrex, LIS, speech engine, Kafka) → deepiri-control-plane
# Cloud VPS deploy (this repo): docker compose -f docker-compose.yml up -d
# ============================================================================

set -u
set -o pipefail

CONTROL_PLANE_REPO="git@github.com:Team-Deepiri/deepiri-control-plane.git"

cat <<EOF
This is the cloud portal repo (deepiri-platform).

Full dev stack setup lives in deepiri-control-plane:
  git clone $CONTROL_PLANE_REPO
  cd deepiri-control-plane
  bash setup-deepiri-dev.sh

Cloud portal deploy (this repo):
  docker compose -f docker-compose.yml up -d

Architecture: docs/architecture/REPO_SPLIT.md
EOF
exit 1
