# Team service catalogs

| Repo | Compose | Catalog |
|------|---------|---------|
| **deepiri-platform** (this repo, cloud VPS) | `docker-compose.yml` | [`cloud-portal.yml`](cloud-portal.yml) |
| **deepiri-control-plane** (local/lab full stack) | `docker-compose.dev.yml` | [`all-services.yml`](https://github.com/Team-Deepiri/deepiri-control-plane/blob/main/teams/all-services.yml) |

Full dev onboarding (`setup-deepiri-dev.sh`, speech engine, Cyrex, LIS): **deepiri-control-plane** only.

The YAML files in this folder (except `cloud-portal.yml`) are kept for reference during the repo split; they apply to **deepiri-control-plane**, not this cloud repo.
