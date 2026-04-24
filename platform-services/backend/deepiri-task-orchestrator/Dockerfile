FROM ghcr.io/team-deepiri/deepiri-base:18-slim

# Prisma binary compatibility (service-specific)
RUN mkdir -p /lib64 \
 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
           /lib64/ld-linux-x86-64.so.2

# Package files
COPY backend/deepiri-task-orchestrator/package*.json ./
COPY backend/deepiri-task-orchestrator/tsconfig.json ./

# SINGLE atomic dependency install
RUN --mount=type=secret,id=github_token \
    { echo "@team-deepiri:registry=https://npm.pkg.github.com"; \
      echo "//npm.pkg.github.com/:_authToken=$(cat /run/secrets/github_token)"; \
    } > .npmrc \
 && npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm install --legacy-peer-deps \
 && npm cache clean --force \
 && echo "@team-deepiri:registry=https://npm.pkg.github.com" > .npmrc

# Source + Prisma schema
COPY backend/deepiri-task-orchestrator/src ./src
COPY backend/deepiri-task-orchestrator/prisma ./prisma

# Prisma generate + TypeScript build
RUN npx prisma generate \
 && npm run build \
 && cd node_modules/.prisma/client \
 && if [ -f libquery_engine-debian-openssl-3.0.x.so.node ]; then \
      cp libquery_engine-debian-openssl-3.0.x.so.node \
         libquery_engine-linux-musl.so.node; \
    fi \
 && cd /app

RUN mkdir -p logs /home/nodejs/.npm \
 && chown -R nodejs:nodejs /app /home/nodejs

USER nodejs

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5002/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["dumb-init", "--", "node", "dist/server.js"]
