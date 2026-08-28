#!/usr/bin/env bash
# One-time bootstrap for real TLS on the cheap one-box VPS.
#
# Standard nginx+certbot dance (same shape as https://github.com/wmnnd/nginx-certbot):
#   1. Start nginx with a throwaway self-signed cert so it can bind :443 at all.
#   2. Ask Let's Encrypt for a real cert over the webroot HTTP-01 challenge.
#   3. Point /etc/letsencrypt/live/current at the real cert and reload nginx.
#
# Run this ONCE per box, after DNS for $DOMAIN_NAME already points at it.
# Renewal after this is automatic (the `certbot` service in docker-compose.yml
# runs `certbot renew` on a loop) but nginx won't notice a renewed cert until
# it reloads — see the note this script prints at the end.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DOMAIN_NAME="${DOMAIN_NAME:?Set DOMAIN_NAME to the real domain pointed at this box}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:?Set CERTBOT_EMAIL for Let's Encrypt renewal notices}"
COMPOSE=(docker compose -f docker-compose.yml)

echo "==> Ensuring a cert (dummy, for now) exists so nginx can start..."
./ops/nginx/ensure-dummy-cert.sh "$DOMAIN_NAME" -- -f docker-compose.yml

echo "==> Starting nginx (and certbot) so the webroot challenge path is servable..."
"${COMPOSE[@]}" up -d nginx certbot

echo "==> Removing the dummy cert so certbot doesn't think a real one already exists..."
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "rm -rf /etc/letsencrypt/live/${DOMAIN_NAME} /etc/letsencrypt/archive/${DOMAIN_NAME} /etc/letsencrypt/renewal/${DOMAIN_NAME}.conf"

echo "==> Requesting a real certificate from Let's Encrypt for ${DOMAIN_NAME}..."
"${COMPOSE[@]}" run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  --email "$CERTBOT_EMAIL" -d "$DOMAIN_NAME" \
  --rsa-key-size 2048 --agree-tos --no-eff-email

echo "==> Pointing /etc/letsencrypt/live/current at the real cert..."
"${COMPOSE[@]}" run --rm --entrypoint sh certbot -c "ln -sfn ${DOMAIN_NAME} /etc/letsencrypt/live/current"

echo "==> Reloading nginx to pick it up..."
"${COMPOSE[@]}" exec nginx nginx -s reload

cat <<EOF

Done. ${DOMAIN_NAME} should now serve a real Let's Encrypt certificate.

The certbot service auto-renews in the background, but nginx only picks up
a renewed cert on reload. Add a host crontab entry (outside docker) to
reload nginx periodically, e.g. weekly:

  0 3 * * 0 cd ${ROOT_DIR} && docker compose exec nginx nginx -s reload

EOF
