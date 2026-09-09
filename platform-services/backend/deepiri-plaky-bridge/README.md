# deepiri-plaky-bridge

Headless Plaky bridge — invite/kick/deactivate automation. Runs 100% in the background (no GUI).

Plaky's public API (`https://api.plaky.com/v1/public`, `X-API-Key`) has **no invite endpoint**, so
member invite uses Cake Account's members API (`/api/organizations/{org}/workspaces/invitations/...`),
which is captcha-free when driven with the org's SSO session cookie. Kicks/deactivations go through
the web API (`PATCH /users/{id}/deactivate`) with the same SSO Bearer. Login codes are retrieved
headlessly over IMAP.

## Layout

    src/server.ts             Express entrypoint (PORT, default 5009)
    src/bridge.ts             Playwright automation + Plaky/Cake API calls
    src/emailCodeProvider.ts  IMAP login-code retrieval
    Dockerfile                based on mcr.microsoft.com/playwright:v1.46.0-jammy

## Environment

    PORT                     default 5009
    PLAKY_API_BASE           https://api.plaky.com/v1/public
    PLAKY_API_KEY            public API key (X-API-Key)
    PLAKY_API_TOKEN          alias for PLAKY_API_KEY
    PLAKY_EMAIL              bridge account used for UI automation
    PLAKY_PASSWORD
    PLAKY_BOT_EMAIL
    PLAKY_BRIDGE_SECRET      shared secret for callers of this service
    PLAKY_BRIDGE_DATA_DIR    session persistence (default /app/data)
    INTERNAL_SERVICE_SECRET  accepted as x-internal-secret / x-api-key header
    IMAP_HOST / IMAP_PORT / IMAP_USER / IMAP_PASS   login-code mailbox
    CAKE_API_BASE            https://account.cake.com/api
    CAKE_ORGANIZATION_ID     defaults to the Deepiri org id in bridge.ts
    CAKE_WORKSPACE_IDS       comma-separated; defaults to the Deepiri workspace

All values come from the environment; nothing is hardcoded.

## Status

Wired into `docker-compose.yml` and deployed on the cloud portal (`platform.deepiri.com`).
Public path: `https://platform.deepiri.com/api/plaky/{plaky/invite,plaky/kick,plaky/invite-batch,plaky/kick-batch}`
plus `/api/plaky/health` for liveness. nginx proxies these to the bridge container (port 5009); the
bridge enforces `x-internal-secret` on invite/kick routes. Without `PLAKY_EMAIL`/`PLAKY_PASSWORD` the
service boots read-only (`isReady=true`) and invite/kick return instructive errors instead of crashing.

Consumed by deepiri-norozo's `/plaky-invite` and `/plaky-kick` commands (see `plaky_invite.py` there).