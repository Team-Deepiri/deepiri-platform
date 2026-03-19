import { Router, Request, Response } from 'express';
import multer from 'multer';
import { structuredDataService } from '../services/structuredDataService';
import { requireIngestionScope } from '../middleware/authMiddleware';
import { logger } from '../utils/logger';

const router = Router();

const csvUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'text/csv' || file.originalname.endsWith('.csv')) {
      cb(null, true);
    } else {
      cb(new Error('Only CSV files are accepted for this endpoint'));
    }
  },
});

router.post('/', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId as string;
    const { data, schemaName } = req.body;

    if (!data) {
      res.status(400).json({ error: 'Missing "data" field in request body' });
      return;
    }

    const result = await structuredDataService.ingestJson(userId, data, schemaName);
    res.status(201).json(result);
  } catch (error: any) {
    logger.error('POST /data failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.post('/csv', requireIngestionScope, csvUpload.single('file'), async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'No CSV file provided' });
      return;
    }

    const userId = (req as any).userId as string;
    const schemaName = req.body.schemaName;
    const result = await structuredDataService.ingestCsv(userId, req.file, schemaName);
    res.status(201).json(result);
  } catch (error: any) {
    logger.error('POST /data/csv failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.get('/', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId as string;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const result = await structuredDataService.listData(userId, page, limit);
    res.json(result);
  } catch (error: any) {
    logger.error('GET /data failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.get('/:id', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const record = await structuredDataService.getRecord(req.params.id);
    if (!record) {
      res.status(404).json({ error: 'Not found' });
      return;
    }
    res.json(record);
  } catch (error: any) {
    logger.error('GET /data/:id failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

export default router;
