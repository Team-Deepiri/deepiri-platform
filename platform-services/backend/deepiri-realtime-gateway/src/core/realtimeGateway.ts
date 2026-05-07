import { Request, Response } from 'express';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { secureLog } from '@team-deepiri/shared-utils';

export type Channel = 'user' | 'party' | 'org' | 'global' | 'custom';

export interface Room {
  id: string;
  channel: Channel;
  name: string;
  members: Set<string>;
  metadata: Record<string, any>;
}

export interface Presence {
  odId: string;
  userId: string;
  status: 'online' | 'away' | 'offline';
  lastSeen: string;
}

export interface StreamCursor {
  streamId: string;
  userId: string;
  cursor: number;
  timestamp: string;
}

export interface EventEnvelope {
  id: string;
  channel: Channel;
  roomId?: string;
  eventType: string;
  payload: any;
  idempotencyKey: string;
  timestamp: string;
  deliveryGuarantee: 'at-most-once' | 'at-least-once' | 'exactly-once';
}

export interface RateLimitConfig {
  windowMs: number;
  maxEvents: number;
}

export interface RealtimeMetrics {
  connectedClients: number;
  activeRooms: number;
  messagesPerSecond: number;
  queueDepth: number;
  dropRate: number;
  reconnectRate: number;
}

export class RealtimeGatewayCore {
  private rooms: Map<string, Room> = new Map();
  private presence: Map<string, Presence> = new Map();
  private streamCursors: Map<string, StreamCursor> = new Map();
  private roomRateLimits: Map<string, RateLimitConfig> = new Map();
  private messageQueue: EventEnvelope[] = [];
  private metrics: RealtimeMetrics = {
    connectedClients: 0,
    activeRooms: 0,
    messagesPerSecond: 0,
    queueDepth: 0,
    dropRate: 0,
    reconnectRate: 0
  };

  joinRoom(socket: Socket, roomId: string, channel: Channel): void {
    const fullRoomId = `${channel}:${roomId}`;
    
    if (!this.rooms.has(fullRoomId)) {
      this.rooms.set(fullRoomId, {
        id: fullRoomId,
        channel,
        name: roomId,
        members: new Set(),
        metadata: {}
      });
    }
    
    const room = this.rooms.get(fullRoomId)!;
    room.members.add(socket.id);
    socket.join(fullRoomId);
    
    this.metrics.activeRooms = this.rooms.size;
    
    socket.to(fullRoomId).emit('user:joined', {
      odId: socket.id,
      roomId: fullRoomId,
      timestamp: new Date().toISOString()
    });
  }

  leaveRoom(socket: Socket, roomId: string, channel: Channel): void {
    const fullRoomId = `${channel}:${roomId}`;
    const room = this.rooms.get(fullRoomId);
    
    if (room) {
      room.members.delete(socket.id);
      socket.leave(fullRoomId);
      
      socket.to(fullRoomId).emit('user:left', {
        odId: socket.id,
        roomId: fullRoomId,
        timestamp: new Date().toISOString()
      });
      
      if (room.members.size === 0) {
        this.rooms.delete(fullRoomId);
      }
    }
    
    this.metrics.activeRooms = this.rooms.size;
  }

  emitToChannel(
    io: SocketIOServer,
    channel: Channel,
    roomId: string,
    eventType: string,
    payload: any,
    options?: {
      idempotencyKey?: string;
      deliveryGuarantee?: 'at-most-once' | 'at-least-once' | 'exactly-once';
    }
  ): string {
    const envelopeId = options?.idempotencyKey || `env-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const fullRoomId = `${channel}:${roomId}`;
    
    const envelope: EventEnvelope = {
      id: envelopeId,
      channel,
      roomId: fullRoomId,
      eventType,
      payload,
      idempotencyKey: envelopeId,
      timestamp: new Date().toISOString(),
      deliveryGuarantee: options?.deliveryGuarantee || 'at-most-once'
    };
    
    this.messageQueue.push(envelope);
    this.metrics.queueDepth = this.messageQueue.length;
    
    io.to(fullRoomId).emit(eventType, envelope);
    
    return envelopeId;
  }

  emitToUser(
    io: SocketIOServer,
    odId: string,
    eventType: string,
    payload: any,
    options?: { idempotencyKey?: string }
  ): string {
    const envelopeId = options?.idempotencyKey || `env-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    io.to(odId).emit(eventType, {
      id: envelopeId,
      eventType,
      payload,
      idempotencyKey: envelopeId,
      timestamp: new Date().toISOString()
    });
    
    return envelopeId;
  }

  emitToAll(io: SocketIOServer, eventType: string, payload: any): void {
    io.emit(eventType, payload);
  }

  broadcastPresence(socket: Socket, userId: string, status: 'online' | 'away' | 'offline'): void {
    this.presence.set(socket.id, {
      odId: socket.id,
      userId,
      status,
      lastSeen: new Date().toISOString()
    });
  }

  getRoomMembers(roomId: string, channel: Channel): string[] {
    const fullRoomId = `${channel}:${roomId}`;
    const room = this.rooms.get(fullRoomId);
    return room ? Array.from(room.members) : [];
  }

  getPresence(userId: string): Presence | undefined {
    for (const [, presence] of this.presence) {
      if (presence.userId === userId) {
        return presence;
      }
    }
    return undefined;
  }

  setRateLimit(roomId: string, config: RateLimitConfig): void {
    this.roomRateLimits.set(roomId, config);
  }

  checkRateLimit(roomId: string): boolean {
    const config = this.roomRateLimits.get(roomId);
    if (!config) return true;
    
    const now = Date.now();
    const recent = this.messageQueue.filter(
      m => m.roomId === roomId && now - new Date(m.timestamp).getTime() < config.windowMs
    );
    
    return recent.length < config.maxEvents;
  }

  getDurableStreamReplay(streamId: string, userId: string, limit: number = 100): EventEnvelope[] {
    const cursor = this.streamCursors.get(`${streamId}:${userId}`);
    const startIndex = cursor ? cursor.cursor : 0;
    
    return this.messageQueue
      .filter(m => m.channel === streamId)
      .slice(startIndex, startIndex + limit);
  }

  updateStreamCursor(streamId: string, userId: string, cursor: number): void {
    this.streamCursors.set(`${streamId}:${userId}`, {
      streamId,
      userId,
      cursor,
      timestamp: new Date().toISOString()
    });
  }

  getMetrics(): RealtimeMetrics {
    return { ...this.metrics };
  }

  handleConnection(socket: Socket): void {
    this.metrics.connectedClients++;
  }

  handleDisconnect(socket: Socket): void {
    this.metrics.connectedClients--;
    this.presence.delete(socket.id);
    
    for (const [roomId, room] of this.rooms) {
      if (room.members.has(socket.id)) {
        room.members.delete(socket.id);
        socket.to(roomId).emit('user:left', {
          odId: socket.id,
          roomId,
          timestamp: new Date().toISOString()
        });
      }
    }
  }
}

export const realtimeGateway = new RealtimeGatewayCore();

export async function handleEmitToChannel(req: Request, res: Response): Promise<void> {
  try {
    const { channel, roomId, eventType, payload, idempotencyKey, deliveryGuarantee } = req.body;
    
    const io = req.app.get('io') as SocketIOServer;
    if (!io) {
      throw new Error('Socket.IO not available');
    }
    
    const envelopeId = realtimeGateway.emitToChannel(
      io,
      channel,
      roomId,
      eventType,
      payload,
      { idempotencyKey, deliveryGuarantee }
    );
    
    res.json({ envelopeId });
  } catch (error: any) {
    secureLog('error', 'Emit to channel error:', error);
    res.status(500).json({ error: error.message });
  }
}

export async function handleGetRooms(req: Request, res: Response): Promise<void> {
  try {
    const { channel, roomId } = req.query;
    const members = realtimeGateway.getRoomMembers(roomId as string, channel as any);
    res.json({ channel, roomId, memberCount: members.length, members });
  } catch (error: any) {
    secureLog('error', 'Get rooms error:', error);
    res.status(500).json({ error: 'Failed to get rooms' });
  }
}

export async function handleGetPresence(req: Request, res: Response): Promise<void> {
  try {
    const { userId } = req.query;
    const presence = realtimeGateway.getPresence(userId as string);
    res.json(presence || { userId, status: 'offline' });
  } catch (error: any) {
    secureLog('error', 'Get presence error:', error);
    res.status(500).json({ error: 'Failed to get presence' });
  }
}

export async function handleGetMetrics(req: Request, res: Response): Promise<void> {
  try {
    const metrics = realtimeGateway.getMetrics();
    res.json(metrics);
  } catch (error: any) {
    secureLog('error', 'Get metrics error:', error);
    res.status(500).json({ error: 'Failed to get metrics' });
  }
}