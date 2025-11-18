FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache curl dumb-init

COPY package*.json ./
COPY tsconfig.json ./

RUN npm install --legacy-peer-deps && npm cache clean --force

COPY src ./src

RUN npm run build

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5007

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5007/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/server.js"]

