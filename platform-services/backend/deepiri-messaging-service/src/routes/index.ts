import { Router } from 'express';
import chatRoutes from './chatRoutes';
import messageRoutes from './messageRoutes';
import serviceRoutes from './serviceRoutes';
import notificationRoutes from './notificationRoutes';

const router = Router();

router.use('/chats', chatRoutes);
router.use('/', messageRoutes);
router.use('/service', serviceRoutes);
router.use('/notifications', notificationRoutes);

export default router;

