import express, { Router, Request, Response } from 'express';
import multiCurrencyService from './multiCurrencyService';
import badgeSystemService from './badgeSystemService';
import eloLeaderboardService from './eloLeaderboardService';
import momentumService from './services/momentumService';
import streakService from './services/streakService';
import boostService from './services/boostService';
import objectiveService from './services/objectiveService';
import odysseyService from './services/odysseyService';
import seasonService from './services/seasonService';
import rewardService from './services/rewardService';

const router: Router = express.Router();

// Currency routes
router.post('/currency/award', (req: Request, res: Response) => multiCurrencyService.awardPoints(req, res));
router.get('/currency/:userId', (req: Request, res: Response) => multiCurrencyService.getBalance(req, res));

// Badge routes
router.get('/badges/:userId', (req: Request, res: Response) => badgeSystemService.getBadges(req, res));
router.post('/badges/award', (req: Request, res: Response) => badgeSystemService.awardBadge(req, res));

// Leaderboard routes
router.get('/leaderboard', (req: Request, res: Response) => eloLeaderboardService.getLeaderboard(req, res));
router.post('/leaderboard/update', (req: Request, res: Response) => eloLeaderboardService.updateRating(req, res));

// Momentum routes
router.get('/momentum/:userId', (req: Request, res: Response) => momentumService.getProfile(req, res));
router.post('/momentum/award', (req: Request, res: Response) => momentumService.award(req, res));
router.get('/momentum/ranking', (req: Request, res: Response) => momentumService.getRanking(req, res));
router.get('/momentum/:userId/rank', (req: Request, res: Response) => momentumService.getUserRank(req, res));

// Streak routes
router.get('/streaks/:userId', (req: Request, res: Response) => streakService.getStreaks(req, res));
router.post('/streaks/update', (req: Request, res: Response) => streakService.updateStreak(req, res));
router.post('/streaks/cash-in', (req: Request, res: Response) => streakService.cashInStreak(req, res));

// Boost routes
router.get('/boosts/:userId', (req: Request, res: Response) => boostService.getProfile(req, res));
router.post('/boosts/activate', (req: Request, res: Response) => boostService.activate(req, res));
router.post('/boosts/add-credits', (req: Request, res: Response) => boostService.addCreditsEndpoint(req, res));
router.get('/boosts/costs', (req: Request, res: Response) => boostService.getCosts(req, res));

// Objective routes
router.post('/objectives', (req: Request, res: Response) => objectiveService.create(req, res));
router.get('/objectives/:userId', (req: Request, res: Response) => objectiveService.getObjectives(req, res));
router.get('/objectives/detail/:id', (req: Request, res: Response) => objectiveService.getObjective(req, res));
router.post('/objectives/:id/complete', (req: Request, res: Response) => objectiveService.complete(req, res));
router.put('/objectives/:id', (req: Request, res: Response) => objectiveService.update(req, res));
router.delete('/objectives/:id', (req: Request, res: Response) => objectiveService.delete(req, res));

// Odyssey routes
router.post('/odysseys', (req: Request, res: Response) => odysseyService.create(req, res));
router.get('/odysseys/:userId', (req: Request, res: Response) => odysseyService.getOdysseys(req, res));
router.get('/odysseys/detail/:id', (req: Request, res: Response) => odysseyService.getOdyssey(req, res));
router.post('/odysseys/:id/objectives', (req: Request, res: Response) => odysseyService.addObjectiveEndpoint(req, res));
router.post('/odysseys/:id/milestones', (req: Request, res: Response) => odysseyService.addMilestoneEndpoint(req, res));
router.post('/odysseys/:id/milestones/:milestoneId/complete', (req: Request, res: Response) => odysseyService.completeMilestoneEndpoint(req, res));
router.put('/odysseys/:id', (req: Request, res: Response) => odysseyService.update(req, res));

// Season routes
router.post('/seasons', (req: Request, res: Response) => seasonService.create(req, res));
router.get('/seasons', (req: Request, res: Response) => seasonService.getSeasons(req, res));
router.get('/seasons/:id', (req: Request, res: Response) => seasonService.getSeason(req, res));
router.post('/seasons/:id/odysseys', (req: Request, res: Response) => seasonService.addOdysseyEndpoint(req, res));
router.post('/seasons/:id/boost', (req: Request, res: Response) => seasonService.enableBoost(req, res));
router.post('/seasons/:id/highlights', (req: Request, res: Response) => seasonService.generateHighlightsEndpoint(req, res));

// Reward routes
router.post('/rewards', (req: Request, res: Response) => rewardService.create(req, res));
router.get('/rewards/:userId', (req: Request, res: Response) => rewardService.getRewardsEndpoint(req, res));
router.post('/rewards/:id/claim', (req: Request, res: Response) => rewardService.claim(req, res));
router.get('/rewards/:userId/pending-count', (req: Request, res: Response) => rewardService.getPendingCount(req, res));

export default router;

