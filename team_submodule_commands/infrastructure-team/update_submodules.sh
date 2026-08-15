#!/usr/bin/env bash
# Superseded: delegates to setup-deepiri-dev.sh with --update-submodules.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../_invoke_setup_submodules.sh" infrastructure --update
