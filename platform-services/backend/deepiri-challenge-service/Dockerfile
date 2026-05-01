# Build the service
FROM ghcr.io/team-deepiri/deepiri-base:18-alpine

COPY shared/deepiri-shared-utils/package*.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
# Copy package files
COPY backend/deepiri-challenge-service/package*.json ./
COPY backend/deepiri-challenge-service/tsconfig.json ./

# Install dependencies, including shared-utils from the local submodule
# Add retry logic for network issues
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm config set fetch-timeout 300000 && \
    cd /shared/deepiri-shared-utils && npm install --legacy-peer-deps && npm run build && \
    cd /app && npm install --legacy-peer-deps && \
    npm cache clean --force

# Copy source files
COPY backend/deepiri-challenge-service/src ./src

# Build TypeScript
RUN npm run build && \
    rm -rf /tmp/* /var/tmp/*

RUN mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5007

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5007/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
