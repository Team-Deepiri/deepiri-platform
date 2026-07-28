// Database connection using Prisma
import { PrismaClient } from '@prisma/client';
import { createLogger, secureLog } from '@team-deepiri/shared-utils';

const logger = createLogger('truss');

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
    secureLog('info', 'Truss: Connected to PostgreSQL via Prisma');
  } catch (error) {
    secureLog('error', 'Truss: PostgreSQL connection error', error);
    throw error;
  }
}

// Disconnect from database
export async function disconnectDatabase() {
  await prisma.$disconnect();
  secureLog('info', 'Truss: Disconnected from PostgreSQL');
}

// Graceful shutdown
process.on('beforeExit', async () => {
  await disconnectDatabase();
});

export default prisma;

