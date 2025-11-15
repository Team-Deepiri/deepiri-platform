# Use Node.js LTS version
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install system dependencies (dumb-init and curl needed at runtime)
RUN apk add --no-cache curl dumb-init

# Copy package files
COPY package*.json ./

# Install dependencies and clean up in one layer
RUN npm ci --only=production --legacy-peer-deps && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/tmp/*

# Copy source code
COPY . .

# Create non-root user and set up directories in one layer
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    mkdir -p logs && chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start the application
CMD ["npm", "start"]