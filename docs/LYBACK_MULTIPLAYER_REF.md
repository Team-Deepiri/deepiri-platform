# Lyback multiplayer — where the plan lives

The 4-player P2P multiplayer design is **not** in this repo. It lives with the
code it describes:

> **deepiri-lyback PR #42** — `docs/MULTIPLAYER_PLAN.md`
> https://github.com/Team-Deepiri/deepiri-lyback/pull/42

This file exists only so someone reading the platform's games plan
(`GAMES_HOSTING_PLAN.md`) can find it.

## Why it is not here

The design is about Lyback's engine and client — authority model, state sync,
determinism in `world-engine.js`. Keeping it beside that code means it moves
when the code moves, instead of drifting out of date in a repo nobody touches
while working on it.

## What the platform does own

Multiplayer needs one thing from this repo: a **signaling service**, which is a
new long-lived process and therefore a platform concern.

- a container in `docker-compose.yml`
- an nginx `location` for the WebSocket, with `Upgrade`/`Connection` headers and
  a raised `proxy_read_timeout` — idle WebSockets die at nginx's 60s default and
  present as players being randomly disconnected
- the **resolver pattern** for its upstream, not a static `upstream` block: that
  caches the container IP at startup, so redeploying the signaling container
  strands nginx on a dead address. This has already happened twice on this box
- a healthcheck, because a dead signaling server breaks matchmaking while the
  game itself still loads perfectly — nothing else would reveal it

None of that is worth building until the authority model and the TURN question
are settled, both of which are decisions in the Lyback plan.

## Also worth knowing

"P2P" does not mean serverless. Peers cannot discover each other without
signaling, and roughly 10-20% of real connections need a TURN relay to connect
at all. Both are covered in PR #42.
