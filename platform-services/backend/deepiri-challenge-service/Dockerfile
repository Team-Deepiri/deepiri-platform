# Build shared-utils first
FROM node:18-alpine AS shared-utils-builder
WORKDIR /shared-utils
COPY shared/deepiri-shared-utils/package*.json ./
COPY shared/deepiri-shared-utils/tsconfig.json ./
COPY shared/deepiri-shared-utils/src ./src
RUN npm install --legacy-peer-deps && npm run build

# Build the service
FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache curl dumb-init

# Copy package files
COPY backend/deepiri-challenge-service/package*.json ./
COPY backend/deepiri-challenge-service/tsconfig.json ./

# Copy built shared-utils to a temp location
COPY --from=shared-utils-builder /shared-utils /tmp/shared-utils

# Install shared-utils as a local file dependency first, then install other dependencies
RUN npm install --legacy-peer-deps file:/tmp/shared-utils && \
    npm install --legacy-peer-deps && \
    npm cache clean --force

# Copy source files
COPY backend/deepiri-challenge-service/src ./src

# Build TypeScript
RUN npm run build && \
    rm -rf /tmp/* /var/tmp/*

# Create non-root user and set up directories
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5007

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5007/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/server.js"]
