import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import dotenv from 'dotenv';
import { PlakyBridge } from './bridge';

dotenv.config();

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());

const PORT = parseInt(process.env.PORT || '5009', 10);
const INTERNAL_SECRET = process.env.INTERNAL_SERVICE_SECRET || process.env.PLAKY_BRIDGE_SECRET || '';

function requireInternalAuth(req: express.Request, res: express.Response, next: express.NextFunction) {
  if (!INTERNAL_SECRET) return next(); // open if no secret configured (dev)
  const provided = (req.headers['x-internal-secret'] as string) || (req.headers['x-api-key'] as string) || '';
  if (provided !== INTERNAL_SECRET) {
    return res.status(401).json({ success: false, error: 'Invalid internal secret' });
  }
  next();
}

const bridge = new PlakyBridge();

// Health — no auth
app.get('/health', (_req, res) => {
  res.json({ status: bridge.isReady ? 'ready' : 'initializing', service: 'deepiri-plaky-bridge', ts: new Date().toISOString() });
});

app.get('/status', (_req, res) => {
  res.json({
    status: bridge.isReady ? 'ready' : 'initializing',
    initialized: bridge.isReady,
    headless: true,
    gui: false,
    browser: !!process.env.PLAKY_EMAIL,
    apiKeyConfigured: !!(process.env.PLAKY_API_KEY || process.env.PLAKY_API_TOKEN),
  });
});

// Protected routes
app.post('/plaky/invite', requireInternalAuth, async (req, res) => {
  const { email, role } = req.body || {};
  if (!email) return res.status(400).json({ success: false, error: 'Missing email' });
  const result = await bridge.inviteUser(email, role || 'MEMBER');
  res.status(result.success ? 200 : result.error?.includes('Already') ? 409 : 500).json(result);
});

app.post('/plaky/kick', requireInternalAuth, async (req, res) => {
  const { email } = req.body || {};
  if (!email) return res.status(400).json({ success: false, error: 'Missing email' });
  const result = await bridge.kickUser(email);
  res.status(result.success ? 200 : 500).json(result);
});

app.post('/plaky/invite-batch', requireInternalAuth, async (req, res) => {
  const { emails, role } = req.body || {};
  if (!emails || !Array.isArray(emails)) return res.status(400).json({ success: false, error: 'Missing emails array' });
  const results = [];
  for (const email of emails) {
    const r = await bridge.inviteUser(email, role || 'MEMBER');
    results.push(r);
    await new Promise(r => setTimeout(r, 2000));
  }
  res.json({ success: true, results, total: results.length, successful: results.filter(r => r.success).length });
});

app.post('/plaky/kick-batch', requireInternalAuth, async (req, res) => {
  const { emails } = req.body || {};
  if (!emails || !Array.isArray(emails)) return res.status(400).json({ success: false, error: 'Missing emails array' });
  const results = [];
  for (const email of emails) {
    const r = await bridge.kickUser(email);
    results.push(r);
    await new Promise(r => setTimeout(r, 2000));
  }
  res.json({ success: true, results, total: results.length, successful: results.filter(r => r.success).length });
});

async function start() {
  try {
    await bridge.init();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`[PlakyBridge] Headless bridge listening on :${PORT} (GUI: false, headless: true)`);
      console.log(`[PlakyBridge] POST /plaky/invite  | POST /plaky/kick | POST /plaky/invite-batch | GET /status`);
    });
  } catch (e) {
    console.error('[PlakyBridge] Failed to start', e);
    process.exit(1);
  }
}

start();

process.on('SIGTERM', async () => {
  await bridge.close();
  process.exit(0);
});
process.on('SIGINT', async () => {
  await bridge.close();
  process.exit(0);
});
