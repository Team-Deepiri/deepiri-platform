# Build main service
FROM ghcr.io/team-deepiri/deepiri-suite:20-alpine

COPY shared/deepiri-shared-utils/package*.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/tsconfig.json /shared/deepiri-shared-utils/
COPY shared/deepiri-shared-utils/src /shared/deepiri-shared-utils/src
# Copy package files
COPY backend/deepiri-messaging-service/package*.json ./
COPY backend/deepiri-messaging-service/tsconfig.json ./

# Install dependencies, including shared-utils from GitHub Packages
RUN cd /shared/deepiri-shared-utils \
 && npm install --legacy-peer-deps \
 && npm run build \
 && cd /app \
 && npm install --legacy-peer-deps \
 && npm cache clean --force

# Copy source code
COPY backend/deepiri-messaging-service/src ./src
COPY backend/deepiri-messaging-service/prisma ./prisma

# Generate Prisma client
RUN npx prisma generate

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 5009

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5009/health || exit 1

# Start server
CMD ["npm", "start"]
