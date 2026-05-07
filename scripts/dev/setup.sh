#!/bin/bash

# Deepiri Setup Script
echo "🚀 Setting up Deepiri..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check for Docker Compose support
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please update the .env file with your API keys and configuration"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p deepiri-core-api/logs
mkdir -p deepiri-core-api/config
mkdir -p nginx/ssl

# Install dependencies through the shared setup path so local submodule
# dependencies (including shared-utils) resolve consistently.
echo "📦 Installing project dependencies..."
./scripts/dev/fix-dependencies.sh

# Generate JWT secret if not provided
if grep -q "your_jwt_secret_key" .env; then
    JWT_SECRET=$(openssl rand -hex 32)
    sed -i "s/your_jwt_secret_key/$JWT_SECRET/g" .env
    echo "🔑 Generated JWT secret"
fi

echo "✅ Setup complete!"
echo ""
echo "🚀 To start the application:"
echo "   1. Update the .env file with your API keys"
echo "   2. Run: ${COMPOSE_CMD} up -d"
echo ""
echo "🌐 The application will be available at:"
echo "   - Frontend: http://localhost:3000"
echo "   - Backend API: http://localhost:5000"
echo "   - API Documentation: http://localhost:5000/api-docs"
echo ""
echo "📚 For more information, check the README.md file"
