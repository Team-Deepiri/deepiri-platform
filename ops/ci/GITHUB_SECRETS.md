# GitHub Actions secrets for `deepiri-platform` CI

Repository: **Team-Deepiri/deepiri-platform** → Settings → Secrets and variables → Actions.

## Required for CI (submodule + Docker builds)

| Secret | Purpose | How to obtain |
|--------|---------|---------------|
| `PLATFORM_ACCESS_TOKEN` | Clone private Team-Deepiri submodules over HTTPS in CI | **Preferred:** PAT from `secrets.7z` (Discord). Or create a fine-grained PAT at [github.com/settings/tokens](https://github.com/settings/tokens) with **read** access to all submodule repos in the org. `GITHUB_TOKEN` alone cannot read other private repos. |

`GITHUB_TOKEN` is provided automatically by Actions (used for `ghcr.io` login to pull `deepiri-suite` base images). No manual setup.

## Not required for CI (dummy values used in workflow)

These appear in `docker-compose.dev.yml` without defaults. CI sets safe placeholders via workflow `env` so `docker compose config` and builds do not warn/fail. **Do not add these to GitHub unless you need them for deploy workflows.**

| Variable | Used by | Real value source |
|----------|---------|-------------------|
| `GOOGLE_CLIENT_ID` | auth-service, external-bridge | `secrets.7z` or Google Cloud Console OAuth client — **consult Josep** (tied to org Google project) |
| `GOOGLE_CLIENT_SECRET` | external-bridge | Same as above — **consult Josep** |
| `AUTH_SERVICE_URL` | external-bridge | Compose default locally; set per environment in k8s configmaps |
| `EXTERNAL_BRIDGE_BASE_URL` | external-bridge | Environment-specific URL |
| `OPENAI_API_KEY` | cyrex | `secrets.7z` or OpenAI dashboard — **consult Josep** if using org billing |
| `WANDB_API_KEY` | cyrex | Weights & Biases account — optional for ML |
| `PINECONE_API_KEY` | cyrex | Pinecone console — optional |
| `WEAVIATE_URL` | cyrex | Self-hosted or cloud Weaviate URL — optional |
| `INFLUXDB_TOKEN` | cyrex, telemetry | Generate via InfluxDB UI or use value from `secrets.7z` |

## Local dev secrets (not GitHub)

Per-service runtime secrets live in **gitignored** `ops/k8s/secrets/<service>-secret.yaml`. Bootstrap locally from `secrets.7z` (Discord) or generate shared keys:

```bash
openssl rand -base64 32   # JWT_SECRET, INTERNAL_SERVICE_SECRET
```

Shared keys (`JWT_SECRET`, `INTERNAL_SERVICE_SECRET`, `REDIS_PASSWORD`, `INFLUXDB_TOKEN`) are duplicated per service file by design.

## `secrets.7z` (Discord)

Team bundle — extract and map values into:

1. **GitHub:** `PLATFORM_ACCESS_TOKEN` (minimum for CI)
2. **Local:** `ops/k8s/secrets/*-secret.yaml` for full stack dev
3. **Consult Josep** for OAuth/OpenAI keys tied to personal/org accounts

## Manual CI full build

Actions → **Platform Build and Test** → **Run workflow** → enable **full_build** to build all 13 platform services (ignores path-based detection).
