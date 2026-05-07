FROM ghcr.io/team-deepiri/deepiri-base:18-slim

# Prisma binary compatibility (service-specific)
RUN mkdir -p /lib64 \
 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
           /lib64/ld-linux-x86-64.so.2

COPY shared/deepiri-shared-utils/package*.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
COPY backend/deepiri-workflow-orchestrator/package*.json ./
COPY backend/deepiri-workflow-orchestrator/tsconfig.json ./
COPY backend/deepiri-workflow-orchestrator/prisma ./prisma

RUN cd /shared/deepiri-shared-utils \
 && npm install --legacy-peer-deps \
 && npm run build \
 && cd /app \
 && npm install --legacy-peer-deps \
 && npm cache clean --force

COPY backend/deepiri-workflow-orchestrator/src ./src

RUN npx prisma generate \
 && npm run build \
 && cd node_modules/.prisma/client \
 && if [ -f libquery_engine-debian-openssl-3.0.x.so.node ]; then \
      cp libquery_engine-debian-openssl-3.0.x.so.node \
         libquery_engine-linux-musl.so.node; \
    fi \
 && cd /app

RUN mkdir -p logs /home/nodejs/.npm \
 && chown -R nodejs:nodejs /app /home/nodejs

USER nodejs

EXPOSE 5002

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5002/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["dumb-init", "--", "node", "dist/server.js"]
