import express, { Router, Request, Response } from 'express';
import taskVersioningService from './taskVersioningService';
import dependencyGraphService from './dependencyGraphService';
import { speechHealth, synthesizeSpeech, transcribeAudio } from './speechClient';
import { secureLog } from '@team-deepiri/shared-utils';

const router: Router = express.Router();

router.get('/tasks', (req: Request, res: Response) => taskVersioningService.getTasks(req, res));
router.post('/tasks', (req: Request, res: Response) => taskVersioningService.createTask(req, res));
router.put('/tasks/:id', (req: Request, res: Response) => taskVersioningService.updateTask(req, res));
router.get('/tasks/:id/versions', (req: Request, res: Response) => taskVersioningService.getVersions(req, res));

router.get('/dependencies/:taskId', (req: Request, res: Response) => dependencyGraphService.getDependencies(req, res));
router.post('/dependencies', (req: Request, res: Response) => dependencyGraphService.addDependency(req, res));

/** Jobs/Truss batch path → deepiri-speech /v1/stt + /v1/tts */
router.get('/speech/health', async (_req: Request, res: Response) => {
  try {
    const health = await speechHealth();
    res.json({ ok: true, speech: health });
  } catch (err) {
    secureLog('error', 'speech health proxy failed', err);
    res.status(502).json({ ok: false, error: 'speech unreachable' });
  }
});

router.post('/speech/transcribe', async (req: Request, res: Response) => {
  try {
    const { audio_b64, filename, mime_type, language, session_id } = req.body || {};
    if (!audio_b64 || typeof audio_b64 !== 'string') {
      res.status(400).json({ error: 'audio_b64 required' });
      return;
    }
    const audio = Buffer.from(audio_b64, 'base64');
    const result = await transcribeAudio(audio, {
      filename: filename || 'audio.wav',
      mimeType: mime_type || 'audio/wav',
      language,
      sessionId: session_id,
    });
    res.json(result);
  } catch (err) {
    secureLog('error', 'speech transcribe proxy failed', err);
    res.status(502).json({ error: 'speech STT failed' });
  }
});

router.post('/speech/synthesize', async (req: Request, res: Response) => {
  try {
    const { text, voice, session_id } = req.body || {};
    if (!text || typeof text !== 'string') {
      res.status(400).json({ error: 'text required' });
      return;
    }
    const { audio, contentType } = await synthesizeSpeech(text, {
      voice,
      sessionId: session_id,
    });
    res.setHeader('Content-Type', contentType);
    res.send(Buffer.from(audio));
  } catch (err) {
    secureLog('error', 'speech synthesize proxy failed', err);
    res.status(502).json({ error: 'speech TTS failed' });
  }
});

/** Ingest lifecycle pings from deepiri-speech (best-effort). */
router.post('/speech/events', (req: Request, res: Response) => {
  secureLog('info', 'speech event', req.body || {});
  res.status(202).json({ accepted: true });
});

export default router;
