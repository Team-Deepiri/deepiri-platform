FROM ghcr.io/team-deepiri/deepiri-suite:18-alpine

COPY shared/deepiri-shared-utils/package*.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
COPY backend/deepiri-decision-intelligence/package*.json ./

RUN cd /shared/deepiri-shared-utils \
 && npm install --legacy-peer-deps \
 && npm run build \
 && cd /app \
 && npm install --legacy-peer-deps \
 && npm cache clean --force

COPY backend/deepiri-decision-intelligence/tsconfig.json ./
COPY backend/deepiri-decision-intelligence/src ./src

RUN npm run build

RUN mkdir -p logs \
 && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5004

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5004/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
