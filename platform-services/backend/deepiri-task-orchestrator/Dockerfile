# ===============================
# Build shared-utils
# ===============================
FROM node:18-slim AS shared-utils-builder
WORKDIR /shared-utils

COPY shared/deepiri-shared-utils/package.json ./
COPY shared/deepiri-shared-utils/package-lock.json ./
COPY shared/deepiri-shared-utils/tsconfig.json ./
COPY shared/deepiri-shared-utils/src ./src

RUN npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm install --legacy-peer-deps \
 && npm run build

# ===============================
# Build task-orchestrator
# ===============================
FROM node:18-slim
WORKDIR /app

# Prisma + healthcheck deps (Debian)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      openssl \
      dumb-init \
      libc6 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Prisma binary compatibility
RUN mkdir -p /lib64 \
 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
           /lib64/ld-linux-x86-64.so.2

# Package files (LOCK FILE INCLUDED)
COPY backend/deepiri-task-orchestrator/package.json ./
COPY backend/deepiri-task-orchestrator/package-lock.json ./
COPY backend/deepiri-task-orchestrator/tsconfig.json ./

# Copy shared-utils
COPY --from=shared-utils-builder /shared-utils /shared-utils

# SINGLE atomic dependency install
RUN npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm install --legacy-peer-deps file:/shared-utils \
 && npm cache clean --force

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

# Runtime user
RUN groupadd -r -g 1001 nodejs \
 && useradd -r -u 1001 -g nodejs -m -d /home/nodejs nodejs \
 && mkdir -p logs /home/nodejs/.npm \
 && chown -R nodejs:nodejs /app /home/nodejs

USER nodejs

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5002/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
