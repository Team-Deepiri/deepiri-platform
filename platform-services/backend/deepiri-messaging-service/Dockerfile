FROM ghcr.io/team-deepiri/deepiri-suite:20-alpine


# Bedd runtime (Bun-style) — musl binary for Alpine
ARG BEDD_IMAGE=ghcr.io/team-deepiri/bedd:0.6
COPY --from=${BEDD_IMAGE} /opt/bedd/bedd-musl /usr/local/bin/bedd
COPY --from=${BEDD_IMAGE} /opt/bedd/skills /opt/bedd/skills
ENV BEDD_SKILLS_DIR=/opt/bedd/skills

COPY shared/deepiri-shared-utils/package.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/package-lock.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
COPY backend/deepiri-messaging-service/package.json ./
COPY backend/deepiri-messaging-service/tsconfig.json ./
COPY backend/deepiri-messaging-service/prisma ./prisma

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

COPY backend/deepiri-messaging-service/src ./src

RUN npx prisma generate \
 && npm run build

EXPOSE 5009

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5009/health || exit 1

CMD ["npm", "start"]
