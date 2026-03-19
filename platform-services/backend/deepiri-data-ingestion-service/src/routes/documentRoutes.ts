import { Router, Request, Response } from 'express';
import multer from 'multer';
import { documentIngestionService } from '../services/documentIngestionService';
import { requireIngestionScope } from '../middleware/authMiddleware';
import { config } from '../config/environment';
import { logger } from '../utils/logger';

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: config.upload.maxFileSizeMb * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (config.upload.allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported file type: ${file.mimetype}`));
    }
  },
});

router.post('/', requireIngestionScope, upload.single('file'), async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'No file provided' });
      return;
    }

    const userId = (req as any).userId as string;
    const result = await documentIngestionService.ingestDocument(userId, req.file);
    res.status(201).json(result);
  } catch (error: any) {
    logger.error('POST /documents failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.get('/', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId as string;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const result = await documentIngestionService.listDocuments(userId, page, limit);
    res.json(result);
  } catch (error: any) {
    logger.error('GET /documents failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.get('/:id', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const record = await documentIngestionService.getRecord(req.params.id);
    if (!record) {
      res.status(404).json({ error: 'Not found' });
      return;
    }
    res.json(record);
  } catch (error: any) {
    logger.error('GET /documents/:id failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

router.delete('/:id', requireIngestionScope, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId as string;
    const result = await documentIngestionService.deleteDocument(req.params.id, userId);
    res.json(result);
  } catch (error: any) {
    logger.error('DELETE /documents/:id failed', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

export default router;
