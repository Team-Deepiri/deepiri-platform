import express, { Router, Request, Response } from 'express';
import { registryService } from './services/registryService';

const router: Router = express.Router();

router.get('/services', (_req: Request, res: Response) => {
  res.json(registryService.listServices());
});

router.get('/services/:name', (req: Request, res: Response) => {
  const entry = registryService.getService(req.params.name);
  if (!entry) {
    res.status(404).json({ error: 'Service not found' });
    return;
  }
  res.json(entry);
});

router.post('/services', (req: Request, res: Response) => {
  const entry = registryService.registerService(req.body);
  res.status(201).json(entry);
});

router.post('/poll', async (_req: Request, res: Response) => {
  const results = await registryService.pollHealth();
  res.json({ polled: results.length, results });
});

export default router;
