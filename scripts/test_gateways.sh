#!/usr/bin/env bash
set -euo pipefail

API_GATEWAY_URL=${API_GATEWAY_URL:-http://localhost:5100}
REALTIME_GATEWAY_URL=${REALTIME_GATEWAY_URL:-http://localhost:5008}

endpoints=(
  "$API_GATEWAY_URL/health"
  "$API_GATEWAY_URL/auth/health"
  "$REALTIME_GATEWAY_URL/health"
)

echo "Testing API Gateway: $API_GATEWAY_URL"
echo "Testing Realtime Gateway: $REALTIME_GATEWAY_URL"

failed=0
for url in "${endpoints[@]}"; do
  echo -e "\n--> GET $url"
  if resp=$(curl -sS -m 10 -w "\nHTTP_CODE:%{http_code}" "$url"); then
    http=$(echo "$resp" | sed -n 's/.*HTTP_CODE:\([0-9]\+\)$/\1/p')
    body=$(echo "$resp" | sed 's/HTTP_CODE:.*$//')
    echo "  HTTP $http"
    echo "  Body: $body"
    if [[ "$http" -ge 400 ]]; then
      echo "  ❌ non-2xx response"
      failed=1
    else
      echo "  ✅ OK"
    fi
  else
    echo "  ❌ request failed"
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo -e "\nOne or more tests failed." >&2
  exit 1
fi

echo -e "\nAll middleware tests passed."
