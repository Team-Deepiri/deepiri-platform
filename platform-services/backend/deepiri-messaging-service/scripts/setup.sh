#!/bin/bash

# Setup script for Messaging Service

echo "🚀 Setting up Deepiri Messaging Service..."

# Check if .env exists
if [ ! -f .env ]; then
  echo "📝 Creating .env file from .env.example..."
  cp .env.example .env
  echo "⚠️  Please update .env with your configuration"
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Generate Prisma client
echo "🔧 Generating Prisma client..."
npm run prisma:generate

# Check if database is configured
if [ -z "$DATABASE_URL" ]; then
  echo "⚠️  DATABASE_URL not set. Please configure it in .env"
  echo "   Example: DATABASE_URL=postgresql://user:password@localhost:5432/deepiri?schema=messaging"
fi

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update .env with your configuration"
echo "2. Run migrations: npm run prisma:migrate"
echo "3. Start development server: npm run dev"

