#!/bin/sh
set -eu

: "${PROXY_USER:?PROXY_USER must be set}"
: "${PROXY_PASS:?PROXY_PASS must be set}"
: "${PROXY_PORT:=8888}"

cat > /etc/tinyproxy/tinyproxy.conf <<EOF
User nobody
Group nobody
Port ${PROXY_PORT}
Listen 0.0.0.0
Timeout 60
LogLevel Info
PidFile "/var/run/tinyproxy.pid"
MaxClients 20
BasicAuth ${PROXY_USER} ${PROXY_PASS}
DisableViaHeader Yes
EOF

exec tinyproxy -d -c /etc/tinyproxy/tinyproxy.conf
