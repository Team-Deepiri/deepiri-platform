# deepiri-plaky-bridge

Headless Plaky bridge — invite/kick automation. Runs 100% in the background (no GUI).

Plaky's public API (`https://api.plaky.com/v1/public`, `X-API-Key`) has **no invite endpoint**, so
member invite/kick is driven through Playwright against the web UI. Login codes are retrieved
headlessly over IMAP.

## Layout

    src/server.ts             Express entrypoint (PORT, default 5009)
    src/bridge.ts             Playwright automation + Plaky API calls
    src/emailCodeProvider.ts  IMAP login-code retrieval
    Dockerfile                based on mcr.microsoft.com/playwright:v1.46.0-jammy
    scratch/                  iteration scripts kept for reference; NOT part of the build

## Environment

    PORT                     default 5009
    PLAKY_API_BASE           https://api.plaky.com/v1/public
    PLAKY_API_KEY            public API key (X-API-Key)
    PLAKY_API_TOKEN
    PLAKY_EMAIL              bridge account used for UI automation
    PLAKY_PASSWORD
    PLAKY_BOT_EMAIL
    PLAKY_BRIDGE_SECRET      shared secret for callers of this service
    PLAKY_BRIDGE_DATA_DIR    session persistence (default /app/data)
    INTERNAL_SERVICE_SECRET
    IMAP_HOST / IMAP_PORT / IMAP_USER / IMAP_PASS   login-code mailbox

All values come from the environment; nothing is hardcoded.

## Status

Not yet wired into `docker-compose.yml` — committing the source first so it stops living only in
an untracked working directory. Consumed by deepiri-norozo's `/plaky-invite`, `/plaky-kick` and
`/plaky-bridge-status` commands (see `plaky_bridge.py` there).
