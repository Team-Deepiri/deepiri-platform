# Build shared-utils first
FROM node:20-alpine AS shared-utils-builder
WORKDIR /shared-utils
COPY shared/deepiri-shared-utils/package*.json ./
COPY shared/deepiri-shared-utils/tsconfig.json ./
COPY shared/deepiri-shared-utils/src ./src

RUN npm install --legacy-peer-deps && \
    npm run build && \
    npm cache clean --force

# Build main service
FROM node:20-alpine
WORKDIR /app

# Install curl for health checks and OpenSSL for Prisma
RUN apk add --no-cache curl openssl

# Copy package files
COPY backend/deepiri-messaging-service/package*.json ./
COPY backend/deepiri-messaging-service/tsconfig.json ./

# Copy built shared-utils
COPY --from=shared-utils-builder /shared-utils /shared-utils

# Install dependencies (including shared-utils as file dependency)
RUN npm install --legacy-peer-deps file:/shared-utils && \
    npm cache clean --force

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

