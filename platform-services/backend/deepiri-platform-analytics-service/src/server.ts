import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
// MongoDB removed - analytics uses InfluxDB for time-series and PostgreSQL for metadata
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import winston from 'winston';
import routes from './index';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5004', 10);

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

app.use(helmet());
app.use(cors());
app.use(express.json());

// PostgreSQL connection via Prisma (if needed for analytics metadata)
// Primary analytics data stored in InfluxDB

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'platform-analytics-service', timestamp: new Date().toISOString() });
});

app.use('/', routes);

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  logger.error('Platform Analytics Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

// Start event consumption
import { startEventConsumption } from './streaming/eventConsumer';

startEventConsumption().catch((err) => {
  logger.error('Failed to start event consumption:', err);
});

app.listen(PORT, () => {
  logger.info(`Platform Analytics Service running on port ${PORT}`);
});

export default app;

