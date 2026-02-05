import { Router } from 'express';
import chatRoutes from './chatRoutes';
import messageRoutes from './messageRoutes';

const router = Router();

router.use('/chats', chatRoutes);
router.use('/', messageRoutes);

export default router;

