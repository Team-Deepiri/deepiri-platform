import { createServer } from './server';
import { connectDatabase, disconnectDatabase } from './db';
import { config } from './config/environment';
import { logger } from './utils/logger';

async function startServer() {
  try {
    // Connect to database
    await connectDatabase();

    // Create and start server
    const app = createServer();
    const server = app.listen(config.port, () => {
      logger.info(`Messaging Service started on port ${config.port}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      logger.info('SIGTERM received, shutting down gracefully');
      server.close(async () => {
        await disconnectDatabase();
        process.exit(0);
      });
    });

    process.on('SIGINT', async () => {
      logger.info('SIGINT received, shutting down gracefully');
      server.close(async () => {
        await disconnectDatabase();
        process.exit(0);
      });
    });
  } catch (error: any) {
    logger.error('Failed to start server', {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  }
}

startServer();

