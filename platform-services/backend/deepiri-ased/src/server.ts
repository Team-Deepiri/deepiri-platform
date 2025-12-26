import express from 'express';
import { createLogger } from '@deepiri/shared-utils';
import { Orchestrator } from './orchestrator';
import { Scheduler } from './scheduler';
import { loadConfig } from './config';

const logger = createLogger('sovereignty-enforcement');
const app = express();
app.use(express.json());

let orchestrator: Orchestrator | null = null;
let scheduler: Scheduler | null = null;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-ased',
    timestamp: new Date().toISOString(),
  });
});

// Manual trigger endpoint
app.post('/trigger', async (req, res) => {
  try {
    if (!orchestrator) {
      return res.status(503).json({ error: 'Orchestrator not initialized' });
    }
    await orchestrator.runDetectionCycle();
    res.json({ success: true, message: 'Detection cycle triggered' });
  } catch (error: any) {
    logger.error('Error triggering detection cycle:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get risk scores endpoint
app.get('/risk-scores', (req, res) => {
  try {
    if (!orchestrator) {
      return res.status(503).json({ error: 'Orchestrator not initialized' });
    }
    const scores = (orchestrator as any).scoring.accumulator.getAllScores();
    const result: Record<string, any> = {};
    for (const [repo, score] of scores.entries()) {
      result[repo] = {
        current: score.current,
        lastUpdate: score.lastUpdate,
        eventCount: score.events.length,
      };
    }
    res.json(result);
  } catch (error: any) {
    logger.error('Error getting risk scores:', error);
    res.status(500).json({ error: error.message });
  }
});

// Initialize and start
async function start() {
  try {
    const config = loadConfig();
    
    logger.info('Initializing Sovereignty Enforcement Service...');
    
    orchestrator = new Orchestrator();
    
    // Initialize (will auto-establish baseline if needed)
    try {
      await orchestrator.initialize();
    } catch (error: any) {
      logger.warn('Initialization had warnings, but continuing:', error.message);
      // Don't exit - allow service to start and retry on first cycle
    }
    
    scheduler = new Scheduler(orchestrator);
    scheduler.start();
    
    // Run first detection cycle after a short delay (allows baseline to be established)
    setTimeout(async () => {
      try {
        await orchestrator.runDetectionCycle();
      } catch (error: any) {
        logger.error('First detection cycle failed:', error);
      }
    }, 30000); // 30 seconds delay
    
    const PORT = config.server.port;
    app.listen(PORT, () => {
      logger.info(`Sovereignty Enforcement Service started on port ${PORT}`);
      logger.info('Configuration loaded from YAML files (via docker-compose-k8s.sh)');
    });
  } catch (error: any) {
    logger.error('Failed to start service:', error);
    // Don't exit immediately - log error and allow retry
    logger.warn('Service will attempt to start anyway. Check configuration.');
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  if (scheduler) {
    scheduler.stop();
  }
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  if (scheduler) {
    scheduler.stop();
  }
  process.exit(0);
});

start();

