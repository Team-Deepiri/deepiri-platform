# Embed Bedd via multi-stage FROM published image (BuildKit-safe).
ARG BEDD_IMAGE=ghcr.io/team-deepiri/bedd:0.8
FROM ${BEDD_IMAGE} AS bedd

FROM ghcr.io/team-deepiri/deepiri-suite:18-alpine

# Bedd runtime (Bun-style) — musl binary for Alpine
COPY --from=bedd /opt/bedd/bedd-musl /usr/local/bin/bedd
COPY --from=bedd /opt/bedd/skills /opt/bedd/skills
ENV BEDD_SKILLS_DIR=/opt/bedd/skills
ENV BEDD_BUS_URL=redis://redis:6379
ENV BEDD_DLQ_STREAM=bedd.dlq

COPY shared/deepiri-shared-utils/package.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/package-lock.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
COPY backend/deepiri-registry/package.json ./
COPY backend/deepiri-registry/package-lock.json ./
COPY backend/deepiri-registry/tsconfig.json ./
COPY backend/deepiri-registry/prisma ./prisma

RUN node -e "const fs=require('fs'),lock=JSON.parse(fs.readFileSync('package-lock.json'));for(const k of Object.keys(lock.packages)){if(k.includes('deepiri-shared-utils')||k==='node_modules/@team-deepiri/shared-utils')delete lock.packages[k]}fs.writeFileSync('package-lock.json',JSON.stringify(lock));" \
 && cd /shared/deepiri-shared-utils \
 && npm ci --legacy-peer-deps \
 && npm run build \
 && node -e "const fs=require('fs'),p=JSON.parse(fs.readFileSync('package.json'));delete p.scripts.prepare;fs.writeFileSync('package.json',JSON.stringify(p,null,2));" \
 && rm -rf node_modules \
 && cd /app \
 && npm install --legacy-peer-deps file:/shared/deepiri-shared-utils \
 && npm ci --legacy-peer-deps \
 && cd /shared/deepiri-shared-utils \
 && npm ci --omit=dev --legacy-peer-deps \
 && cd /app \
 && npm cache clean --force

COPY backend/deepiri-registry/src ./src

RUN npx prisma generate \
 && npm run build

RUN mkdir -p logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5003

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5003/health || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/dumb-init", "--", "node", "dist/server.js"]
