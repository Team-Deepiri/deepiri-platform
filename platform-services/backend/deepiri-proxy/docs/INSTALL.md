# Installing deepiri-proxy

A minimal authenticated SOCKS5 egress proxy (`microsocks`), for routing outbound
traffic from a Deepiri service through a VPS with a stable, clean IP — instead
of a shared PaaS egress IP that can pick up someone else's abuse ban.

First use case: Discord gateway/REST traffic from `deepiri-norozo` after
Render's shared egress IP got Cloudflare-1015-banned by discord.com.

## Deploy on the VPS

This service lives at `platform-services/backend/deepiri-proxy` in
`deepiri-platform`, but it runs standalone on its own VPS — it is not part of
the platform's local dev `docker-compose.yml`.

```sh
git clone git@github.com:Team-Deepiri/deepiri-platform.git
cd deepiri-platform/platform-services/backend/deepiri-proxy
cp .env.example .env
# edit .env: set a strong PROXY_USER / PROXY_PASS
docker compose up -d --build
```

Resource footprint: single static binary, no runtime deps, capped at
0.25 CPU / 32MB memory in `docker-compose.yml` — idles near zero.

## Point a consumer service at it

Any service that needs a stable egress IP sets a `*_PROXY_URL` env var of the
form:

```
socks5://<user>:<pass>@<vps-ip>:1080
```

For `deepiri-norozo`, this is `DISCORD_PROXY_URL` — see that repo's README
for how it's wired into `discord.py`'s `proxy=` client option.

## Security notes

- No `-1` (auth-once/whitelist) mode — every connection must present
  credentials, since the VPS is internet-facing.
- Rotate `PROXY_USER`/`PROXY_PASS` if ever exposed (e.g. pasted in chat,
  committed by accident).
- Prefer restricting the VPS firewall to the known egress IP ranges of
  whatever PaaS is connecting, when the PaaS publishes one.
