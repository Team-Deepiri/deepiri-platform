import { Server, Socket } from 'socket.io';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('websocket-service');

class WebSocketService {
  private io: Server | null = null;
  public connectedUsers: Map<string, string[]> = new Map();
  private userRooms: Map<string, Set<string>> = new Map();

  initialize(server: Server): void {
    this.io = server;

    this.io.on('connection', (socket: Socket) => {
      this._handleConnection(socket);
    });

    logger.info('WebSocket server initialized');
  }

  private _handleConnection(socket: Socket): void {
    socket.on('authenticate', (data: { userId: string }) => {
      const { userId } = data;
      if (userId) {
        this._addUserConnection(userId, socket.id);
        socket.join(`user:${userId}`);
        socket.emit('authenticated', { success: true });
        logger.info('User authenticated via WebSocket', { userId, socketId: socket.id });
      }
    });

    socket.on('disconnect', () => {
      this._removeUserConnection(socket.id);
      logger.info('User disconnected from WebSocket', { socketId: socket.id });
    });

    socket.on('subscribe', (room: string) => {
      socket.join(room);
      logger.debug('Socket subscribed to room', { socketId: socket.id, room });
    });

    socket.on('unsubscribe', (room: string) => {
      socket.leave(room);
      logger.debug('Socket unsubscribed from room', { socketId: socket.id, room });
    });
  }

  sendToUser(userId: string, notification: Record<string, any>): void {
    if (!this.io) {
      logger.warn('WebSocket server not initialized');
      return;
    }

    this.io.to(`user:${userId}`).emit('notification', notification);
    logger.info('Notification sent via WebSocket', { userId, type: notification.type });
  }

  sendToUsers(userIds: string[], notification: Record<string, any>): void {
    if (!this.io) {
      logger.warn('WebSocket server not initialized');
      return;
    }

    userIds.forEach(userId => {
      this.io!.to(`user:${userId}`).emit('notification', notification);
    });

    logger.info('Notification sent to multiple users', { count: userIds.length });
  }

  broadcastToRoom(room: string, notification: Record<string, any>): void {
    if (!this.io) {
      logger.warn('WebSocket server not initialized');
      return;
    }

    this.io.to(room).emit('notification', notification);
    logger.info('Notification broadcast to room', { room });
  }

  sendChallengeUpdate(userId: string, challengeId: string, update: Record<string, any>): void {
    this.sendToUser(userId, {
      type: 'challenge_update',
      challengeId,
      ...update
    });
  }

  sendProgressUpdate(userId: string, progress: Record<string, any>): void {
    this.sendToUser(userId, {
      type: 'progress_update',
      ...progress
    });
  }

  private _addUserConnection(userId: string, socketId: string): void {
    if (!this.connectedUsers.has(userId)) {
      this.connectedUsers.set(userId, []);
    }
    this.connectedUsers.get(userId)!.push(socketId);
  }

  private _removeUserConnection(socketId: string): void {
    for (const [userId, socketIds] of this.connectedUsers.entries()) {
      const index = socketIds.indexOf(socketId);
      if (index > -1) {
        socketIds.splice(index, 1);
        if (socketIds.length === 0) {
          this.connectedUsers.delete(userId);
        }
        break;
      }
    }
  }

  getConnectedUsers(): string[] {
    return Array.from(this.connectedUsers.keys());
  }

  isUserConnected(userId: string): boolean {
    return this.connectedUsers.has(userId) && this.connectedUsers.get(userId)!.length > 0;
  }
}

export default new WebSocketService();

