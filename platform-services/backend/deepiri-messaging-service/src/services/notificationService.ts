import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { secureLog } from '@team-deepiri/shared-utils';
import { prisma } from '../db';

export async function createNotification(
  userId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, unknown> = {},
) {
  return prisma.notification.create({
    data: { userId, type, title, body, data: data as Prisma.InputJsonValue },
  });
}

export async function handleListNotifications(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req.query.userId as string) || (req.headers['x-user-id'] as string);
    if (!userId) {
      res.status(400).json({ error: 'userId query param or x-user-id header is required' });
      return;
    }
    const notifications = await prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json({ notifications });
  } catch (error: unknown) {
    secureLog('error', 'List notifications error:', error);
    res.status(500).json({ error: 'Failed to list notifications' });
  }
}

export async function handleMarkNotificationRead(req: Request, res: Response): Promise<void> {
  try {
    const notification = await prisma.notification.update({
      where: { id: req.params.id },
      data: { readAt: new Date() },
    });
    res.json(notification);
  } catch (error: unknown) {
    secureLog('error', 'Mark notification read error:', error);
    res.status(404).json({ error: 'Notification not found' });
  }
}
