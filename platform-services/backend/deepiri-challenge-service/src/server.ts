import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import winston from 'winston';
import axios from 'axios';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5007', 10);

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

app.use(helmet());
app.use(cors());
app.use(express.json());

const MONGO_URI: string = process.env.MONGO_URI || 'mongodb://mongodb:27017/deepiri';
mongoose.connect(MONGO_URI)
  .then(() => logger.info('Challenge Service: Connected to MongoDB'))
  .catch((err: Error) => logger.error('Challenge Service: MongoDB connection error', err));

const CYREX_URL: string = process.env.CYREX_URL || 'http://cyrex:8000';

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'challenge-service', timestamp: new Date().toISOString() });
});

app.post('/generate', async (req: Request, res: Response) => {
  try {
    const response = await axios.post(`${CYREX_URL}/agent/challenge/generate`, req.body);
    res.json(response.data);
  } catch (error: any) {
    logger.error('Challenge generation error:', error);
    res.status(500).json({ error: 'Failed to generate challenge' });
  }
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  logger.error('Challenge Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  logger.info(`Challenge Service running on port ${PORT}`);
});

export default app;

