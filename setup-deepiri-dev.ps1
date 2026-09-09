# ============================================================================
# Deepiri Platform (cloud portal) — dev setup redirect (Windows)
# Full local/lab stack → deepiri-control-plane
# Cloud VPS: docker compose -f docker-compose.yml up -d
# ============================================================================

$ControlPlane = "git@github.com:Team-Deepiri/deepiri-control-plane.git"
Write-Host @"
This is the cloud portal repo (deepiri-platform).

Full dev stack setup lives in deepiri-control-plane:
  git clone $ControlPlane
  cd deepiri-control-plane
  .\setup-deepiri-dev.ps1

Cloud portal deploy (this repo):
  docker compose -f docker-compose.yml up -d

See docs/architecture/REPO_SPLIT.md
"@
exit 1
