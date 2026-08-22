FROM ghcr.io/team-deepiri/deepiri-suite:18-alpine

COPY shared/deepiri-shared-utils/package.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/package-lock.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
COPY backend/deepiri-realtime-gateway/package.json ./

RUN cd /shared/deepiri-shared-utils \
 && npm ci --legacy-peer-deps \
 && npm run build \
 && node -e "const fs=require('fs'),p=JSON.parse(fs.readFileSync('package.json'));delete p.scripts.prepare;fs.writeFileSync('package.json',JSON.stringify(p,null,2));" \
 && rm -rf node_modules \
 && cd /app \
 && npm install --legacy-peer-deps file:/shared/deepiri-shared-utils \
 && npm install --legacy-peer-deps \
 && cd /shared/deepiri-shared-utils \
 && npm ci --omit=dev --legacy-peer-deps \
 && cd /app \
 && npm cache clean --force

COPY backend/deepiri-realtime-gateway/tsconfig.json ./
COPY backend/deepiri-realtime-gateway/src ./src

RUN npm run build

RUN mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5008

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5008/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
