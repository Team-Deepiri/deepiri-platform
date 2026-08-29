#!/bin/sh
set -eu

: "${PROXY_USER:?PROXY_USER must be set}"
: "${PROXY_PASS:?PROXY_PASS must be set}"
: "${PROXY_PORT:=1080}"

exec microsocks -i 0.0.0.0 -p "$PROXY_PORT" -u "$PROXY_USER" -P "$PROXY_PASS"
