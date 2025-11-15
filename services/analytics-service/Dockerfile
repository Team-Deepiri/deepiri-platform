FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache curl dumb-init

COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps && npm cache clean --force

# Ensure utils directory exists (will be available via volume mount in dev)
RUN mkdir -p ./utils
COPY . .

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5004

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5004/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]

