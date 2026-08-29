# deepiri-proxy

Small, generic authenticated SOCKS5 egress proxy service (built on
[microsocks](https://github.com/rofl0r/microsocks)). Runs standalone on a VPS
so any Deepiri service can route outbound traffic through a stable IP instead
of a shared PaaS egress IP.

See [`docs/INSTALL.md`](docs/INSTALL.md) for deploy and wiring instructions.
