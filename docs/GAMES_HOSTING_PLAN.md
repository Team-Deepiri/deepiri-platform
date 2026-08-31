# Games hosting plan — Voxier + Lyback

Target: serve both games under `games.deepiri.com`, and add 4-player P2P
multiplayer to Lyback.

    https://games.deepiri.com/voxier   <- new
    https://games.deepiri.com/lyback   <- move from /

Status of this document: plan only. Nothing here is deployed yet except the
existing Lyback container.

---

## 0. Blocker that affects both — games.deepiri.com has no DNS

`games.deepiri.com` does not resolve. Verified:

    getent hosts games.deepiri.com   -> nothing
    curl https://games.deepiri.com/  -> 000 (connection failed)

The nginx vhost has existed for a while and Lyback has been running for 14
hours, so **Lyback is deployed but has never been publicly reachable.**

Fix, same pattern as boardman.deepiri.com:

    Type: A   Name: games   Content: 159.195.234.19   Proxy: Proxied   TTL: Auto

Cert caveat: the vhost reuses `/etc/letsencrypt/live/current/`. If Cloudflare's
SSL mode is **Full (strict)** and that cert does not cover `games.deepiri.com`,
this returns 526 with nginx perfectly healthy. Either expand the cert or confirm
the mode before declaring it broken.

Neither game is publicly reachable until this record exists. Everything below
is blocked on it.

---

## 1. Voxier — the hard part is that no web build exists

Voxier is a **Godot 4.2.2 project** (`.godot-version` = 4.2.2.stable, ~45MB
repo, GDScript). It is not a web app that can be containerised as-is.

`Voxier/export_presets.cfg` defines exactly three presets:

| preset | platform |
|---|---|
| 0 | Linux |
| 1 | Windows Desktop |
| 2 | macOS |

**There is no Web/HTML5 preset.** So there is nothing to deploy today — a web
build has to be produced first.

### 1.1 Work required

1. **Add a Web export preset** to `export_presets.cfg`, exporting to
   `build/web/index.html`.
2. **Build it.** Godot 4.2.2 headless plus the matching **export templates**
   (`Godot_v4.2.2-stable_export_templates.tpz`). The template version must match
   the engine version exactly or the export fails.

       godot --headless --export-release "Web" build/web/index.html

3. **Serve the output as static files.** A Godot web export is `index.html` +
   `.wasm` + `.pck` + `.js`. No runtime, no container of its own — it can be
   served by the existing games nginx.

### 1.2 The non-obvious blocker: COOP/COEP

Godot 4 web exports use **SharedArrayBuffer**, which browsers only expose in a
cross-origin-isolated context. The server must send:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

Without both, the page loads and the engine **fails to start** — typically a
blank canvas with a SharedArrayBuffer error in the console, which reads like a
broken build rather than a missing header.

Two consequences worth deciding up front:

- `require-corp` applies to **every subresource** on that document. Anything
  cross-origin (a CDN font, an external analytics script) must send
  `Cross-Origin-Resource-Policy: cross-origin` or it will be blocked.
- Scope the headers to `location /voxier/` only. Applying them at the server
  level would impose isolation on Lyback too, which does not need it and may
  break if it loads anything cross-origin.

### 1.3 Where to build

Preferred: **GitHub Actions**, not on the VPS.

The box has 4 vCPU and is running 17 containers. A Godot export pulls ~1GB of
templates and is CPU-heavy; doing it on the VPS competes with production. Build
in CI, publish the exported `build/web/` as an artifact or a container image,
and have the deploy pull it — the same shape as every other service here.

Repo size is also a factor: 45MB of source, and the export adds a `.pck` that
may be tens of MB. Worth measuring before choosing between baking it into an
image and rsyncing it.

---

## 2. Lyback — already deployed, needs to move to a subpath

Lyback is JavaScript, already built into `deepiri-lyback:prod`, and already
running (`nginx -g daemon off`). It is currently served at `/` on
`games.deepiri.com`.

Work: move it to `/lyback/` and add `/voxier/` alongside.

    location /lyback/ { ... existing lyback backend ... }
    location /voxier/ { ... static Godot export, plus COOP/COEP ... }
    location = /      { return 302 /lyback/; }   # or a small landing page

Two things to check when moving a static app to a subpath:

- **Asset paths.** If the app references `/assets/...` absolutely, everything
  404s under `/lyback/`. Either make paths relative or set a base href. This is
  the most common way a subpath move breaks.
- **Client-side routing**, if any: the SPA fallback must point at
  `/lyback/index.html`, not `/index.html`.

---

## 3. Lyback multiplayer — 4 players, P2P

Requirement: up to 4 players, peer-to-peer.

### 3.1 "P2P" still needs a server

WebRTC is peer-to-peer for **media and data**, but peers cannot find each other
unaided. Three server-side pieces are needed regardless:

1. **Signaling** — a small WebSocket service to exchange SDP offers/answers and
   ICE candidates, and to manage rooms. Peers cannot connect without it.
   Traffic is tiny; it only runs during connection setup.
2. **STUN** — for public address discovery. Google's public STUN is free and
   adequate.
3. **TURN** — a relay for peers that cannot connect directly. In practice
   **10-20% of connections need TURN** (symmetric NAT, restrictive corporate
   networks). Without it those players simply cannot join, and it will look like
   an intermittent bug rather than a NAT problem.

TURN relays actual game traffic, so it costs bandwidth. Decide deliberately:
ship without it and accept a minority of players failing to connect, or run
coturn and pay for the relay.

### 3.2 Topology — full mesh

With a 4-player cap, **full mesh** is the right choice: each peer connects to
every other, 6 connections total, no relay hop, lowest latency.

Mesh scales as n(n-1)/2, so this only stays reasonable because of the 4-player
cap. If the cap ever rises, this becomes host-authoritative or a relay.

### 3.3 Authority and cheating

P2P has no server referee. Decide which:

- **Host-authoritative** — one peer owns game state. Simple, but that player can
  cheat, and their disconnect ends or stalls the session unless host migration
  is implemented.
- **Shared/deterministic (lockstep)** — no single owner, but needs deterministic
  simulation and desync handling. More work.

For a casual 4-player arcade game, host-authoritative is almost certainly right.
Just make the trade explicit rather than discovering it later.

### 3.4 Deployment shape

The signaling service is a new long-lived process:

- its own container in the platform compose (or Lyback's own compose)
- an nginx `location /lyback/ws` with `Upgrade`/`Connection` headers for the
  WebSocket, plus a longer `proxy_read_timeout` — idle WebSockets die at the
  default 60s
- health check, so a dead signaling server fails a deploy rather than silently
  breaking matchmaking

---

## 4. Suggested order

1. **DNS for `games.deepiri.com`** — blocks everything, costs one record.
2. **Voxier web export preset + CI build** — the long pole; nothing to deploy
   until it exists.
3. **Serve Voxier at `/voxier/`** with COOP/COEP scoped to that location.
4. **Move Lyback to `/lyback/`**, checking asset paths.
5. **Lyback multiplayer** — signaling service, then mesh, then TURN decision.

Steps 1-4 are mechanical. Step 5 is a feature with real design decisions in it
(authority model, TURN cost, host migration) and should not be bundled with the
hosting work.

---

## 5. Notes carried from tonight's incidents

Directly relevant to this work:

- **nginx config is bind-mounted as a single file.** rsync replaces it by
  rename, so the container keeps a stale inode and `nginx -s reload` re-reads the
  old file. The deploy now checksums and recreates nginx when it differs — but
  anyone editing that config by hand must recreate the container, not reload it.
- **Use the resolver pattern for any new upstream.** A static `upstream` block
  caches its IP at startup; a signaling container redeploying will strand nginx
  on a dead address. Use `resolver 127.0.0.11` with the address in a variable.
- **Verify config before merging**, by rendering it into a throwaway
  `nginx:alpine` with the real certs and network attached. A bad config here
  takes down the entire front door.
