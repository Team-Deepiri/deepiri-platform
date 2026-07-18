# Bedd in a worker Dockerfile (Bun pattern)

```dockerfile
# --- build or pull Bedd runtime ---
FROM ghcr.io/team-deepiri/bedd:0.6 AS bedd

# --- your existing service image ---
FROM your-existing-service-base
COPY --from=bedd /usr/local/bin/bedd /usr/local/bin/bedd
COPY --from=bedd /opt/bedd/skills /opt/bedd/skills
COPY deploy/bedd/tinder.document-bus.json /etc/bedd/tinder.json
ENV BEDD_SKILLS_DIR=/opt/bedd/skills
ENV BEDD_TINDER=/etc/bedd/tinder.json
ENV BEDD_BUS_URL=http://synapse-sidecar:8081
# Only if THIS container's process is the skill worker:
# CMD ["bedd", "serve"]
```

Do not add a `deepiri-bedd` service to compose. Sugar Glider stays the bus; Bedd is a binary on PATH inside a worker that already belongs to Cyrex/Helox/LIS/platform.
