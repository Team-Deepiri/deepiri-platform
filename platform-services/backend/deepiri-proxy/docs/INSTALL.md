# Installing deepiri-proxy

A minimal authenticated HTTP forward/egress proxy (`tinyproxy`), for routing
outbound traffic from a Deepiri service through a VPS with a stable, clean IP
— instead of a shared PaaS egress IP that can pick up someone else's abuse ban.

HTTP proxy, not SOCKS5: aiohttp (what discord.py and most Deepiri Python
services run on) only supports HTTP-proxy `proxy=`/`proxy_auth=` natively —
SOCKS5 needs the extra `aiohttp-socks` dependency, which isn't worth pulling
in when a plain HTTP proxy does the job for both REST and websocket traffic.

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

Resource footprint: capped at 0.25 CPU / 32MB memory in `docker-compose.yml`
— idles near zero.

## Point a consumer service at it

Any service that needs a stable egress IP sets a `*_PROXY_URL` env var of the
form:

```
http://<user>:<pass>@<vps-ip>:8888
```

For `deepiri-norozo`, this is `DISCORD_PROXY_URL` — see that repo's
`main.py` (`_discord_proxy_kwargs`) for how it's wired into `discord.py`'s
`proxy=`/`proxy_auth=` client options.

## Security notes

- Every connection must present Basic Auth credentials (`BasicAuth` in
  `tinyproxy.conf`), since the VPS is internet-facing.
- Rotate `PROXY_USER`/`PROXY_PASS` if ever exposed (e.g. pasted in chat,
  committed by accident).
- Prefer restricting the VPS firewall to the known egress IP ranges of
  whatever PaaS is connecting, when the PaaS publishes one.
