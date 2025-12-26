FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache curl dumb-init bash

# Create user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Give nodejs ownership of /app
RUN chown -R nodejs:nodejs /app

# Copy lockfiles with correct ownership
COPY --chown=nodejs:nodejs platform-services/backend/deepiri-ased/package*.json ./

USER nodejs

# Install dependencies (including dev dependencies for building)
RUN npm ci --legacy-peer-deps && npm cache clean --force

COPY --chown=nodejs:nodejs platform-services/backend/deepiri-ased/tsconfig.json ./
COPY --chown=nodejs:nodejs platform-services/backend/deepiri-ased/src ./src
COPY --chown=nodejs:nodejs platform-services/backend/deepiri-ased/scripts ./scripts
COPY --chown=nodejs:nodejs platform-services/backend/deepiri-ased/docker-entrypoint.sh ./docker-entrypoint.sh

# Build the application
RUN npm run build && \
    npm cache clean --force

# Make entrypoint executable
RUN chmod +x docker-entrypoint.sh

# Create data and logs directories
RUN mkdir -p /app/data /app/logs

EXPOSE 5010

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/docker-entrypoint.sh"]

