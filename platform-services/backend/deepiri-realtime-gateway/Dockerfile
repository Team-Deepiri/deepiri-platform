# Build the service
FROM ghcr.io/team-deepiri/deepiri-base:18-alpine

# Copy package file. This service has no usable lockfile in the current branch.
COPY backend/deepiri-realtime-gateway/package.json ./

# SINGLE install step (this is the fix)
RUN --mount=type=secret,id=github_token \
    { echo "@team-deepiri:registry=https://npm.pkg.github.com"; \
      echo "//npm.pkg.github.com/:_authToken=$(cat /run/secrets/github_token)"; \
    } > .npmrc \
 && npm install --legacy-peer-deps \
 && npm cache clean --force \
 && echo "@team-deepiri:registry=https://npm.pkg.github.com" > .npmrc

# Copy source files
COPY backend/deepiri-realtime-gateway/tsconfig.json ./
COPY backend/deepiri-realtime-gateway/src ./src

# Build TypeScript
RUN npm run build

RUN mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5008

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5008/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
