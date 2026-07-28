import express, { Router, Request, Response } from 'express';
import timeSeriesAnalytics from './timeSeriesAnalytics';
import behavioralClustering from './behavioralClustering';
import predictiveModeling from './predictiveModeling';
import { handleGetEcosystemHealth } from './services/ecosystemHealthService';
import { handleGetJobMetrics } from './services/jobMetricsService';
import { handleGetRecentEvents } from './services/synapseEventIndexService';

const router: Router = express.Router();

router.post('/time-series/record', (req: Request, res: Response) => timeSeriesAnalytics.recordData(req, res));
router.get('/time-series/:userId', (req: Request, res: Response) => timeSeriesAnalytics.getAnalytics(req, res));
// Generalized alias -- same handler, just not user-scoped naming, for
// callers polling metrics for a service/target rather than a user. A
// separate path segment (not bare /time-series/:target) avoids colliding
// with the /time-series/:userId route registered above.
router.get('/time-series/target/:target', (req: Request, res: Response) => {
  req.params.userId = req.params.target;
  return timeSeriesAnalytics.getAnalytics(req, res);
});
router.post('/metrics/record', (req: Request, res: Response) => timeSeriesAnalytics.recordData(req, res));
router.get('/health/ecosystem', handleGetEcosystemHealth);
router.get('/metrics/jobs', handleGetJobMetrics);
router.get('/events/recent', handleGetRecentEvents);

router.post('/clustering/analyze', (req: Request, res: Response) => behavioralClustering.analyze(req, res));
router.get('/clustering/:userId/group', (req: Request, res: Response) => behavioralClustering.getUserGroup(req, res));

router.post('/predictive/forecast', (req: Request, res: Response) => predictiveModeling.forecast(req, res));
router.get('/predictive/:userId/recommendations', (req: Request, res: Response) => predictiveModeling.getRecommendations(req, res));

export default router;

