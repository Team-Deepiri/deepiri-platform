import express, { Router, Request, Response } from 'express';
import multiCurrencyService from './multiCurrencyService';
import badgeSystemService from './badgeSystemService';
import eloLeaderboardService from './eloLeaderboardService';

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

export default router;

