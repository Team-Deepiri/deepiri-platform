import express, { Router, Request, Response } from 'express';
import taskVersioningService from './taskVersioningService';
import dependencyGraphService from './dependencyGraphService';

const router: Router = express.Router();

router.get('/tasks', (req: Request, res: Response) => taskVersioningService.getTasks(req, res));
router.post('/tasks', (req: Request, res: Response) => taskVersioningService.createTask(req, res));
router.put('/tasks/:id', (req: Request, res: Response) => taskVersioningService.updateTask(req, res));
router.get('/tasks/:id/versions', (req: Request, res: Response) => taskVersioningService.getVersions(req, res));

router.get('/dependencies/:taskId', (req: Request, res: Response) => dependencyGraphService.getDependencies(req, res));
router.post('/dependencies', (req: Request, res: Response) => dependencyGraphService.addDependency(req, res));

export default router;

