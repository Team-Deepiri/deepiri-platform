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
    // req.user is set by the authenticate() middleware -- never trust a
    // client-supplied userId here, or any caller could read anyone's
    // notifications by passing a different id.
    const userId = req.user!.id;
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
    // Scope the update to the authenticated user's own notifications --
    // updating by id alone let any caller mark any user's notification as
    // read by guessing/enumerating ids.
    const result = await prisma.notification.updateMany({
      where: { id: req.params.id, userId: req.user!.id },
      data: { readAt: new Date() },
    });
    if (result.count === 0) {
      res.status(404).json({ error: 'Notification not found' });
      return;
    }
    res.json({ success: true });
  } catch (error: unknown) {
    secureLog('error', 'Mark notification read error:', error);
    res.status(500).json({ error: 'Failed to mark notification read' });
  }
}
