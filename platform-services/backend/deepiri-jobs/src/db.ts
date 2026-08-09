import { PrismaClient } from '@prisma/client';
import { secureLog } from '@team-deepiri/shared-utils';

const prisma = new PrismaClient();

export async function connectDatabase(): Promise<void> {
  await prisma.$connect();
  secureLog('info', 'Jobs service: connected to PostgreSQL');
}

export async function disconnectDatabase(): Promise<void> {
  await prisma.$disconnect();
}

process.on('beforeExit', async () => {
  await disconnectDatabase();
});

export default prisma;
