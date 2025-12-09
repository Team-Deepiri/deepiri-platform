// Database connection using Prisma
import { PrismaClient } from '@prisma/client';
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({ format: winston.format.simple() })
  ]
});

// Prisma Client singleton
const prisma = new PrismaClient({
  log: [
    { level: 'query', emit: 'event' },
    { level: 'error', emit: 'stdout' },
    { level: 'warn', emit: 'stdout' },
  ],
});

// Log queries in development
if (process.env.NODE_ENV === 'development') {
  prisma.$on('query' as never, (e: any) => {
    logger.debug('Query:', { query: e.query, duration: `${e.duration}ms` });
  });
}

// Connect to database
export async function connectDatabase() {
  try {
    await prisma.$connect();
    logger.info('Engagement Service: Connected to PostgreSQL via Prisma');
  } catch (error) {
    logger.error('Engagement Service: PostgreSQL connection error', error);
    throw error;
  }
}

// Disconnect from database
export async function disconnectDatabase() {
  await prisma.$disconnect();
  logger.info('Engagement Service: Disconnected from PostgreSQL');
}

// Graceful shutdown
process.on('beforeExit', async () => {
  await disconnectDatabase();
});

export default prisma;

