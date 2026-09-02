#!/usr/bin/env bash
# Makes sure nginx has *some* cert to load at /etc/letsencrypt/live/current
# before it starts, so a fresh box (or a local-prod smoke test with no real
# domain) doesn't crash-loop on a missing ssl_certificate file.
#
# - Real prod: ops/nginx/init-letsencrypt.sh calls this once with the real
#   domain, then immediately replaces the dummy with a real Let's Encrypt
#   cert via certbot.
# - Local-prod testing: scripts/infra/measure-compose.sh calls this with
#   "localhost" so nginx boots the same way it will in prod, without
#   needing a real domain. The self-signed cert is never presented to real
#   users in that path.
#
# Usage: ensure-dummy-cert.sh <domain> [-- <docker compose args...>]
set -euo pipefail

DOMAIN="${1:?Usage: ensure-dummy-cert.sh <domain> [-- <docker compose args...>]}"
shift
if [ "${1:-}" = "--" ]; then shift; fi
COMPOSE_ARGS=("$@")

compose() {
  docker compose "${COMPOSE_ARGS[@]}" "$@"
}
# `run` calls below pass -T (no TTY / don't inherit stdin). Without it, when this
# script is fed to a shell over `ssh ... bash -s`, `docker compose run` consumes
# the caller's remaining stdin — i.e. the rest of the script.

if compose run --rm -T --entrypoint sh certbot -c \
    'test -e /etc/letsencrypt/live/current' >/dev/null 2>&1; then
  echo "ensure-dummy-cert: /etc/letsencrypt/live/current already exists, leaving it alone."
  exit 0
fi

echo "ensure-dummy-cert: no cert found, generating a throwaway self-signed one for ${DOMAIN}..."
compose run --rm -T --entrypoint sh certbot -c "
  set -e
  mkdir -p /etc/letsencrypt/live/${DOMAIN}
  openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
    -keyout /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
    -out /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
    -subj '/CN=${DOMAIN}'
  ln -sfn ${DOMAIN} /etc/letsencrypt/live/current
"
echo "ensure-dummy-cert: done."
