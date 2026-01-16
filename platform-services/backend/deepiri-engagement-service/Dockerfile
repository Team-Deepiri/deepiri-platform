# ===============================
# Build shared-utils
# ===============================
FROM node:18-alpine AS shared-utils-builder
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
# Build engagement-service
# ===============================
FROM node:18-alpine
WORKDIR /app

RUN apk add --no-cache curl dumb-init openssl bash

# Copy K8s env loader scripts
COPY --chown=root:root shared/scripts/load-k8s-env.sh /usr/local/bin/load-k8s-env.sh
COPY --chown=root:root shared/scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh

# Copy service package files (LOCK FILE INCLUDED)
COPY backend/deepiri-engagement-service/package.json ./
COPY backend/deepiri-engagement-service/package-lock.json ./
COPY backend/deepiri-engagement-service/tsconfig.json ./

# Copy built shared-utils
COPY --from=shared-utils-builder /shared-utils /shared-utils

# SINGLE atomic install (this is the critical fix)
RUN npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm install --legacy-peer-deps file:/shared-utils \
 && npm cache clean --force

# Prisma schema (needed for generate during build)
COPY backend/deepiri-engagement-service/prisma ./prisma

# Source
COPY backend/deepiri-engagement-service/src ./src

# Build (includes prisma generate)
RUN npm run build

# Runtime user
RUN addgroup -g 1001 -S nodejs \
 && adduser -S nodejs -u 1001 \
 && mkdir -p logs \
 && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5003

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5003/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
