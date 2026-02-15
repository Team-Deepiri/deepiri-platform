import { PrismaClient } from '@prisma/client';
import { logger } from './utils/logger';

let prisma: PrismaClient;

export async function connectDatabase(): Promise<void> {
  try {
    prisma = new PrismaClient({
      log: process.env.NODE_ENV === 'development' 
        ? ['query', 'error', 'warn'] 
        : ['error'],
      datasources: {
        db: {
          url: process.env.DATABASE_URL,
        },
      },
    });
    
    // Test connection
    await prisma.$connect();
    await prisma.$queryRaw`SELECT 1`;
    
    logger.info('Messaging Service: Connected to PostgreSQL');
  } catch (error: any) {
    logger.error('Messaging Service: Failed to connect to PostgreSQL', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}

export async function disconnectDatabase(): Promise<void> {
  try {
    await prisma?.$disconnect();
    logger.info('Messaging Service: Disconnected from PostgreSQL');
  } catch (error: any) {
    logger.error('Messaging Service: Error disconnecting from PostgreSQL', error);
  }
}

// Handle graceful shutdown
process.on('beforeExit', async () => {
  await disconnectDatabase();
});

export { prisma };

