FROM mcr.microsoft.com/playwright:v1.46.0-jammy

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci || npm install
# Playwright browsers already in base image (chromium)

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# data dir for session persistence
RUN mkdir -p /app/data

ENV NODE_ENV=production
ENV PORT=5009
EXPOSE 5009

CMD ["node", "dist/server.js"]
