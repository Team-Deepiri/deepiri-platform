/**
 * Event Consumer for Realtime Gateway
 * Uses Synapse Sugar Glider transport (formerly sidecar).
 * Redis Streams access remains owned by the transport service.
 */
import fs from 'fs';
import path from 'path';
import { request as httpRequest } from 'http';
import { request as httpsRequest } from 'https';
import { Server } from 'socket.io';
import * as grpc from '@grpc/grpc-js';
import * as protoLoader from '@grpc/proto-loader';
import { StreamEvent, StreamTopics, secureLog } from '@team-deepiri/shared-utils';

interface SubscriptionOptions {
  consumerGroup: string;
  consumerName: string;
  blockMs: number;
}

interface EventDispatchTiming {
  dispatchNs?: number;
  emitNs?: number;
}

type EventDispatchCallback = (event: StreamEvent) => Promise<EventDispatchTiming | void> | EventDispatchTiming | void;

interface EventTransport {
  readonly name: string;
  readonly displayName?: string;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  subscribe(
    streamName: string,
    callback: EventDispatchCallback,
    options: SubscriptionOptions
  ): Promise<void>;
}

interface SugarGliderReadRequest {
  stream: string;
  consumer_group: string;
  consumer_name: string;
  count: number;
  block_ms: number;
}

interface SugarGliderReadEvent {
  stream: string;
  entry_id: string;
  fields: Record<string, unknown>;
}

interface SugarGliderReadResponse {
  events: SugarGliderReadEvent[];
}

interface SugarGliderAckRequest {
  stream: string;
  consumer_group: string;
  entry_ids: string[];
}

interface SugarGliderAckResponse {
  acked: number;
}

interface GrpcSubscribeRequest {
  stream: string;
  consumer_group: string;
  consumer_name: string;
  batch_size: number;
}

interface GrpcEvent {
  stream: string;
  entry_id: string;
  event_type: string;
  sender: string;
  payload: Buffer | Uint8Array;
  timestamp: string;
}

interface GrpcAckRequest {
  stream: string;
  consumer_group: string;
  entry_ids: string[];
}

interface GrpcAckResponse {
  acked: number;
}

interface GrpcHealthResponse {
  healthy: boolean;
  redis_status: string;
}

interface SynapseSidecarClient extends grpc.Client {
  Subscribe(request: GrpcSubscribeRequest): grpc.ClientReadableStream<GrpcEvent>;
  Ack(
    request: GrpcAckRequest,
    callback: (error: grpc.ServiceError | null, response: GrpcAckResponse) => void
  ): grpc.ClientUnaryCall;
  Health(
    request: Record<string, never>,
    callback: (error: grpc.ServiceError | null, response: GrpcHealthResponse) => void
  ): grpc.ClientUnaryCall;
}

interface StreamSpec {
  stream: string;
  socketEvent: string;
}

type StreamTransportSetting = 'sugar-glider-http' | 'sugar-glider-grpc';
type BroadcastFastPathMode = 'off' | 'payload' | 'payload-json';
type RuntimeLaneName = 'small' | 'mid' | 'heavy' | 'unknown';
type RuntimeLaneSource = 'bench-scenario' | 'payload-size' | 'disabled' | 'unknown';

type RuntimeLaneDecision = {
  lane: RuntimeLaneName;
  payloadBytes: number | null;
  source: RuntimeLaneSource;
};

const STREAM_SPECS: StreamSpec[] = [
  { stream: StreamTopics.INFERENCE_EVENTS, socketEvent: 'inference-event' },
  { stream: StreamTopics.PLATFORM_EVENTS, socketEvent: 'platform-event' },
  { stream: StreamTopics.MODEL_EVENTS, socketEvent: 'model-event' },
  { stream: StreamTopics.TRAINING_EVENTS, socketEvent: 'training-event' },
];

const STREAM_SHADOW_MODE = parseBoolean(process.env.STREAM_SHADOW_MODE, false);
const PRIMARY_CONSUMER_GROUP = resolveConsumerGroup(process.env.STREAM_CONSUMER_GROUP, STREAM_SHADOW_MODE);
const PRIMARY_CONSUMER_NAME = (process.env.STREAM_CONSUMER_NAME || 'realtime-1').trim();
const BLOCK_MS = parsePositiveInt(process.env.STREAM_BLOCK_MS, 1000);
const SUBSCRIBE_BATCH_SIZE = parsePositiveInt(process.env.STREAM_SUBSCRIBE_BATCH_SIZE, 128);
const STREAM_EVENT_MAX_IN_FLIGHT = parsePositiveInt(process.env.STREAM_EVENT_MAX_IN_FLIGHT, 1024);
const STREAM_EVENT_RESUME_IN_FLIGHT = parsePositiveInt(
  process.env.STREAM_EVENT_RESUME_IN_FLIGHT,
  Math.max(1, Math.floor(STREAM_EVENT_MAX_IN_FLIGHT * 0.75))
);
const SUGAR_GLIDER_URL =
  process.env.SYNAPSE_SUGAR_GLIDER_URL ||
  process.env.SYNAPSE_SIDECAR_URL ||
  'http://synapse-sugar-glider:8081';
const SUGAR_GLIDER_GRPC_ADDR = (process.env.SYNAPSE_GRPC_ADDR || 'synapse-sugar-glider:50051').trim();
const STREAM_TRANSPORT_RAW = (process.env.STREAM_TRANSPORT || '').trim();
const STREAM_TRANSPORT = parseStreamTransport(STREAM_TRANSPORT_RAW);
const STREAM_GRPC_KEEPALIVE_MS = parsePositiveInt(process.env.STREAM_GRPC_KEEPALIVE_MS, 300000);
const STREAM_GRPC_KEEPALIVE_TIMEOUT_MS = parsePositiveInt(
  process.env.STREAM_GRPC_KEEPALIVE_TIMEOUT_MS,
  20000
);
const STREAM_GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS = parseBoolean(
  process.env.STREAM_GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS,
  false
);
const STREAM_ACK_BATCH_SIZE = parsePositiveInt(process.env.STREAM_ACK_BATCH_SIZE, 256);
const STREAM_ACK_FLUSH_MS = parsePositiveInt(process.env.STREAM_ACK_FLUSH_MS, 6);
const STREAM_ACK_FLUSH_CONCURRENCY = parsePositiveInt(process.env.STREAM_ACK_FLUSH_CONCURRENCY, 8);
const STREAM_ACK_RETRY_MAX_ATTEMPTS = parsePositiveInt(process.env.STREAM_ACK_RETRY_MAX_ATTEMPTS, 3);
const STREAM_ACK_RETRY_BASE_MS = parsePositiveInt(process.env.STREAM_ACK_RETRY_BASE_MS, 25);
const STREAM_ACK_LOW_TRAFFIC_FLUSH_MS = parseNonNegativeInt(
  process.env.STREAM_ACK_LOW_TRAFFIC_FLUSH_MS,
  1
);
const STREAM_ACK_LOW_TRAFFIC_GAP_MS = parsePositiveInt(
  process.env.STREAM_ACK_LOW_TRAFFIC_GAP_MS,
  16
);
const STREAM_ACK_LOW_TRAFFIC_MAX_PENDING = parsePositiveInt(
  process.env.STREAM_ACK_LOW_TRAFFIC_MAX_PENDING,
  Math.max(1, Math.floor(STREAM_ACK_BATCH_SIZE / 8))
);
const STREAM_LAZY_PAYLOAD_PARSE = parseBoolean(process.env.STREAM_LAZY_PAYLOAD_PARSE, true);
const STREAM_EXTRACT_USER_FROM_PAYLOAD = parseBoolean(
  process.env.STREAM_EXTRACT_USER_FROM_PAYLOAD,
  true
);
const STREAM_LANE_RUNTIME_PROFILES_ENABLED = parseBoolean(
  process.env.STREAM_LANE_RUNTIME_PROFILES_ENABLED,
  false
);
const STREAM_DIRECT_BROADCAST_FAST_PATH = parseBroadcastFastPathMode(
  process.env.STREAM_DIRECT_BROADCAST_FAST_PATH
);
const STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES = parseNonNegativeInt(
  process.env.STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES,
  0
);
const STREAM_SOCKET_HOTPATH_PROFILE_ENABLED = parseBoolean(
  process.env.STREAM_SOCKET_HOTPATH_PROFILE_ENABLED,
  false
);
const STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS_RAW =
  (process.env.STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS || '32768:10,32768:50').trim();
const STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT = parsePositiveInt(
  process.env.STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT,
  2048
);

const ROUTING_KEY_REGEX = /"(?:user_id|userId|recipient|recipient_id|recipientId)"/;
const BENCH_SCENARIO_ID_REGEX = /"bench_scenario_id"\s*:\s*"([^"]+)"/;
const BENCH_SCENARIO_BUCKET_REGEX = /(?:^|-)p(\d+)-c(\d+)(?:-|$)/i;

let isConsuming = false;
let io: Server | null = null;
let transport: EventTransport | null = null;
let sidecarClientConstructor: grpc.ServiceClientConstructor | null = null;
let runtimeProfileEvents = 0;
let runtimeProfileDirectBroadcastEvents = 0;
const runtimeProfileLaneCounts = new Map<string, number>();
const runtimeProfileDirectBroadcastLaneCounts = new Map<string, number>();

type StageAccumulator = {
  totalNs: number;
  maxNs: number;
  samplesNs: number[];
};

type SocketHotPathBucketAccumulator = {
  payloadBytes: number;
  concurrency: number;
  events: number;
  parse: StageAccumulator;
  dispatch: StageAccumulator;
  emit: StageAccumulator;
  streamCounts: Map<string, number>;
  socketEventCounts: Map<string, number>;
  lastUpdatedUtc: string;
};

type SocketHotPathBucket = {
  key: string;
  payloadBytes: number;
  concurrency: number;
};

type StageTimingSnapshot = {
  avg_ms: number;
  p95_ms: number;
  max_ms: number;
  total_ms: number;
  sample_count: number;
};

type BucketTimingSnapshot = {
  payload_bytes: number;
  concurrency: number;
  bucket: string;
  events: number;
  parse: StageTimingSnapshot;
  dispatch: StageTimingSnapshot;
  emit: StageTimingSnapshot;
  stream_counts: Record<string, number>;
  socket_event_counts: Record<string, number>;
  last_updated_utc: string;
};

export type SocketHotPathProfileSnapshot = {
  enabled: boolean;
  bucket_targets: string[];
  track_all_buckets: boolean;
  sample_limit: number;
  total_events_tracked: number;
  bucket_count: number;
  last_reset_utc: string;
  buckets: BucketTimingSnapshot[];
};

export type RuntimeBreakthroughSnapshot = {
  lane_runtime_profiles_enabled: boolean;
  direct_broadcast_fast_path: {
    mode: BroadcastFastPathMode;
    min_payload_bytes: number;
    active: boolean;
    requires_extract_user_from_payload_false: boolean;
  };
  lane_profiles: Array<{
    lane: RuntimeLaneName;
    min_payload_bytes: number;
    max_payload_bytes: number | null;
  }>;
  counters: {
    evaluated_events: number;
    direct_broadcast_events: number;
    lane_counts: Record<string, number>;
    direct_broadcast_lane_counts: Record<string, number>;
  };
};

class SocketHotPathProfiler {
  private readonly enabled: boolean;
  private readonly sampleLimit: number;
  private readonly trackAllBuckets: boolean;
  private readonly targetBuckets: Set<string>;
  private readonly bucketAccumulators: Map<string, SocketHotPathBucketAccumulator> = new Map();
  private lastResetUtc: string = new Date().toISOString();

  constructor(params: { enabled: boolean; bucketTargetsRaw: string; sampleLimit: number }) {
    this.enabled = params.enabled;
    this.sampleLimit = Math.max(1, params.sampleLimit);
    const parsedTargets = parseSocketHotPathBucketTargets(params.bucketTargetsRaw);
    this.trackAllBuckets = parsedTargets.trackAll;
    this.targetBuckets = parsedTargets.targets;
  }

  public snapshot(): SocketHotPathProfileSnapshot {
    const buckets = Array.from(this.bucketAccumulators.entries())
      .sort((a, b) => compareBucketKeys(a[0], b[0]))
      .map(([key, bucket]) => ({
        payload_bytes: bucket.payloadBytes,
        concurrency: bucket.concurrency,
        bucket: key,
        events: bucket.events,
        parse: stageSnapshot(bucket.parse, bucket.events),
        dispatch: stageSnapshot(bucket.dispatch, bucket.events),
        emit: stageSnapshot(bucket.emit, bucket.events),
        stream_counts: mapToObject(bucket.streamCounts),
        socket_event_counts: mapToObject(bucket.socketEventCounts),
        last_updated_utc: bucket.lastUpdatedUtc,
      }));

    const totalEventsTracked = buckets.reduce((sum, bucket) => sum + bucket.events, 0);
    return {
      enabled: this.enabled,
      bucket_targets: this.trackAllBuckets ? ['*'] : [...this.targetBuckets].sort(),
      track_all_buckets: this.trackAllBuckets,
      sample_limit: this.sampleLimit,
      total_events_tracked: totalEventsTracked,
      bucket_count: buckets.length,
      last_reset_utc: this.lastResetUtc,
      buckets,
    };
  }

  public configSummary(): string {
    const bucketSummary = this.trackAllBuckets ? '*' : [...this.targetBuckets].sort().join(',');
    return `enabled=${this.enabled}, buckets=${bucketSummary || 'none'}, sample_limit=${this.sampleLimit}`;
  }

  public deriveBucket(event: StreamEvent): SocketHotPathBucket | null {
    if (!this.enabled) {
      return null;
    }
    const scenarioId = extractBenchScenarioId(event);
    if (!scenarioId) {
      return null;
    }
    const match = BENCH_SCENARIO_BUCKET_REGEX.exec(scenarioId);
    if (!match) {
      return null;
    }
    const payloadBytes = Number(match[1]);
    const concurrency = Number(match[2]);
    if (!Number.isFinite(payloadBytes) || !Number.isFinite(concurrency) || payloadBytes <= 0 || concurrency <= 0) {
      return null;
    }
    const key = `${payloadBytes}:${concurrency}`;
    if (!this.trackAllBuckets && !this.targetBuckets.has(key)) {
      return null;
    }
    return {
      key,
      payloadBytes,
      concurrency,
    };
  }

  public record(params: {
    stream: string;
    socketEvent: string;
    bucket: SocketHotPathBucket | null;
    parseNs: number;
    dispatchNs: number;
    emitNs: number;
  }): void {
    if (!this.enabled || !params.bucket) {
      return;
    }

    const safeParseNs = sanitizeDurationNs(params.parseNs);
    const safeDispatchNs = sanitizeDurationNs(params.dispatchNs);
    const safeEmitNs = sanitizeDurationNs(params.emitNs);

    const bucket = this.getOrCreateBucket(params.bucket);
    bucket.events += 1;
    bucket.lastUpdatedUtc = new Date().toISOString();
    incrementMapCount(bucket.streamCounts, params.stream || 'unknown');
    incrementMapCount(bucket.socketEventCounts, params.socketEvent || 'unknown');
    applyStageSample(bucket.parse, safeParseNs, bucket.events, this.sampleLimit);
    applyStageSample(bucket.dispatch, safeDispatchNs, bucket.events, this.sampleLimit);
    applyStageSample(bucket.emit, safeEmitNs, bucket.events, this.sampleLimit);
  }

  private getOrCreateBucket(bucket: SocketHotPathBucket): SocketHotPathBucketAccumulator {
    const existing = this.bucketAccumulators.get(bucket.key);
    if (existing) {
      return existing;
    }
    const created: SocketHotPathBucketAccumulator = {
      payloadBytes: bucket.payloadBytes,
      concurrency: bucket.concurrency,
      events: 0,
      parse: createStageAccumulator(),
      dispatch: createStageAccumulator(),
      emit: createStageAccumulator(),
      streamCounts: new Map(),
      socketEventCounts: new Map(),
      lastUpdatedUtc: new Date().toISOString(),
    };
    this.bucketAccumulators.set(bucket.key, created);
    return created;
  }
}

const socketHotPathProfiler = new SocketHotPathProfiler({
  enabled: STREAM_SOCKET_HOTPATH_PROFILE_ENABLED,
  bucketTargetsRaw: STREAM_SOCKET_HOTPATH_PROFILE_BUCKETS_RAW,
  sampleLimit: STREAM_SOCKET_HOTPATH_PROFILE_SAMPLE_LIMIT,
});

class SugarGliderHttpEventTransport implements EventTransport {
  public readonly name: string = 'sugar-glider-http';
  public readonly displayName: string = 'sugar-glider-http';
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
    callback: EventDispatchCallback,
    options: SubscriptionOptions
  ): Promise<void> {
    while (this.running) {
      try {
        const response = await this.requestJson<SugarGliderReadRequest, SugarGliderReadResponse>('POST', '/v1/read', {
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

          await this.requestJson<SugarGliderAckRequest, SugarGliderAckResponse>('POST', '/v1/ack', {
            stream: event.stream || streamName,
            consumer_group: options.consumerGroup,
            entry_ids: [event.entry_id],
          });
        }
      } catch (error) {
        secureLog('error', `[SugarGliderHttpTransport] subscription error for ${streamName}:`, error);
        await sleep(1000);
      }
    }
  }

  private async requestJson<TReq, TRes>(
    method: 'GET' | 'POST',
    pathName: string,
    payload?: TReq
  ): Promise<TRes> {
    const target = new URL(pathName, this.baseUrl);
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
              reject(new Error(`sugar glider request failed (${res.statusCode}): ${raw}`));
              return;
            }

            if (!raw) {
              resolve({} as TRes);
              return;
            }

            try {
              resolve(JSON.parse(raw) as TRes);
            } catch (error) {
              reject(new Error(`failed to parse sugar glider response: ${String(error)}`));
            }
          });
        }
      );

      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy(new Error('sugar glider request timed out'));
      });

      if (payload) {
        req.write(body);
      }
      req.end();
    });
  }
}

class SugarGliderGrpcEventTransport implements EventTransport {
  public readonly name: string = 'sugar-glider-grpc';
  public readonly displayName: string = 'sugar-glider-grpc';
  private running: boolean = false;
  private client: SynapseSidecarClient | null = null;
  private pendingAcks: Map<
    string,
    {
      stream: string;
      consumerGroup: string;
      entryIds: string[];
    }
  > = new Map();
  private ackFlushTimer: NodeJS.Timeout | null = null;
  private ackFlushDeadlineMs: number = 0;
  private ackFlushInFlight: Promise<void> | null = null;
  private pendingAckEntries: number = 0;
  private lastAckQueuedAtMs: number = 0;

  constructor(private readonly address: string) {}

  async connect(): Promise<void> {
    const SidecarClient = getSynapseSidecarClientConstructor();
    this.client = new SidecarClient(this.address, grpc.credentials.createInsecure(), {
      'grpc.keepalive_time_ms': STREAM_GRPC_KEEPALIVE_MS,
      'grpc.keepalive_timeout_ms': STREAM_GRPC_KEEPALIVE_TIMEOUT_MS,
      'grpc.keepalive_permit_without_calls': STREAM_GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS ? 1 : 0,
      'grpc.http2.min_time_between_pings_ms': STREAM_GRPC_KEEPALIVE_MS,
    }) as unknown as SynapseSidecarClient;
    const client = this.requireClient();

    await new Promise<void>((resolve, reject) => {
      client.waitForReady(Date.now() + 5000, (error?: Error | null) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });

    const health = await this.healthCheck();
    if (!health.healthy) {
      throw new Error(`gRPC health check failed: redis_status=${health.redis_status}`);
    }

    this.running = true;
  }

  async disconnect(): Promise<void> {
    this.running = false;
    await this.flushAcks();
    if (this.client) {
      this.client.close();
      this.client = null;
    }
  }

  async subscribe(
    streamName: string,
    callback: EventDispatchCallback,
    options: SubscriptionOptions
  ): Promise<void> {
    while (this.running) {
      try {
        await this.consumeStream(streamName, callback, options);
      } catch (error) {
        if (!this.running) {
          break;
        }
        secureLog('error', `[SugarGliderGrpcTransport] subscription error for ${streamName}:`, error);
        await sleep(500);
      }
    }
  }

  private async consumeStream(
    streamName: string,
    callback: EventDispatchCallback,
    options: SubscriptionOptions
  ): Promise<void> {
    const client = this.requireClient();

    await new Promise<void>((resolve, reject) => {
      const grpcStream = client.Subscribe({
        stream: streamName,
        consumer_group: options.consumerGroup,
        consumer_name: options.consumerName,
        batch_size: SUBSCRIBE_BATCH_SIZE,
      });

      let inFlight = 0;
      let finished = false;
      let pendingError: Error | undefined;
      let drainResolver: (() => void) | null = null;
      let paused = false;

      const maybePause = (): void => {
        if (!paused && inFlight >= STREAM_EVENT_MAX_IN_FLIGHT) {
          grpcStream.pause();
          paused = true;
        }
      };

      const maybeResume = (): void => {
        if (paused && inFlight <= STREAM_EVENT_RESUME_IN_FLIGHT) {
          grpcStream.resume();
          paused = false;
        }
      };

      const waitForDrain = async (): Promise<void> => {
        if (inFlight === 0) {
          return;
        }
        await new Promise<void>((resolveDrain) => {
          drainResolver = resolveDrain;
        });
      };

      const markDone = (): void => {
        inFlight = Math.max(0, inFlight - 1);
        maybeResume();
        if (inFlight === 0 && drainResolver) {
          const resolveDrain = drainResolver;
          drainResolver = null;
          resolveDrain();
        }
      };

      const finalize = (error?: Error): void => {
        if (error && !pendingError) {
          pendingError = error;
        }
        if (finished) {
          return;
        }
        finished = true;

        Promise.resolve()
          .then(() => waitForDrain())
          .then(async () => {
            await this.flushAcks();
          })
          .then(() => {
            if (pendingError) {
              reject(pendingError);
              return;
            }
            resolve();
          })
          .catch(reject);
      };

      grpcStream.on('data', (event: GrpcEvent) => {
        inFlight += 1;
        maybePause();

        void this.handleIncomingEvent(streamName, options.consumerGroup, event, callback)
          .catch((error) => {
            secureLog('error', `[SugarGliderGrpcTransport] event processing error for ${streamName}:`, error);
          })
          .finally(() => {
            markDone();
          });
      });

      grpcStream.on('end', () => finalize());
      grpcStream.on('close', () => finalize());
      grpcStream.on('error', (error: Error) => {
        if (!this.running) {
          finalize();
          return;
        }
        finalize(error);
      });
    });
  }

  private async ack(request: GrpcAckRequest): Promise<number> {
    const client = this.requireClient();
    return new Promise<number>((resolve, reject) => {
      client.Ack(request, (error: grpc.ServiceError | null, response: GrpcAckResponse) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(response?.acked ?? 0);
      });
    });
  }

  private queueAck(request: GrpcAckRequest): void {
    const stream = request.stream || '';
    const consumerGroup = request.consumer_group || '';
    if (!stream || !consumerGroup) {
      return;
    }

    const key = `${stream}|${consumerGroup}`;
    let bucket = this.pendingAcks.get(key);
    if (!bucket) {
      bucket = {
        stream,
        consumerGroup,
        entryIds: [],
      };
      this.pendingAcks.set(key, bucket);
    }

    const ids = request.entry_ids || [];
    for (let i = 0; i < ids.length; i += 1) {
      const entryId = ids[i];
      if (entryId) {
        bucket.entryIds.push(entryId);
        this.pendingAckEntries += 1;
      }
    }

    if (bucket.entryIds.length >= STREAM_ACK_BATCH_SIZE) {
      void this.flushAcks();
      return;
    }

    const nowMs = Date.now();
    const gapMs =
      this.lastAckQueuedAtMs > 0 ? Math.max(0, nowMs - this.lastAckQueuedAtMs) : Number.POSITIVE_INFINITY;
    this.lastAckQueuedAtMs = nowMs;

    if (this.shouldUseLowTrafficFlush(gapMs)) {
      this.scheduleAckFlush(STREAM_ACK_LOW_TRAFFIC_FLUSH_MS);
      return;
    }

    this.scheduleAckFlush(STREAM_ACK_FLUSH_MS);
  }

  private scheduleAckFlush(delayMs: number): void {
    const safeDelayMs = Math.max(0, delayMs);
    const nextDeadlineMs = Date.now() + safeDelayMs;
    if (this.ackFlushTimer && this.ackFlushDeadlineMs > 0 && this.ackFlushDeadlineMs <= nextDeadlineMs) {
      return;
    }

    if (this.ackFlushTimer) {
      clearTimeout(this.ackFlushTimer);
    }
    this.ackFlushDeadlineMs = nextDeadlineMs;

    this.ackFlushTimer = setTimeout(() => {
      this.ackFlushTimer = null;
      this.ackFlushDeadlineMs = 0;
      void this.flushAcks();
    }, safeDelayMs);
  }

  private async flushAcks(): Promise<void> {
    if (this.ackFlushInFlight) {
      await this.ackFlushInFlight;
      return;
    }
    if (this.pendingAcks.size === 0) {
      return;
    }

    if (this.ackFlushTimer) {
      clearTimeout(this.ackFlushTimer);
      this.ackFlushTimer = null;
    }
    this.ackFlushDeadlineMs = 0;

    const snapshot = this.pendingAcks;
    this.pendingAcks = new Map();
    this.pendingAckEntries = 0;

    const buckets = Array.from(snapshot.values());
    this.ackFlushInFlight = Promise.all(
      buckets.map(async (bucket) => {
        await this.flushAckBucket(bucket);
      })
    ).then(() => undefined);

    try {
      await this.ackFlushInFlight;
    } finally {
      this.ackFlushInFlight = null;
      if (this.pendingAcks.size > 0) {
        this.scheduleAckFlush(0);
      }
    }
  }

  private shouldUseLowTrafficFlush(gapMs: number): boolean {
    if (STREAM_ACK_LOW_TRAFFIC_FLUSH_MS >= STREAM_ACK_FLUSH_MS) {
      return false;
    }
    if (gapMs < STREAM_ACK_LOW_TRAFFIC_GAP_MS) {
      return false;
    }
    return this.pendingAckEntries <= STREAM_ACK_LOW_TRAFFIC_MAX_PENDING;
  }

  private async flushAckBucket(bucket: {
    stream: string;
    consumerGroup: string;
    entryIds: string[];
  }): Promise<void> {
    const entryIds = bucket.entryIds;
    if (!entryIds.length) {
      return;
    }

    const chunks = chunkArray(entryIds, STREAM_ACK_BATCH_SIZE);
    let nextIndex = 0;
    const workerCount = Math.min(STREAM_ACK_FLUSH_CONCURRENCY, chunks.length);

    const workers = Array.from({ length: workerCount }, async () => {
      while (nextIndex < chunks.length) {
        const chunk = chunks[nextIndex];
        nextIndex += 1;
        try {
          const acked = await this.ackChunkWithRetry(bucket.stream, bucket.consumerGroup, chunk);
          if (acked <= 0) {
            secureLog(
              'warn',
              `[SugarGliderGrpcTransport] ack returned 0 for ${bucket.stream} entries=${chunk.length}`
            );
          }
        } catch (error) {
          secureLog(
            'error',
            `[SugarGliderGrpcTransport] ack flush failed for ${bucket.stream} entries=${chunk.length}:`,
            error
          );
        }
      }
    });

    await Promise.all(workers);
  }

  private async handleIncomingEvent(
    streamName: string,
    consumerGroup: string,
    event: GrpcEvent,
    callback: EventDispatchCallback
  ): Promise<void> {
    if (STREAM_SHADOW_MODE) {
      this.queueAck({
        stream: event.stream || streamName,
        consumer_group: consumerGroup,
        entry_ids: [event.entry_id],
      });
      return;
    }

    const parseStartNs = nowHrTimeNs();
    const normalizedEvent = normalizeGrpcEvent(event);
    const parseNs = elapsedNs(parseStartNs);
    const bucket = socketHotPathProfiler.deriveBucket(normalizedEvent);
    const dispatchTiming = await callback(normalizedEvent);
    const stream = event.stream || streamName;
    const socketEvent = resolveSocketEventName(streamName);
    socketHotPathProfiler.record({
      stream,
      socketEvent,
      bucket,
      parseNs,
      dispatchNs: sanitizeDurationNs(dispatchTiming?.dispatchNs),
      emitNs: sanitizeDurationNs(dispatchTiming?.emitNs),
    });

    this.queueAck({
      stream: event.stream || streamName,
      consumer_group: consumerGroup,
      entry_ids: [event.entry_id],
    });
  }

  private async ackChunkWithRetry(stream: string, consumerGroup: string, entryIds: string[]): Promise<number> {
    let attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await this.ack({
          stream,
          consumer_group: consumerGroup,
          entry_ids: entryIds,
        });
      } catch (error) {
        if (attempt >= STREAM_ACK_RETRY_MAX_ATTEMPTS) {
          throw error;
        }
        await sleep(STREAM_ACK_RETRY_BASE_MS * attempt);
      }
    }
  }

  private async healthCheck(): Promise<GrpcHealthResponse> {
    const client = this.requireClient();
    return new Promise<GrpcHealthResponse>((resolve, reject) => {
      client.Health({}, (error: grpc.ServiceError | null, response: GrpcHealthResponse) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(response);
      });
    });
  }

  private requireClient(): SynapseSidecarClient {
    if (!this.client) {
      throw new Error('gRPC client is not initialized');
    }
    return this.client;
  }
}

/**
 * Initialize and start consuming events.
 * Transport is Sugar Glider only by design.
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
    if (!STREAM_TRANSPORT_RAW) {
      secureLog(
        'warn',
        '[Realtime Gateway] STREAM_TRANSPORT is not set explicitly. Falling back to sugar-glider-grpc.'
      );
    }
    if (STREAM_SHADOW_MODE && PRIMARY_CONSUMER_GROUP === 'realtime-gateway') {
      secureLog(
        'warn',
        '[Realtime Gateway] STREAM_SHADOW_MODE=true is using STREAM_CONSUMER_GROUP=realtime-gateway. ' +
          'Prefer realtime-gateway-sg-canary to avoid consuming from the primary group.'
      );
    }

    transport = createTransport();
    await transport.connect();
    secureLog(
      'info',
      `[Realtime Gateway] Streaming backend: ${transport.displayName || transport.name} ` +
        `(group=${options.consumerGroup}, consumer=${options.consumerName}, shadow_mode=${STREAM_SHADOW_MODE}, ` +
        `transport_explicit=${STREAM_TRANSPORT_RAW.length > 0}, ` +
        `grpc_keepalive_ms=${STREAM_GRPC_KEEPALIVE_MS}, ` +
        `grpc_keepalive_timeout_ms=${STREAM_GRPC_KEEPALIVE_TIMEOUT_MS}, ` +
        `grpc_keepalive_permit_without_calls=${STREAM_GRPC_KEEPALIVE_PERMIT_WITHOUT_CALLS}, ` +
        `subscribe_batch_size=${SUBSCRIBE_BATCH_SIZE}, ` +
        `event_max_in_flight=${STREAM_EVENT_MAX_IN_FLIGHT}, ` +
        `event_resume_in_flight=${STREAM_EVENT_RESUME_IN_FLIGHT}, ` +
        `ack_batch_size=${STREAM_ACK_BATCH_SIZE}, ack_flush_ms=${STREAM_ACK_FLUSH_MS}, ` +
        `ack_flush_concurrency=${STREAM_ACK_FLUSH_CONCURRENCY}, ` +
        `ack_retry_max_attempts=${STREAM_ACK_RETRY_MAX_ATTEMPTS}, ` +
        `ack_low_traffic_flush_ms=${STREAM_ACK_LOW_TRAFFIC_FLUSH_MS}, ` +
        `ack_low_traffic_gap_ms=${STREAM_ACK_LOW_TRAFFIC_GAP_MS}, ` +
        `ack_low_traffic_max_pending=${STREAM_ACK_LOW_TRAFFIC_MAX_PENDING}, ` +
        `lazy_payload_parse=${STREAM_LAZY_PAYLOAD_PARSE}, ` +
        `extract_user_from_payload=${STREAM_EXTRACT_USER_FROM_PAYLOAD})`
    );
    secureLog('info', `[Realtime Gateway] Stream socket hot-path profile: ${socketHotPathProfiler.configSummary()}`);
    if (STREAM_SHADOW_MODE) {
      secureLog(
        'info',
        '[Realtime Gateway] STREAM_SHADOW_MODE=true. Events are consumed and ACKed, but Socket.IO emission is disabled.'
      );
    }

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

export function getSocketHotPathProfileSnapshot(): SocketHotPathProfileSnapshot {
  return socketHotPathProfiler.snapshot();
}

export function getRuntimeBreakthroughSnapshot(): RuntimeBreakthroughSnapshot {
  return {
    lane_runtime_profiles_enabled: STREAM_LANE_RUNTIME_PROFILES_ENABLED,
    direct_broadcast_fast_path: {
      mode: STREAM_DIRECT_BROADCAST_FAST_PATH,
      min_payload_bytes: STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES,
      active: STREAM_DIRECT_BROADCAST_FAST_PATH !== 'off' && !STREAM_EXTRACT_USER_FROM_PAYLOAD,
      requires_extract_user_from_payload_false: true,
    },
    lane_profiles: [
      { lane: 'small', min_payload_bytes: 0, max_payload_bytes: 1024 },
      { lane: 'mid', min_payload_bytes: 1025, max_payload_bytes: 8192 },
      { lane: 'heavy', min_payload_bytes: 8193, max_payload_bytes: null },
    ],
    counters: {
      evaluated_events: runtimeProfileEvents,
      direct_broadcast_events: runtimeProfileDirectBroadcastEvents,
      lane_counts: mapToObject(runtimeProfileLaneCounts),
      direct_broadcast_lane_counts: mapToObject(runtimeProfileDirectBroadcastLaneCounts),
    },
  };
}

function createTransport(): EventTransport {
  if (STREAM_TRANSPORT === 'sugar-glider-http') {
    return new SugarGliderHttpEventTransport(SUGAR_GLIDER_URL);
  }
  return new SugarGliderGrpcEventTransport(SUGAR_GLIDER_GRPC_ADDR);
}

async function startStreamLoop(
  eventTransport: EventTransport,
  spec: StreamSpec,
  options: SubscriptionOptions
): Promise<void> {
  await eventTransport.subscribe(
    spec.stream,
    async (event: StreamEvent) => {
      if (STREAM_SHADOW_MODE) {
        return;
      }
      if (!io) {
        return;
      }

      const dispatchStartNs = nowHrTimeNs();
      const laneDecision = resolveRuntimeLaneDecision(event);
      const socketEvent = resolveRepurposeSocketEvent(event, spec.socketEvent);
      if (event.user_id) {
        const emitStartNs = nowHrTimeNs();
        io.to(`user_${event.user_id}`).emit(socketEvent, event);
        const emitNs = elapsedNs(emitStartNs);
        recordRuntimeBreakthroughDecision(laneDecision, false);
        return {
          dispatchNs: Math.max(0, elapsedNs(dispatchStartNs) - emitNs),
          emitNs,
        };
      }

      const emission = resolveBroadcastEmission(event, laneDecision);
      const emitStartNs = nowHrTimeNs();
      io.emit(socketEvent, emission.data);
      const emitNs = elapsedNs(emitStartNs);
      recordRuntimeBreakthroughDecision(laneDecision, emission.directBroadcast);
      return {
        dispatchNs: Math.max(0, elapsedNs(dispatchStartNs) - emitNs),
        emitNs,
      };
    },
    {
      consumerGroup: options.consumerGroup,
      consumerName: `${options.consumerName}-${eventTransport.name}`,
      blockMs: options.blockMs,
    }
  );
}

function getSynapseSidecarClientConstructor(): grpc.ServiceClientConstructor {
  if (sidecarClientConstructor) {
    return sidecarClientConstructor;
  }

  const protoPath = resolveSidecarProtoPath();
  const packageDefinition = protoLoader.loadSync(protoPath, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });

  const loadedDefinition = grpc.loadPackageDefinition(packageDefinition) as unknown as {
    synapse?: { v1?: { SynapseSidecar?: grpc.ServiceClientConstructor } };
  };
  const constructor = loadedDefinition?.synapse?.v1?.SynapseSidecar;
  if (!constructor) {
    throw new Error(`Unable to load SynapseSidecar service definition from proto: ${protoPath}`);
  }
  sidecarClientConstructor = constructor;
  return constructor;
}

function resolveSidecarProtoPath(): string {
  const explicitPath = process.env.SYNAPSE_SIDECAR_PROTO_PATH?.trim();
  const candidates = [
    explicitPath || '',
    path.resolve(__dirname, 'proto/sidecar.proto'),
    path.resolve(__dirname, '../../src/streaming/proto/sidecar.proto'),
    path.resolve(process.cwd(), 'src/streaming/proto/sidecar.proto'),
    path.resolve(process.cwd(), 'platform-services/shared/deepiri-sugar-glider/proto/synapse/v1/sidecar.proto'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  throw new Error(
    `Unable to find sidecar.proto. Checked: ${candidates.join(', ')}. ` +
      'Set SYNAPSE_SIDECAR_PROTO_PATH to an absolute path.'
  );
}

function normalizeGrpcEvent(event: GrpcEvent): StreamEvent {
  const normalized: Record<string, unknown> = {
    stream: event.stream,
    entry_id: event.entry_id,
    event_type: event.event_type,
    event: event.event_type,
    sender: event.sender,
    payload: decodeGrpcPayload(event.payload),
    timestamp: event.timestamp || new Date().toISOString(),
    source: 'synapse-sugar-glider',
  };

  enrichUserIdFromPayload(normalized);
  return normalized as StreamEvent;
}

function resolveSocketEventName(streamName: string): string {
  const spec = STREAM_SPECS.find((entry) => entry.stream === streamName);
  return spec?.socketEvent || 'unknown-event';
}

function resolveRepurposeSocketEvent(event: StreamEvent, defaultEvent: string): string {
  const type = String(event.event_type || event.event || '');
  if (type.startsWith('registry.')) return 'registry-event';
  if (type.startsWith('truss.')) return 'truss-event';
  if (type.startsWith('jobs.')) return 'jobs-event';
  if (type.startsWith('telemetry.')) return 'telemetry-event';
  if (type.startsWith('training.')) return 'training-event';
  if (type.startsWith('notification.') || type.startsWith('messaging.')) return 'notification-event';
  return defaultEvent;
}

function decodeGrpcPayload(payload: Buffer | Uint8Array): unknown {
  const bytes = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
  if (bytes.length === 0) {
    return {};
  }
  const text = bytes.toString('utf8');
  if (STREAM_LAZY_PAYLOAD_PARSE) {
    return text;
  }
  return tryParseJson(text);
}

function normalizeEvent(fields: Record<string, unknown>): StreamEvent {
  const event: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === 'string') {
      if (key === 'payload' && STREAM_LAZY_PAYLOAD_PARSE) {
        event[key] = value;
      } else {
        event[key] = tryParseJson(value);
      }
    } else {
      event[key] = value;
    }
  }

  if (event.event === undefined && event.event_type !== undefined) {
    event.event = String(event.event_type);
  }

  // Sugar Glider events may nest routing keys in payload; hoist them for socket routing.
  enrichUserIdFromPayload(event);
  if (event.timestamp === undefined) {
    event.timestamp = new Date().toISOString();
  }
  if (event.source === undefined) {
    event.source = 'synapse-sugar-glider';
  }

  return event as StreamEvent;
}

function enrichUserIdFromPayload(event: Record<string, unknown>): void {
  if (!STREAM_EXTRACT_USER_FROM_PAYLOAD || event.user_id !== undefined) {
    return;
  }

  let payload = asRecord(event.payload);
  if (!payload && STREAM_LAZY_PAYLOAD_PARSE && typeof event.payload === 'string') {
    const maybePayload = tryParsePayloadForRouting(event.payload);
    payload = asRecord(maybePayload);
    if (payload) {
      event.payload = payload;
    }
  }
  if (!payload) {
    return;
  }

  const payloadUser = firstDefined(payload, ['user_id', 'userId']);
  if (payloadUser !== undefined) {
    event.user_id = payloadUser;
    return;
  }

  const nestedUser = asRecord(payload.user);
  const nestedUserId = nestedUser ? firstDefined(nestedUser, ['id', 'user_id', 'userId']) : undefined;
  if (nestedUserId !== undefined) {
    event.user_id = nestedUserId;
  }
}

function resolveRuntimeLaneDecision(event: StreamEvent): RuntimeLaneDecision {
  if (!shouldEvaluateRuntimeBreakthroughs()) {
    return {
      lane: 'unknown',
      payloadBytes: null,
      source: 'disabled',
    };
  }

  const scenarioId = extractBenchScenarioId(event);
  if (scenarioId) {
    const match = BENCH_SCENARIO_BUCKET_REGEX.exec(scenarioId);
    if (match && match[1]) {
      const payloadBytes = Number(match[1]);
      if (Number.isFinite(payloadBytes) && payloadBytes >= 0) {
        return {
          lane: laneFromPayloadBytes(payloadBytes),
          payloadBytes,
          source: 'bench-scenario',
        };
      }
    }
  }

  const estimatedBytes = estimatePayloadBytes(event);
  if (estimatedBytes !== null) {
    return {
      lane: laneFromPayloadBytes(estimatedBytes),
      payloadBytes: estimatedBytes,
      source: 'payload-size',
    };
  }

  return {
    lane: 'unknown',
    payloadBytes: null,
    source: 'unknown',
  };
}

function shouldEvaluateRuntimeBreakthroughs(): boolean {
  return STREAM_LANE_RUNTIME_PROFILES_ENABLED || STREAM_DIRECT_BROADCAST_FAST_PATH !== 'off';
}

function laneFromPayloadBytes(payloadBytes: number): RuntimeLaneName {
  if (payloadBytes <= 1024) {
    return 'small';
  }
  if (payloadBytes <= 8192) {
    return 'mid';
  }
  return 'heavy';
}

function estimatePayloadBytes(event: StreamEvent): number | null {
  const root = asRecord(event as unknown);
  if (!root) {
    return null;
  }

  const payload = root.payload;
  if (typeof payload === 'string') {
    return Buffer.byteLength(payload, 'utf8');
  }
  if (Buffer.isBuffer(payload)) {
    return payload.byteLength;
  }
  if (payload instanceof Uint8Array) {
    return payload.byteLength;
  }
  return null;
}

function resolveBroadcastEmission(
  event: StreamEvent,
  laneDecision: RuntimeLaneDecision
): { data: unknown; directBroadcast: boolean } {
  if (!shouldUseDirectBroadcastFastPath(event, laneDecision)) {
    return { data: event, directBroadcast: false };
  }

  return {
    data: materializeDirectBroadcastPayload(event),
    directBroadcast: true,
  };
}

function shouldUseDirectBroadcastFastPath(event: StreamEvent, laneDecision: RuntimeLaneDecision): boolean {
  if (STREAM_DIRECT_BROADCAST_FAST_PATH === 'off') {
    return false;
  }
  if (STREAM_EXTRACT_USER_FROM_PAYLOAD) {
    return false;
  }
  if (event.user_id) {
    return false;
  }
  if (laneDecision.payloadBytes === null) {
    return STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES === 0;
  }
  return laneDecision.payloadBytes >= STREAM_DIRECT_BROADCAST_MIN_PAYLOAD_BYTES;
}

function materializeDirectBroadcastPayload(event: StreamEvent): unknown {
  const root = asRecord(event as unknown);
  if (!root || root.payload === undefined) {
    return event;
  }

  if (STREAM_DIRECT_BROADCAST_FAST_PATH === 'payload-json' && typeof root.payload === 'string') {
    return tryParseJson(root.payload);
  }

  return root.payload;
}

function recordRuntimeBreakthroughDecision(
  laneDecision: RuntimeLaneDecision,
  directBroadcast: boolean
): void {
  if (!shouldEvaluateRuntimeBreakthroughs()) {
    return;
  }

  runtimeProfileEvents += 1;
  incrementMapCount(runtimeProfileLaneCounts, laneDecision.lane);
  if (directBroadcast) {
    runtimeProfileDirectBroadcastEvents += 1;
    incrementMapCount(runtimeProfileDirectBroadcastLaneCounts, laneDecision.lane);
  }
}

function extractBenchScenarioId(event: StreamEvent): string | null {
  const root = asRecord(event as unknown);
  if (!root) {
    return null;
  }

  const rootScenario = firstDefined(root, ['bench_scenario_id', 'benchScenarioId']);
  if (typeof rootScenario === 'string' && rootScenario.length > 0) {
    return rootScenario;
  }

  const payloadRecord = asRecord(root.payload);
  if (payloadRecord) {
    const payloadScenario = firstDefined(payloadRecord, ['bench_scenario_id', 'benchScenarioId']);
    if (typeof payloadScenario === 'string' && payloadScenario.length > 0) {
      return payloadScenario;
    }
  }

  if (typeof root.payload === 'string') {
    const match = BENCH_SCENARIO_ID_REGEX.exec(root.payload);
    if (match && match[1]) {
      return match[1];
    }
  }

  return null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function firstDefined(source: Record<string, unknown>, keys: string[]): unknown {
  for (const key of keys) {
    if (source[key] !== undefined) {
      return source[key];
    }
  }
  return undefined;
}

function tryParseJson(value: string): unknown {
  if (value.length < 2) {
    return value;
  }

  const first = value.charCodeAt(0);
  const last = value.charCodeAt(value.length - 1);
  const isLikelyJson = (first === 123 && last === 125) || (first === 91 && last === 93);
  if (isLikelyJson) {
    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  }

  // Slow path for values with leading/trailing whitespace.
  const trimmed = value.trim();
  if (trimmed.length < 2) {
    return value;
  }
  const trimmedFirst = trimmed.charCodeAt(0);
  const trimmedLast = trimmed.charCodeAt(trimmed.length - 1);
  const trimmedLikelyJson =
    (trimmedFirst === 123 && trimmedLast === 125) || (trimmedFirst === 91 && trimmedLast === 93);
  if (trimmedLikelyJson) {
    try {
      return JSON.parse(trimmed);
    } catch {
      return value;
    }
  }
  return value;
}

function nowHrTimeNs(): bigint {
  return process.hrtime.bigint();
}

function elapsedNs(startNs: bigint): number {
  return Number(process.hrtime.bigint() - startNs);
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

function parseNonNegativeInt(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return Math.floor(parsed);
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'off'].includes(normalized)) {
    return false;
  }

  return fallback;
}

function parseBroadcastFastPathMode(value: string | undefined): BroadcastFastPathMode {
  const normalized = (value || 'off').trim().toLowerCase();
  if (normalized === 'payload' || normalized === 'raw-payload' || normalized === 'raw_payload') {
    return 'payload';
  }
  if (normalized === 'payload-json' || normalized === 'payload_json' || normalized === 'json-payload') {
    return 'payload-json';
  }
  if (normalized && normalized !== 'off' && normalized !== 'false' && normalized !== '0') {
    secureLog(
      'warn',
      `[Realtime Gateway] Unknown STREAM_DIRECT_BROADCAST_FAST_PATH='${value}'. Falling back to off.`
    );
  }
  return 'off';
}

function parseSocketHotPathBucketTargets(raw: string): { trackAll: boolean; targets: Set<string> } {
  const values = raw
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  let trackAll = false;
  const targets = new Set<string>();

  for (const value of values) {
    if (value === '*') {
      trackAll = true;
      continue;
    }
    const directMatch = /^(\d+):(\d+)$/.exec(value);
    if (directMatch) {
      targets.add(`${Number(directMatch[1])}:${Number(directMatch[2])}`);
      continue;
    }
    const scenarioStyleMatch = /^p(\d+)-c(\d+)$/i.exec(value);
    if (scenarioStyleMatch) {
      targets.add(`${Number(scenarioStyleMatch[1])}:${Number(scenarioStyleMatch[2])}`);
    }
  }

  return {
    trackAll,
    targets,
  };
}

function createStageAccumulator(): StageAccumulator {
  return {
    totalNs: 0,
    maxNs: 0,
    samplesNs: [],
  };
}

function sanitizeDurationNs(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
    return 0;
  }
  return Math.floor(value);
}

function applyStageSample(stage: StageAccumulator, durationNs: number, eventCount: number, sampleLimit: number): void {
  stage.totalNs += durationNs;
  stage.maxNs = Math.max(stage.maxNs, durationNs);
  if (stage.samplesNs.length < sampleLimit) {
    stage.samplesNs.push(durationNs);
    return;
  }
  const slot = Math.floor(Math.random() * eventCount);
  if (slot < sampleLimit) {
    stage.samplesNs[slot] = durationNs;
  }
}

function stageSnapshot(stage: StageAccumulator, events: number): StageTimingSnapshot {
  return {
    avg_ms: toFixedNumber(nsToMs(events > 0 ? stage.totalNs / events : 0), 6),
    p95_ms: toFixedNumber(nsToMs(percentile(stage.samplesNs, 95)), 6),
    max_ms: toFixedNumber(nsToMs(stage.maxNs), 6),
    total_ms: toFixedNumber(nsToMs(stage.totalNs), 6),
    sample_count: stage.samplesNs.length,
  };
}

function mapToObject(source: Map<string, number>): Record<string, number> {
  const object: Record<string, number> = {};
  for (const [key, value] of Array.from(source.entries()).sort(([a], [b]) => a.localeCompare(b))) {
    object[key] = value;
  }
  return object;
}

function incrementMapCount(map: Map<string, number>, key: string): void {
  const next = (map.get(key) || 0) + 1;
  map.set(key, next);
}

function compareBucketKeys(a: string, b: string): number {
  const [aPayload, aConcurrency] = a.split(':').map((value) => Number(value));
  const [bPayload, bConcurrency] = b.split(':').map((value) => Number(value));
  if (aPayload !== bPayload) {
    return aPayload - bPayload;
  }
  return aConcurrency - bConcurrency;
}

function percentile(values: number[], percentileValue: number): number {
  if (!values.length) {
    return 0;
  }
  const safePercentile = Math.min(100, Math.max(0, percentileValue));
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.floor(((safePercentile / 100) * (sorted.length - 1)));
  return sorted[index];
}

function nsToMs(valueNs: number): number {
  return valueNs / 1_000_000;
}

function toFixedNumber(value: number, digits: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Number(value.toFixed(digits));
}

function resolveConsumerGroup(value: string | undefined, shadowMode: boolean): string {
  const normalized = (value || '').trim();
  if (normalized) {
    return normalized;
  }
  return shadowMode ? 'realtime-gateway-sg-canary' : 'realtime-gateway';
}

function chunkArray<T>(items: T[], chunkSize: number): T[][] {
  const safeChunkSize = Math.max(1, chunkSize);
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += safeChunkSize) {
    chunks.push(items.slice(i, i + safeChunkSize));
  }
  return chunks;
}

function tryParsePayloadForRouting(payloadText: string): unknown {
  if (!payloadText) {
    return payloadText;
  }

  // Fast path: skip full JSON parse unless routing keys are present.
  const hasRoutingKey = ROUTING_KEY_REGEX.test(payloadText);
  if (!hasRoutingKey) {
    return payloadText;
  }

  return tryParseJson(payloadText);
}

function parseStreamTransport(value: string): StreamTransportSetting {
  const normalized = value.trim().toLowerCase();
  if (!normalized) {
    return 'sugar-glider-grpc';
  }

  if (normalized === 'sugar-glider-grpc' || normalized === 'grpc') {
    return 'sugar-glider-grpc';
  }
  if (normalized === 'sugar-glider-http' || normalized === 'http') {
    return 'sugar-glider-http';
  }

  secureLog(
    'warn',
    `[Realtime Gateway] Unknown STREAM_TRANSPORT='${value}'. Falling back to sugar-glider-grpc.`
  );
  return 'sugar-glider-grpc';
}
