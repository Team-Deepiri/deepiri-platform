import express, { Router, Request, Response } from 'express';
import { registryService } from './services/registryService';
import {
  getEcosystemHealth,
  getRepo,
  listRepos,
  listTools,
  recordRepoHealth,
} from './services/repoCatalogService';

const router: Router = express.Router();

router.get('/services', async (_req: Request, res: Response) => {
  res.json(await registryService.listServices());
});

router.get('/services/:name', async (req: Request, res: Response) => {
  const entry = await registryService.getService(req.params.name);
  if (!entry) {
    res.status(404).json({ error: 'Service not found' });
    return;
  }
  res.json(entry);
});

router.post('/services', async (req: Request, res: Response) => {
  const entry = await registryService.registerService(req.body);
  res.status(201).json(entry);
});

router.post('/poll', async (_req: Request, res: Response) => {
  const results = await registryService.pollHealth();
  res.json({ polled: results.length, results });
});

router.get('/repos', async (_req: Request, res: Response) => {
  res.json({ repos: await listRepos() });
});

router.get('/repos/:id', async (req: Request, res: Response) => {
  const repo = await getRepo(req.params.id);
  if (!repo) {
    res.status(404).json({ error: 'Repo not found' });
    return;
  }
  res.json(repo);
});

router.get('/repos/:id/health', async (req: Request, res: Response) => {
  const repo = await getRepo(req.params.id);
  if (!repo) {
    res.status(404).json({ error: 'Repo not found' });
    return;
  }
  const latest = repo.healthChecks[0];
  if (!latest) {
    res.json({ repoId: repo.id, status: 'unknown', checkedAt: null });
    return;
  }
  res.json(latest);
});

router.post('/repos/:id/health', async (req: Request, res: Response) => {
  const repo = await getRepo(req.params.id);
  if (!repo) {
    res.status(404).json({ error: 'Repo not found' });
    return;
  }
  const { status, detail } = req.body ?? {};
  if (!status) {
    res.status(400).json({ error: 'status is required' });
    return;
  }
  const check = await recordRepoHealth(repo.id, status, detail);
  res.status(201).json(check);
});

router.get('/tools', async (_req: Request, res: Response) => {
  res.json({ tools: await listTools() });
});

router.get('/health/ecosystem', async (_req: Request, res: Response) => {
  res.json(await getEcosystemHealth());
});

export default router;
