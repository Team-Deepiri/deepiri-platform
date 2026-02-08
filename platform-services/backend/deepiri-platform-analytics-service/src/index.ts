import express, { Router, Request, Response } from 'express';
import timeSeriesAnalytics from './timeSeriesAnalytics';
import behavioralClustering from './behavioralClustering';
import predictiveModeling from './predictiveModeling';

const router: Router = express.Router();

router.post('/time-series/record', (req: Request, res: Response) => timeSeriesAnalytics.recordData(req, res));
router.get('/time-series/:userId', (req: Request, res: Response) => timeSeriesAnalytics.getAnalytics(req, res));

router.post('/clustering/analyze', (req: Request, res: Response) => behavioralClustering.analyze(req, res));
router.get('/clustering/:userId/group', (req: Request, res: Response) => behavioralClustering.getUserGroup(req, res));

router.post('/predictive/forecast', (req: Request, res: Response) => predictiveModeling.forecast(req, res));
router.get('/predictive/:userId/recommendations', (req: Request, res: Response) => predictiveModeling.getRecommendations(req, res));

export default router;

