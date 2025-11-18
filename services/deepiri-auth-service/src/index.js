const express = require('express');
const router = express.Router();

// Import services
const oauthService = require('./oauthService');
const skillTreeService = require('./skillTreeService');
const socialGraphService = require('./socialGraphService');
const timeSeriesService = require('./timeSeriesService');

// Use exported instances
const oauth = oauthService;
const skillTree = skillTreeService;
const socialGraph = socialGraphService;
const timeSeries = timeSeriesService;

// OAuth routes
router.post('/oauth/authorize', (req, res) => oauth.authorize(req, res));
router.post('/oauth/token', (req, res) => oauth.token(req, res));
router.post('/oauth/register', (req, res) => oauth.registerClient(req, res));

// Skill tree routes
router.get('/skill-tree/:userId', (req, res) => skillTree.getSkillTree(req, res));
router.post('/skill-tree/:userId/upgrade', (req, res) => skillTree.upgradeSkill(req, res));

// Social graph routes
router.get('/social/:userId/friends', (req, res) => socialGraph.getFriends(req, res));
router.post('/social/:userId/friends', (req, res) => socialGraph.addFriend(req, res));

// Time series routes
router.post('/time-series/record', (req, res) => timeSeries.recordData(req, res));
router.get('/time-series/:userId', (req, res) => timeSeries.getData(req, res));

module.exports = router;

