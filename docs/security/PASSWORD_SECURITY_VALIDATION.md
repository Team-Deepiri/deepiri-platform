# Password Security Validation - Technical Reference

## Architecture

```
Environment Variable → Docker Compose Validation → Pydantic Settings Validation → Application Code
                       (${VAR:?error} syntax)       (field_validator)              (no fallback defaults)
```

## Components

### 1. PasswordValidator (`diri-cyrex/app/utils/security_validators.py`)

Environment-aware password validation with three tiers:

| Environment | Min Length | Weak Check | Complexity | Required |
|-------------|-----------|------------|------------|----------|
| development | None      | No         | No         | No       |
| staging     | 12        | Yes        | No         | Yes      |
| production  | 12        | Yes        | Yes        | Yes      |

**Complexity requirements (production only):**
- At least one uppercase letter
- At least one lowercase letter
- At least one digit
- At least one special character

### 2. Settings Validators (`diri-cyrex/app/settings.py`)

Pydantic `field_validator` decorators on:
- `POSTGRES_PASSWORD` - validates via PasswordValidator
- `REDIS_PASSWORD` - validates via PasswordValidator, required in production
- `JWT_SECRET` - minimum 32 characters in non-dev environments

### 3. Docker Compose (`docker-compose.yml`)

Uses `${VAR:?error message}` syntax to fail fast when required variables are missing.

## Validation Rules

### Weak Password Blacklist

```
password, admin, deepiripassword, redispassword, minioadmin,
adminpassword, your_jwt_secret_key_here, your-influxdb-token,
change-me, default, 123456, postgres, root, test, dev, development,
secret, pass, qwerty, letmein, welcome,
default-secret-change-in-production
```

### Environment Detection

Reads `NODE_ENV` or `ENVIRONMENT` variable:
- `production` / `prod` → Production validation
- `staging` / `stage` → Staging validation
- Everything else → Development (no validation)

## Helper Functions

```python
from app.utils.security_validators import (
    generate_secure_password,  # 32-char password with complexity
    generate_jwt_secret,       # URL-safe base64 token
    generate_api_token,        # URL-safe base64 API token
)
```

## Testing

```bash
# Run unit tests
cd diri-cyrex
python -m pytest tests/test_security_validators.py -v

# Run integration tests
bash scripts/test_password_security.sh
```

## Files Modified

| File | Change |
|------|--------|
| `diri-cyrex/app/utils/security_validators.py` | New validation framework |
| `diri-cyrex/app/settings.py` | Pydantic field validators added |
| `diri-cyrex/app/core/authentication.py` | Removed JWT_SECRET fallback |
| `diri-cyrex/app/database/postgres.py` | Removed password fallback |
| `platform-services/shared/deepiri-synapse/app/main.py` | Removed Redis password default |
| `diri-cyrex/app/integrations/streaming/event_publisher.py` | Removed Redis password default |
| `diri-cyrex/app/integrations/lora_adapter_service.py` | Removed MinIO defaults |
| `diri-cyrex/app/integrations/model_loader.py` | Removed MinIO defaults |
| `docker-compose.yml` | Required env vars with error messages |
