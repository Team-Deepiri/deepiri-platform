# Build shared-utils first
FROM node:18-slim AS shared-utils-builder
WORKDIR /shared-utils
COPY shared/deepiri-shared-utils/package*.json ./
COPY shared/deepiri-shared-utils/tsconfig.json ./
COPY shared/deepiri-shared-utils/src ./src
# Add retry logic for network issues
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    npm install --legacy-peer-deps || \
    (sleep 10 && npm install --legacy-peer-deps) || \
    (sleep 20 && npm install --legacy-peer-deps) && \
    npm run build

# Build the service
FROM node:18-slim

WORKDIR /app

# Install dependencies for Prisma and health checks
# Ensure libc6 and dynamic linker are available for Prisma debian binary
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates openssl dumb-init libc6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create /lib64 symlink for Prisma binary compatibility (must be done as root)
RUN mkdir -p /lib64 && \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Copy package files
COPY backend/deepiri-task-orchestrator/package*.json ./
COPY backend/deepiri-task-orchestrator/tsconfig.json ./

# Copy built shared-utils to a temp location
COPY --from=shared-utils-builder /shared-utils /tmp/shared-utils

# Install shared-utils as a local file dependency first, then install other dependencies
# Add retry logic for network issues
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    npm install --legacy-peer-deps file:/tmp/shared-utils || \
    (sleep 10 && npm install --legacy-peer-deps file:/tmp/shared-utils) || \
    (sleep 20 && npm install --legacy-peer-deps file:/tmp/shared-utils) && \
    npm install --legacy-peer-deps || \
    (sleep 10 && npm install --legacy-peer-deps) || \
    (sleep 20 && npm install --legacy-peer-deps) && \
    npm cache clean --force

# Copy source files
COPY backend/deepiri-task-orchestrator/src ./src
COPY backend/deepiri-task-orchestrator/prisma ./prisma

# Regenerate Prisma client for Debian (not musl)
# Copy debian binary over musl binary after generation
# Note: TypeScript build is skipped - dev mode uses ts-node-dev
RUN npx prisma generate && \
    cd node_modules/.prisma/client && \
    if [ -f libquery_engine-debian-openssl-3.0.x.so.node ]; then \
        cp libquery_engine-debian-openssl-3.0.x.so.node libquery_engine-linux-musl.so.node; \
    fi && \
    cd /app && \
    rm -rf /tmp/* /var/tmp/*

# Create non-root user and set up directories
RUN groupadd -r -g 1001 nodejs && \
    useradd -r -u 1001 -g nodejs -m -d /home/nodejs nodejs && \
    mkdir -p logs /home/nodejs/.npm && \
    chown -R nodejs:nodejs /app /home/nodejs

USER nodejs

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5002/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
