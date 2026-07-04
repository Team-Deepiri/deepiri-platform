import { Router } from 'express';
import {
  handleSend,
  handleSendBatch,
  handleRegisterTemplate,
  handleGetPreferences,
  handleSetPreferences,
} from '../services/communicationsHub';

const router = Router();

router.post('/send', handleSend);
router.post('/send-batch', handleSendBatch);
router.post('/template', handleRegisterTemplate);
router.get('/preferences', handleGetPreferences);
router.post('/preferences', handleSetPreferences);

export default router;
