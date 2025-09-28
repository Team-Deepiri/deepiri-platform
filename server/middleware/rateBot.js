const rateLimit = require('express-rate-limit');

module.exports = function rateBot() {
  const limiter = rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
    keyGenerator: (req) => (req.user?.userId || req.ip),
    standardHeaders: true,
    legacyHeaders: false,
  });

  return function(req, res, next) {
    // Disable in non-production to avoid throttling local auth/dev flows
    if (process.env.NODE_ENV !== 'production') {
      return next();
    }

    // Do not apply this limiter to auth endpoints to prevent blocking login/register
    const path = req.path || '';
    if (path.startsWith('/api/auth')) {
      return next();
    }

    const ua = (req.get('User-Agent') || '').toLowerCase();
    if (ua.includes('bot') || ua.includes('crawler') || ua.includes('spider')) {
      return res.status(403).json({ success: false, message: 'Bots are not allowed' });
    }
    return limiter(req, res, next);
  };
};


