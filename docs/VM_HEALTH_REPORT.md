# Cloud VM health report

Host: `159.195.234.19` (`deepirivm`) — Netcup VPS 1000 G12
Captured: 2026-08-31 07:28 UTC, after the night's deploys and the Boardman rollout.

**Verdict: healthy, with two things worth acting on before they bite.**

---

## Summary

| area | status | headline |
|---|---|---|
| Compute | healthy | load 0.15 on 4 vCPU |
| Memory | healthy | 5.8 GiB of 7.8 GiB available |
| Disk | healthy | 18 GB of 251 GB used (8%) |
| Services | healthy | 17 containers, 0 unhealthy, 0 restarting |
| **Swap** | **needs attention** | none configured |
| **Docker build cache** | **needs attention** | 12.93 GB, and growing every deploy |

---

## Compute

    uptime: 3 days, 9:41
    load average: 0.15, 0.22, 0.21
    cpus: 4

Load is ~4% of capacity across all three windows. The box is not close to CPU
pressure, even with 17 containers and Boardman's worker polling every 250ms.

This is why the Voxier Godot export belongs in CI, not here — a headless export
is genuinely CPU-heavy and would compete with production for minutes at a time.

## Memory

                   total   used   free   buff/cache   available
    Mem:           7.8Gi   2.0Gi  577Mi      5.6Gi        5.8Gi
    Swap:             0B      0B     0B

2.0 GiB genuinely in use. The 5.6 GiB in buff/cache is reclaimable, so 5.8 GiB
is really available. Comfortable.

Per-container, nothing is near its cap:

    deepiri-boardman           187.7 MiB   (no limit set)
    deepiri-boardman-worker    100.5 MiB   (no limit set)
    deepiri-auth-service        79.0 MiB / 512 MiB   15%
    deepiri-external-bridge     45.9 MiB / 384 MiB   12%
    deepiri-api-gateway         44.1 MiB / 768 MiB    6%
    deepiri-registry            36.6 MiB / 384 MiB   10%
    deepiri-jobs                35.4 MiB / 384 MiB    9%
    deepiri-postgres-platform   30.9 MiB / 1.5 GiB    2%
    deepiri-redis                8.7 MiB / 384 MiB    2%

### ⚠️ No swap is configured

With zero swap, a memory spike has no cushion — the kernel OOM-killer picks a
process and kills it outright rather than degrading. On a box running Postgres
and 17 services, that means an abrupt, hard-to-attribute container death.

There is 223 GB free. A 2–4 GB swapfile costs nothing and converts a hard kill
into a slow patch you can notice and react to.

Not urgent at 2.0 GiB of 7.8 GiB. Worth doing before adding more services —
and Voxier plus a Lyback signaling server are both queued.

## Disk

    /dev/vda4   251G   18G   223G   8%
    inodes:     16.5M used 755k (5%)

Plenty of both space and inodes.

### ⚠️ Docker build cache is 12.93 GB

    Images         19    7.769 GB    (24 MB reclaimable)
    Containers     18   48.12 MB
    Local Volumes   8   116.9 MB
    Build Cache   285   12.93 GB     (8.647 GB reclaimable)

The build cache is now **larger than every image combined**, and it grows on
every deploy. Since CD builds on the box, this is monotonic — nothing prunes it.

At 8% disk usage this is not yet a problem. It becomes one silently: a full disk
on this box takes down Postgres, nginx and every service at once, and the
symptom looks like a general outage rather than a storage issue.

Two options:

1. `docker builder prune -f --filter until=168h` on a weekly timer — keeps a
   week of cache for build speed, discards the rest.
2. Add the same prune as a final CD step, so it self-limits per deploy.

Recommend (1). Pruning inside CD makes deploys slower and occasionally
surprising; a weekly timer is boring and predictable.

Note this interacts with the recent `--pull` change: pulling fresh base images
each deploy is correct, but it does add cache layers faster than before.

## Services

17 containers running, **0 unhealthy, 0 restarting, 0 failed**.

    platform  13   api-gateway, auth-service, certbot, external-bridge,
                   jobs, lyback, nginx, pg-backup-offsite, platform-frontend,
                   postgres-platform, proxy, redis, registry
    boardman   4   boardman, boardman-worker, boardman-postgres, boardman-ui

Endpoints verified from the box and externally:

    https://platform.deepiri.com/               200
    https://platform.deepiri.com/api/health     200
    https://boardman.deepiri.com/               200
    https://boardman.deepiri.com/api/v1/health  200
    https://games.deepiri.com/                  200

Data: 19 platform users, 17 announcements — both growing under real use.

---

## Recommended actions

| priority | action | why |
|---|---|---|
| Medium | add a 2–4 GB swapfile | turns an OOM kill into recoverable slowness |
| Medium | weekly `docker builder prune` | 12.93 GB and monotonically growing |
| Low | set memory limits on the 4 Boardman containers | the other 13 have them; these do not |
| Low | verify `pg-backup-offsite` restores | it runs, but a backup is only real once restored |

Neither medium item is urgent today. Both are the kind of thing that is trivial
now and an incident later, and the box is about to gain services rather than
lose them.

---

## Method

All figures read directly from the host: `uptime`, `free -h`, `df -h`, `df -i`,
`docker system df`, `docker stats --no-stream`, `docker ps`, plus HTTP checks
against the public hostnames. No estimates.
