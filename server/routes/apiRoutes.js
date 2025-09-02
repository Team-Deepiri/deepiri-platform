const express = require('express');
const firebaseAdmin = require('firebase-admin');
const authenticateJWT = require('../middleware/authenticateJWT');
const { signUp, loginUser, getUserData } = require('../controllers/dataController');
const router = express.Router();

// Route for pinging the server
router.get('/ping', (req, res) => {
  res.send('Pong');
});

// Route for user sign-up
router.post('/sign-up', signUp); // Calls the sign-up controller function
router.post('/login', loginUser);

// Protected route for fetching user data
router.get('/user', authenticateJWT, getUserData);  // Authentication required

// No need for app.listen in this file, server.js handles it

module.exports = router;
