import { Router } from 'express';
import chatRoutes from './chatRoutes';
import messageRoutes from './messageRoutes';
import serviceRoutes from './serviceRoutes';

const router = Router();

router.use('/chats', chatRoutes);
router.use('/', messageRoutes);
router.use('/service', serviceRoutes);

export default router;

