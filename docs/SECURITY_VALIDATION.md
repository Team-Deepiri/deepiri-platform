# Secrets Validation Framework

Environment-aware secrets validation for both Python (diri-cyrex) and TypeScript (Node.js services).

## Overview

All secrets are validated at startup based on the current environment:

| Environment | Validation Level | Details |
|-------------|-----------------|---------|
| development | None | Any value accepted for convenience |
| staging | Basic | 12+ chars, no weak passwords |
| production | Strict | 12+ chars, complexity required, no weak passwords |

Environment is detected from `NODE_ENV` or `ENVIRONMENT` variable.

---

## Python (diri-cyrex)

### Validated Secrets

| Secret | Validator | Required |
|--------|-----------|----------|
| `POSTGRES_PASSWORD` | PasswordValidator | Yes |
| `REDIS_PASSWORD` | PasswordValidator | Prod only |
| `JWT_SECRET` | PasswordValidator (32+ chars) | Yes |
| `MINIO_ROOT_USER` | Rejects "minioadmin" in prod | Yes |
| `MINIO_ROOT_PASSWORD` | PasswordValidator | Yes |
| `S3_ENDPOINT_URL` | UrlValidator | Yes |
| `OPENAI_API_KEY` | ApiKeyValidator (20+ chars) | No |
| `CYREX_API_KEY` | ApiKeyValidator (20+ chars) | No |
| `LANGCHAIN_API_KEY` | ApiKeyValidator (20+ chars) | No |

### Validator Classes

Located in `diri-cyrex/app/utils/security_validators.py`:

- **PasswordValidator** - Password strength with complexity requirements
- **ApiKeyValidator** - API key format and minimum length (20 chars)
- **MinioCredentialValidator** - MinIO username/password pairs
- **UrlValidator** - URL format with optional HTTPS enforcement

### Usage

Settings are validated automatically on import via Pydantic `field_validator`:

```python
from app.settings import settings

# Accessing settings triggers validation at import time
print(settings.POSTGRES_PASSWORD)
```

### Adding New Secrets

1. Add the field to `Settings` class in `diri-cyrex/app/settings.py`
2. Add a `@field_validator` decorator using the appropriate validator
3. Add tests to `tests/test_security_validators_extended.py`

---

## TypeScript (Node.js Services)

### Package

`@deepiri/shared-utils` - `src/config/`

### Validator Classes

- **PasswordValidator** - Password strength with complexity
- **ApiKeyValidator** - API key format (20+ chars)
- **TokenValidator** - JWT secrets (32+ chars) and tokens (48+ chars)
- **UrlValidator** - URL format with optional HTTPS enforcement
- **SecretValidator** - Coordinates all validators, batch validation

### Quick Start

```typescript
import { createSecretValidator } from '@deepiri/shared-utils';

const validator = createSecretValidator();

// Validate individual secrets
validator.validatePassword(process.env.REDIS_PASSWORD!, 'REDIS_PASSWORD');
validator.validateJwt(process.env.JWT_SECRET!, 'JWT_SECRET');
validator.validateApiKey(process.env.OPENAI_API_KEY || null, 'OPENAI_API_KEY');

// Batch validation
const result = validator.validateAll({
  POSTGRES_PASSWORD: process.env.POSTGRES_PASSWORD,
  JWT_SECRET: process.env.JWT_SECRET,
  CYREX_API_KEY: process.env.CYREX_API_KEY,
});

if (!result.valid) {
  console.error('Secret validation failed:', result.errors);
  process.exit(1);
}
```

### Adding New Secrets

1. Add the field to `SecretConfig` interface in `src/config/types.ts`
2. Add the field name to the appropriate array in `SecretValidator.ts` (PASSWORD_FIELDS, API_KEY_FIELDS, etc.)
3. Add tests

---

## Generating Secure Secrets

```bash
# Password (32 chars, base64)
openssl rand -base64 32

# JWT secret (48 chars, URL-safe)
openssl rand -base64 48

# API token (URL-safe)
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Using Python validators module
python -c "from app.utils.security_validators import generate_secure_password; print(generate_secure_password())"
```

---

## Weak Password Blacklist

These values are rejected in staging and production:

`password`, `admin`, `deepiripassword`, `redispassword`, `minioadmin`, `adminpassword`, `change-me`, `default`, `postgres`, `root`, `test`, `dev`, `development`, `secret`, `pass`, `qwerty`, `letmein`, `welcome`, `123456`, `default-secret-change-in-production`

---

## Troubleshooting

### "Password is required in production environment"
Set the environment variable with a strong password: `openssl rand -base64 32`

### "known weak password"
Replace the default/placeholder password with a generated one.

### "must be at least N characters"
Use a longer secret. Generate with `openssl rand -base64 32`.

### "HTTPS is required in production"
Update your URL to use `https://` instead of `http://`.

### Validation passes locally but fails in CI/staging
Check that `NODE_ENV` or `ENVIRONMENT` is set correctly. Development mode skips validation.

---

## Testing

```bash
# Python unit tests
cd diri-cyrex
python -m pytest tests/test_security_validators.py tests/test_security_validators_extended.py -v

# Python integration tests
bash scripts/test_password_security.sh

# TypeScript tests
cd platform-services/shared/deepiri-shared-utils
npm test
```
