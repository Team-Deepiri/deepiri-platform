/**
 * Event Consumer for Realtime Gateway
 * Uses Synapse sidecar transport only.
 * Redis Streams access remains owned by the sidecar.
 */
import { request as httpRequest } from 'http';
import { request as httpsRequest } from 'https';
import { Server } from 'socket.io';
import { StreamEvent, StreamTopics, secureLog } from '@deepiri/shared-utils';

interface SubscriptionOptions {
  consumerGroup: string;
  consumerName: string;
  blockMs: number;
}

interface EventTransport {
  readonly name: string;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  subscribe(
    streamName: string,
    callback: (event: StreamEvent) => Promise<void> | void,
    options: SubscriptionOptions
  ): Promise<void>;
}

interface SidecarReadRequest {
  stream: string;
  consumer_group: string;
  consumer_name: string;
  count: number;
  block_ms: number;
}

interface SidecarReadEvent {
  stream: string;
  entry_id: string;
  fields: Record<string, unknown>;
}

interface SidecarReadResponse {
  events: SidecarReadEvent[];
}

interface SidecarAckRequest {
  stream: string;
  consumer_group: string;
  entry_ids: string[];
}

interface SidecarAckResponse {
  acked: number;
}

interface StreamSpec {
  stream: string;
  socketEvent: string;
}

const STREAM_SPECS: StreamSpec[] = [
  { stream: StreamTopics.INFERENCE_EVENTS, socketEvent: 'inference-event' },
  { stream: StreamTopics.PLATFORM_EVENTS, socketEvent: 'platform-event' },
  { stream: StreamTopics.MODEL_EVENTS, socketEvent: 'model-event' },
  { stream: StreamTopics.TRAINING_EVENTS, socketEvent: 'training-event' },
];

const PRIMARY_CONSUMER_GROUP = (process.env.STREAM_CONSUMER_GROUP || 'realtime-gateway').trim();
const PRIMARY_CONSUMER_NAME = (process.env.STREAM_CONSUMER_NAME || 'realtime-1').trim();
const BLOCK_MS = parsePositiveInt(process.env.STREAM_BLOCK_MS, 1000);
const SIDECAR_URL = process.env.SYNAPSE_SIDECAR_URL || 'http://synapse-sidecar:8081';

let isConsuming = false;
let io: Server | null = null;
let transport: EventTransport | null = null;

class SidecarEventTransport implements EventTransport {
  public readonly name: string = 'sidecar';
  private running: boolean = false;

  constructor(private readonly baseUrl: string) {}

  async connect(): Promise<void> {
    await this.requestJson<undefined, { ready: boolean }>('GET', '/readyz');
    this.running = true;
  }

  async disconnect(): Promise<void> {
    this.running = false;
  }

  async subscribe(
    streamName: string,
    callback: (event: StreamEvent) => Promise<void> | void,
    options: SubscriptionOptions
  ): Promise<void> {
    while (this.running) {
      try {
        const response = await this.requestJson<SidecarReadRequest, SidecarReadResponse>('POST', '/v1/read', {
          stream: streamName,
          consumer_group: options.consumerGroup,
          consumer_name: options.consumerName,
          count: 10,
          block_ms: options.blockMs,
        });

        const events = Array.isArray(response.events) ? response.events : [];
        for (const event of events) {
          const normalizedEvent = normalizeEvent(event.fields);
          await callback(normalizedEvent);

          await this.requestJson<SidecarAckRequest, SidecarAckResponse>('POST', '/v1/ack', {
            stream: event.stream || streamName,
            consumer_group: options.consumerGroup,
            entry_ids: [event.entry_id],
          });
        }
      } catch (error) {
        secureLog('error', `[SidecarTransport] subscription error for ${streamName}:`, error);
        await sleep(1000);
      }
    }
  }

  private async requestJson<TReq, TRes>(
    method: 'GET' | 'POST',
    path: string,
    payload?: TReq
  ): Promise<TRes> {
    const target = new URL(path, this.baseUrl);
    const isHttps = target.protocol === 'https:';
    const requester = isHttps ? httpsRequest : httpRequest;
    const body = payload ? JSON.stringify(payload) : '';

    const headers: Record<string, string> = {
      Accept: 'application/json',
    };
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(body).toString();
    }

    return new Promise<TRes>((resolve, reject) => {
      const req = requester(
        {
          method,
          hostname: target.hostname,
          port: target.port ? Number(target.port) : isHttps ? 443 : 80,
          path: `${target.pathname}${target.search}`,
          headers,
          timeout: 5000,
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => {
            const raw = Buffer.concat(chunks).toString('utf8');
            if ((res.statusCode || 500) >= 400) {
              reject(new Error(`sidecar request failed (${res.statusCode}): ${raw}`));
              return;
            }

            if (!raw) {
              resolve({} as TRes);
              return;
            }

            try {
              resolve(JSON.parse(raw) as TRes);
            } catch (error) {
              reject(new Error(`failed to parse sidecar response: ${String(error)}`));
            }
          });
        }
      );

      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy(new Error('sidecar request timed out'));
      });

      if (payload) {
        req.write(body);
      }
      req.end();
    });
  }
}

/**
 * Initialize and start consuming events.
 * Transport is sidecar-only by design.
 */
export async function startEventConsumption(socketIO: Server): Promise<void> {
  if (isConsuming) {
    secureLog('warn', 'Event consumption already started');
    return;
  }

  io = socketIO;
  const options: SubscriptionOptions = {
    consumerGroup: PRIMARY_CONSUMER_GROUP,
    consumerName: PRIMARY_CONSUMER_NAME,
    blockMs: BLOCK_MS,
  };

  try {
    transport = createTransport();
    await transport.connect();
    secureLog(
      'info',
      `[Realtime Gateway] Streaming backend: ${transport.name} (group=${options.consumerGroup}, consumer=${options.consumerName})`
    );

    for (const spec of STREAM_SPECS) {
      startStreamLoop(transport, spec, options).catch((error) => {
        secureLog('error', `[Realtime Gateway] ${spec.stream} consumption error:`, error);
      });
    }

    isConsuming = true;
    secureLog('info', '[Realtime Gateway] Event consumption started');
  } catch (error) {
    secureLog('error', '[Realtime Gateway] Failed to start event consumption:', error);
    throw error;
  }
}

/**
 * Stop event consumption.
 */
export async function stopEventConsumption(): Promise<void> {
  isConsuming = false;

  if (transport) {
    await transport.disconnect();
    transport = null;
  }

  secureLog('info', '[Realtime Gateway] Event consumption stopped');
}

function createTransport(): EventTransport {
  return new SidecarEventTransport(SIDECAR_URL);
}

async function startStreamLoop(
  eventTransport: EventTransport,
  spec: StreamSpec,
  options: SubscriptionOptions
): Promise<void> {
  await eventTransport.subscribe(
    spec.stream,
    async (event: StreamEvent) => {
      if (!io) {
        return;
      }

      if (event.user_id) {
        io.to(`user_${event.user_id}`).emit(spec.socketEvent, event);
      } else {
        io.emit(spec.socketEvent, event);
      }
    },
    {
      consumerGroup: options.consumerGroup,
      consumerName: `${options.consumerName}-${eventTransport.name}`,
      blockMs: options.blockMs,
    }
  );
}

function normalizeEvent(fields: Record<string, unknown>): StreamEvent {
  const event: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === 'string') {
      event[key] = tryParseJson(value);
    } else {
      event[key] = value;
    }
  }

  if (event.event === undefined && event.event_type !== undefined) {
    event.event = String(event.event_type);
  }
  if (event.timestamp === undefined) {
    event.timestamp = new Date().toISOString();
  }
  if (event.source === undefined) {
    event.source = 'synapse-sidecar';
  }

  return event as StreamEvent;
}

function tryParseJson(value: string): unknown {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
    (trimmed.startsWith('[') && trimmed.endsWith(']'))
  ) {
    try {
      return JSON.parse(trimmed);
    } catch {
      return value;
    }
  }
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parsePositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.floor(parsed);
}
