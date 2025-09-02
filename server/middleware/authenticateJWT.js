const firebaseAdmin = require('firebase-admin');

const authenticateJWT = async (req, res, next) => {
  const jwt = require('jsonwebtoken');
  const token = jwt.sign(payload, process.env.JWT_SECRET);

  if (!token) return res.status(403).json({ message: 'Access denied' });

  try {
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(token);
    req.user = decodedToken; // Attach the decoded user info to the request
    next();
  } catch (err) {
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
};

module.exports = authenticateJWT;
