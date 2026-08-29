# deepiri-proxy

Runs standalone on a VPS (not part of this compose stack) so any service can
route outbound traffic through a stable, non-shared IP instead of a PaaS's
shared egress IP.

Code and deploy instructions live in **deepiri-proxy**
(`install.sh`... see `docs/INSTALL.md`).

See: https://github.com/Team-Deepiri/deepiri-proxy/blob/main/docs/INSTALL.md

First consumer: `deepiri-norozo` (Discord bot) routes Discord gateway/REST
traffic through it after Render's shared egress IP was Cloudflare-1015-banned
by discord.com. Point any future consumer at it with a `*_PROXY_URL` env var:
`socks5://<user>:<pass>@<vps-ip>:1080`.
