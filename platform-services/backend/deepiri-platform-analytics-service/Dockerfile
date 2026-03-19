FROM node:18-alpine AS shared-utils-builder
WORKDIR /shared-utils
COPY platform-services/shared/deepiri-shared-utils/package.json ./
COPY platform-services/shared/deepiri-shared-utils/tsconfig.json ./
COPY platform-services/shared/deepiri-shared-utils/src ./src
RUN npm install --legacy-peer-deps && npm run build

# ===============================
# Build platform-analytics-service
# ===============================
FROM node:18-alpine
WORKDIR /app

RUN apk add --no-cache curl dumb-init bash

COPY --chown=root:root platform-services/shared/scripts/load-k8s-env.sh /usr/local/bin/load-k8s-env.sh
COPY --chown=root:root platform-services/shared/scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh

COPY platform-services/backend/deepiri-platform-analytics-service/package.json ./
COPY platform-services/backend/deepiri-platform-analytics-service/package-lock.json ./
COPY platform-services/backend/deepiri-platform-analytics-service/tsconfig.json ./

RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));delete p.dependencies['@deepiri/shared-utils'];fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

RUN npm install --legacy-peer-deps && npm cache clean --force

COPY --from=shared-utils-builder /shared-utils/package.json /app/node_modules/@deepiri/shared-utils/package.json
COPY --from=shared-utils-builder /shared-utils/dist /app/node_modules/@deepiri/shared-utils/dist

# Source
COPY platform-services/backend/deepiri-platform-analytics-service/src ./src

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

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
