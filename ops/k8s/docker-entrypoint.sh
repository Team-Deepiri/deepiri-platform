#!/bin/bash
# Universal Docker entrypoint that loads K8s env vars then executes command
# For services without existing entrypoints
# Usage: ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Load K8s environment variables
source /usr/local/bin/load-k8s-env.sh

# Execute the original command
exec "$@"

