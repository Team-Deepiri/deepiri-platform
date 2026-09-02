# The Deepiri cloud platform

How production is put together, why it is shaped this way, and the failure modes
that shaped it.

Written 2026-09-01, after the deploy pipeline was rebuilt end to end.

---

## What is running

One Netcup VPS 1000 G12 (`159.195.234.19`, `deepirivm`) — 4 vCPU, 7.8 GiB RAM,
251 GB disk — hosting **18 containers across three independent compose
projects**.

    platform.deepiri.com     the portal + its backends      13 containers
    boardman.deepiri.com     GitHub <-> Plaky sync agent      4 containers
    games.deepiri.com        Lyback + Voxier                 (in platform)
    deepiri-proxy            egress proxy                     1 container

At the time of writing: **0 unhealthy, 0 restarting**, load 0.33 on 4 vCPU,
2.2 GiB of 7.8 GiB used, 9% disk. Every public endpoint returns 200.

    https://platform.deepiri.com/                  200
    https://platform.deepiri.com/api/health        200
    https://boardman.deepiri.com/                  200
    https://boardman.deepiri.com/api/v1/health     200
    https://games.deepiri.com/lyback/              200
    https://games.deepiri.com/voxier/              200

Real usage, not fixtures: 22 platform users and 20 announcements, both growing.

---

## Shape

    Cloudflare (proxied, A records -> 159.195.234.19)
        |
    deepiri-nginx  :80/:443   one vhost per hostname
        |
        +-- platform.deepiri.com  -> platform-frontend, api-gateway, auth-service,
        |                            registry, jobs, external-bridge
        +-- boardman.deepiri.com  -> boardman-nginx  (separate compose project)
        +-- games.deepiri.com     -> /lyback/ -> lyback
                                     /voxier/ -> voxier (Godot 4 web export)

Data lives in `postgres-platform` and `redis`, both on named volumes. Boardman
runs its own Postgres in its own project, deliberately isolated.

### Why Boardman is a separate compose project

It shares only the docker network. It has its own Postgres, its own volumes, its
own deploy pipeline, and lives outside the platform's rsync path — so a platform
deploy cannot touch it and its deploys cannot touch the platform. That isolation
was tested repeatedly: during Boardman deploys the platform held 13 containers
and HTTP 200 across every sample, while Boardman's own container count went
0 -> 2 -> 4.

---

## Deployment

`.github/workflows/cd-cloud-portal.yml`, triggered on push to **`main` only**.

1. checkout, init the cloud submodules
2. rsync the tree to `/opt/deepiri/deepiri-platform` (`--delete`, excluding
   `.git/`, `node_modules/`, `dist/`, `DEPLOYED.txt`)
3. assemble `ops/k8s/secrets/.env` from **per-variable GitHub secrets**, and fail
   the deploy if any required value is empty
4. `docker compose pull --ignore-buildable` — refresh image-only services
5. `docker compose build --pull` — rebuild changed services from current bases
6. `docker compose up -d` — no `--force-recreate`
7. reload **or recreate** nginx, depending on a config checksum
8. write `DEPLOYED.txt`
9. verify the public domain

Steps 3 through 7 each exist because of a specific production incident.

---

## The failure mode that shaped everything

Nearly every serious bug found while building this had the same shape:

> **Something reported success while doing nothing.**

- `prisma migrate deploy || true` logged *"this may be normal"* and continued —
  a migration silently never applied, blocking every later migration for two days
- `docker compose build` reused a months-old cached base image, so a fix that
  published successfully never reached the container
- `docker compose run` reused a stale image, so a migration ran against old code
- nginx.conf is bind-mounted as a **single file**; rsync replaces files by
  rename, so the container kept a stale inode and `nginx -s reload` re-read the
  old file — every config change silently did nothing
- a service defined with `image:` and no `build:` was never refreshed by build or
  by `up`, so new images never arrived
- a health check probed `localhost`, which resolved to IPv6 while nginx bound
  IPv4 — permanently unhealthy while serving perfectly
- COOP/COEP headers set in two places arrived **twice**, combining into an
  invalid value that browsers ignore — the headers were present and useless

None of these produced an error. Every one produced a green deploy.

### What was built in response

| guard | catches |
|---|---|
| fail-loud migration gate (`migrate status` must report up to date) | migrations that silently did not apply |
| `--pull` on build | stale base images |
| `pull --ignore-buildable` | stale image-only services |
| nginx config checksum -> recreate, not reload | the single-file bind-mount inode trap |
| `DEPLOYED.txt` written only after a successful build/restart | "did this deploy actually land?" |
| empty-secret validation before writing `.env` | a missing secret rendering as an empty string |
| assert exported artefacts are non-empty before publishing | Godot exiting 0 having produced nothing |

The pattern: **assert the outcome, not the exit code.**

---

## Secrets

Runtime env is **one GitHub secret per variable**, assembled by the deploy.

It used to be a single opaque `VPS_ENV_FILE` blob. GitHub secrets are
write-only, so nobody could read back what it declared — it went stale, and two
people separately believed they had updated it when they had only edited the
live box, whose `.env` the deploy overwrites every run. Variables vanished
silently.

Now the full list lives in the workflow: reviewable in a diff, git-blame-able,
and impossible to drop one without it showing up as a code change.

Two details that matter:

- the heredoc delimiter is **quoted** (`<<'ENVEOF'`). GitHub substitutes
  `${{ secrets.X }}` before bash sees the script, so an unquoted delimiter would
  let bash expand a `$` inside a secret **value** and silently corrupt a password
- validation runs **before** the remote file is written, so a missing secret
  fails the build instead of deploying an empty value

---

## nginx conventions

**Use the resolver pattern, never a static `upstream` block.**

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
set $some_upstream http://service:80;
proxy_pass $some_upstream;
```

A static `upstream` resolves once at startup and caches the IP forever. Any
container redeploy then strands nginx on a dead address, returning 502 with a
perfectly healthy backend. This happened twice in one day, in both directions.

Three rules that follow from painful experience:

1. **`set` must come *before* `rewrite ... break`.** Both are rewrite-module
   directives and `break` halts the rest of them, so a `set` after it never runs
   and `proxy_pass` gets an empty string.
2. **With a variable, `proxy_pass` must have no URI part.** nginx cannot do
   location-prefix substitution with a variable — a URI part is used as-is and
   the rest of the path is discarded. Strip prefixes with an explicit `rewrite`.
3. **Never add a `types { }` block in a server or location.** It *replaces* the
   inherited MIME map rather than extending it. Declaring one type made nginx
   serve `index.html` as `application/octet-stream`, so browsers downloaded the
   page instead of rendering it.

### Validate config before merging

`nginx -t` inside the running container validates the *old* file, because of the
inode trap. Render the candidate config into a throwaway container instead, with
the real certs and network attached:

```bash
docker run --rm \
  -v /tmp/candidate.conf:/etc/nginx/nginx.conf:ro \
  -v deepiri-platform_certbot_conf:/etc/letsencrypt:ro \
  -v deepiri-platform_certbot_webroot:/var/www/certbot:ro \
  --network deepiri-platform_deepiri-network \
  nginx:alpine nginx -t
```

The network matters — without it the static upstreams cannot resolve and the
test fails for unrelated reasons.

**This validates syntax, not behaviour.** It passed for a config whose upstream
variable was empty at request time. Behaviour needs a real request afterwards.

---

## Games

Lyback is static, built into an image from `platform-services/games/`.

Voxier is a **Godot 4.2.2 web export**, built in CI (`deepiri-voxier`) and
published to GHCR, then pulled here. It is built in CI rather than on the box
because the export pulls ~1 GB of templates and is CPU-heavy.

Godot-specific traps, all of which cost real time:

- export templates are **version-locked** to the engine; a mismatch fails oddly
- a cold checkout has no `class_name` registry, so scripts referencing a
  `class_name` from another file fail to parse. `--import` alone does not fix it;
  `--editor --quit` builds the cache
- **COOP/COEP are load-bearing, not hardening.** Godot 4 needs
  `SharedArrayBuffer`, which requires cross-origin isolation. Without it the page
  loads to a blank canvas
- those headers must appear **exactly once**. Set in both the image and the
  vhost, they combine into an invalid value and are ignored. The vhost uses
  `proxy_hide_header` to strip the upstream copies first

---

## Resource posture

- **memory limits on every container.** Sized from measured cgroup peaks, not
  guesses. Nothing runs unbounded
- **4 GiB swapfile**, `vm.swappiness=10`. Not for routine use — it converts an
  OOM kill into recoverable slowness. There was none until recently
- **build cache pruned on the 1st and 15th**, bounded by `--max-used-space 4GB`.
  An age-based filter was tried first and reclaimed exactly 0 B, because on a
  busy day every cache entry is newer than any sensible cutoff. **Size budgets
  scale with deploy frequency; age filters do not**

---

## Honest gaps

- `pg-backup-offsite` runs, but **no restore has ever been tested**. A backup is
  only real once restored. This is the largest untested assumption here
- the Voxier `index.wasm` is **35 MB uncompressed on the wire**; no brotli/gzip
  is configured. Every first visit downloads all of it
- several older static `upstream` blocks remain for same-project services. They
  survive because compose recreates those together, but they carry the same
  latent staleness
- the build cache regrows to ~12 GB between prunes, which is expected but worth
  watching if deploy frequency rises
