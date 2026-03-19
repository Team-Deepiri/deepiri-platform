FROM node:18-slim AS shared-utils-builder
WORKDIR /shared-utils
COPY platform-services/shared/deepiri-shared-utils/package.json ./
COPY platform-services/shared/deepiri-shared-utils/tsconfig.json ./
COPY platform-services/shared/deepiri-shared-utils/src ./src
RUN npm install --legacy-peer-deps && npm run build

# ===============================
# Build task-orchestrator
# ===============================
FROM node:18-slim
WORKDIR /app

# Prisma + healthcheck deps (Debian)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      openssl \
      dumb-init \
      bash \
      libc6 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Prisma binary compatibility
RUN mkdir -p /lib64 \
 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
           /lib64/ld-linux-x86-64.so.2

# Copy K8s env loader scripts
COPY --chown=root:root platform-services/shared/scripts/load-k8s-env.sh /usr/local/bin/load-k8s-env.sh
COPY --chown=root:root platform-services/shared/scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/load-k8s-env.sh /usr/local/bin/docker-entrypoint.sh

# Package files (LOCK FILE INCLUDED)
COPY platform-services/backend/deepiri-task-orchestrator/package.json ./
COPY platform-services/backend/deepiri-task-orchestrator/package-lock.json ./
COPY platform-services/backend/deepiri-task-orchestrator/tsconfig.json ./

RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));delete p.dependencies['@deepiri/shared-utils'];fs.writeFileSync('package.json',JSON.stringify(p,null,2))"

RUN npm install --legacy-peer-deps && npm cache clean --force

COPY --from=shared-utils-builder /shared-utils/package.json /app/node_modules/@deepiri/shared-utils/package.json
COPY --from=shared-utils-builder /shared-utils/dist /app/node_modules/@deepiri/shared-utils/dist

# Source + Prisma schema
COPY platform-services/backend/deepiri-task-orchestrator/src ./src
COPY platform-services/backend/deepiri-task-orchestrator/prisma ./prisma

# Prisma generate + TypeScript build
RUN npx prisma generate \
 && npm run build \
 && cd node_modules/.prisma/client \
 && if [ -f libquery_engine-debian-openssl-3.0.x.so.node ]; then \
      cp libquery_engine-debian-openssl-3.0.x.so.node \
         libquery_engine-linux-musl.so.node; \
    fi \
 && cd /app

# Runtime user
RUN groupadd -r -g 1001 nodejs \
 && useradd -r -u 1001 -g nodejs -m -d /home/nodejs nodejs \
 && mkdir -p logs /home/nodejs/.npm \
 && chown -R nodejs:nodejs /app /home/nodejs

USER nodejs

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5002/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["dumb-init", "--", "node", "dist/server.js"]
