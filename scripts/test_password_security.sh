#!/bin/bash
# Password Security Integration Tests
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

assert_pass() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local desc="$1"
    shift
    if ! "$@" > /dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected failure)"
        FAIL=$((FAIL + 1))
    fi
}

echo "================================================"
echo "Password Security Integration Tests"
echo "================================================"
echo ""

echo "Test 1: Security validators module"
assert_pass "security_validators.py exists" test -f "$PROJECT_ROOT/diri-cyrex/app/utils/security_validators.py"

echo ""
echo "Test 2: Unit tests"
assert_pass "test_security_validators.py exists" test -f "$PROJECT_ROOT/diri-cyrex/tests/test_security_validators.py"

echo ""
echo "Test 3: Environment templates"
assert_pass "Root .env.example exists" test -f "$PROJECT_ROOT/.env.example"
assert_pass "Cyrex .env.example exists" test -f "$PROJECT_ROOT/diri-cyrex/.env.example"

echo ""
echo "Test 4: Generation instructions in .env.example"
assert_pass ".env.example contains openssl instructions" grep -q "openssl rand" "$PROJECT_ROOT/.env.example"

echo ""
echo "Test 5: Docker Compose requires env vars"
assert_pass "POSTGRES_PASSWORD required" grep -q "POSTGRES_PASSWORD:?" "$PROJECT_ROOT/docker-compose.yml"
assert_pass "REDIS_PASSWORD required" grep -q "REDIS_PASSWORD:?" "$PROJECT_ROOT/docker-compose.yml"
assert_pass "JWT_SECRET required" grep -q "JWT_SECRET:?" "$PROJECT_ROOT/docker-compose.yml"
assert_pass "MONGO_ROOT_PASSWORD required" grep -q "MONGO_ROOT_PASSWORD:?" "$PROJECT_ROOT/docker-compose.yml"
assert_pass "INFLUXDB_PASSWORD required" grep -q "INFLUXDB_PASSWORD:?" "$PROJECT_ROOT/docker-compose.yml"
assert_pass "GRAFANA_ADMIN_PASSWORD required" grep -q "GRAFANA_ADMIN_PASSWORD:?" "$PROJECT_ROOT/docker-compose.yml"

echo ""
echo "Test 6: No hardcoded defaults for critical passwords"
assert_fail "No deepiripassword default in postgres service" grep -q "POSTGRES_PASSWORD.*:-deepiripassword" "$PROJECT_ROOT/docker-compose.yml"
assert_fail "No redispassword default in command" grep -q "requirepass.*:-redispassword" "$PROJECT_ROOT/docker-compose.yml"

echo ""
echo "Test 7: Documentation"
assert_pass "Migration guide exists" test -f "$PROJECT_ROOT/docs/security/PASSWORD_SECURITY_MIGRATION.md"
assert_pass "Validation reference exists" test -f "$PROJECT_ROOT/docs/security/PASSWORD_SECURITY_VALIDATION.md"

echo ""
echo "Test 8: No hardcoded password fallbacks in Python code"
assert_fail "No deepiripassword fallback in postgres.py" grep -q "'deepiripassword'" "$PROJECT_ROOT/diri-cyrex/app/database/postgres.py"
assert_fail "No default-secret fallback in authentication.py" grep -q "default-secret-change-in-production" "$PROJECT_ROOT/diri-cyrex/app/core/authentication.py"
assert_fail "No minioadmin fallback in model_loader.py" grep -q '"minioadmin"' "$PROJECT_ROOT/diri-cyrex/app/integrations/model_loader.py"

echo ""
echo "Test 9: CYREX_API_KEY keeps dev default"
assert_pass "CYREX_API_KEY has change-me default" grep -q "CYREX_API_KEY.*:-change-me" "$PROJECT_ROOT/docker-compose.yml"

echo ""
echo "================================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================================"

exit $FAIL
