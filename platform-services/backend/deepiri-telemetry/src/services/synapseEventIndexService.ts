import { Request, Response } from 'express';

const MAX_EVENTS = 200;

export interface IndexedEvent {
  eventType: string;
  source: string;
  timestamp: string;
  data?: unknown;
}

// In-memory ring buffer, genuinely populated by eventConsumer.ts as real
// Synapse events arrive -- not fabricated sample data. Resets on restart,
// which is acceptable for a "recent events" feed (not a durable audit log;
// the durable path for anything that matters is InfluxDB via
// timeSeriesAnalytics, which this doesn't replace).
const recentEvents: IndexedEvent[] = [];

export function recordEvent(eventType: string, source: string, data?: unknown): void {
  recentEvents.push({ eventType, source, timestamp: new Date().toISOString(), data });
  if (recentEvents.length > MAX_EVENTS) {
    recentEvents.splice(0, recentEvents.length - MAX_EVENTS);
  }
}

export function getRecentEvents(limit = 50): IndexedEvent[] {
  return recentEvents.slice(-limit).reverse();
}

export async function handleGetRecentEvents(req: Request, res: Response): Promise<void> {
  const limit = Math.min(parseInt((req.query.limit as string) ?? '50', 10) || 50, MAX_EVENTS);
  res.json({ events: getRecentEvents(limit) });
}
