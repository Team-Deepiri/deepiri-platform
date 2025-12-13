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
# Build platform-analytics-service
# ===============================
FROM node:18-alpine
WORKDIR /app

RUN apk add --no-cache curl dumb-init

# Copy service package files (LOCK FILE INCLUDED)
COPY backend/deepiri-platform-analytics-service/package.json ./
COPY backend/deepiri-platform-analytics-service/package-lock.json ./
COPY backend/deepiri-platform-analytics-service/tsconfig.json ./

# Copy built shared-utils
COPY --from=shared-utils-builder /shared-utils /shared-utils

# SINGLE atomic install
RUN npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 300000 \
 && npm install --legacy-peer-deps file:/shared-utils \
 && npm cache clean --force

# Source
COPY backend/deepiri-platform-analytics-service/src ./src

# Build
RUN npm run build

# Runtime user
RUN addgroup -g 1001 -S nodejs \
 && adduser -S nodejs -u 1001 \
 && mkdir -p logs \
 && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5004

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5004/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/server.js"]
