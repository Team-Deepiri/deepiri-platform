import express, { Router, Request, Response } from 'express';
import oauthService from './oauthService';
import skillTreeService from './skillTreeService';
import socialGraphService from './socialGraphService';
import timeSeriesService from './timeSeriesService';

const router: Router = express.Router();

// OAuth routes
router.post('/oauth/authorize', (req: Request, res: Response) => oauthService.authorize(req, res));
router.post('/oauth/token', (req: Request, res: Response) => oauthService.token(req, res));
router.post('/oauth/register', (req: Request, res: Response) => oauthService.registerClient(req, res));

// Skill tree routes
router.get('/skill-tree/:userId', (req: Request, res: Response) => skillTreeService.getSkillTree(req, res));
router.post('/skill-tree/:userId/upgrade', (req: Request, res: Response) => skillTreeService.upgradeSkill(req, res));

// Social graph routes
router.get('/social/:userId/friends', (req: Request, res: Response) => socialGraphService.getFriends(req, res));
router.post('/social/:userId/friends', (req: Request, res: Response) => socialGraphService.addFriend(req, res));

// Time series routes
router.post('/time-series/record', (req: Request, res: Response) => timeSeriesService.recordData(req, res));
router.get('/time-series/:userId', (req: Request, res: Response) => timeSeriesService.getData(req, res));

export default router;

