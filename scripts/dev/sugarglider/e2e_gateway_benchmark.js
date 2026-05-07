#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { performance } = require('perf_hooks');
const { execSync } = require('child_process');

const DEFAULTS = {
  sugarGliderUrl: 'http://localhost:8081',
  realtimeGatewayUrl: 'http://localhost:5008',
  socketPath: '/socket.io/',
  socketTransport: 'polling',
  stream: 'platform-events',
  deliveryTimeoutMs: 15000,
};

const FIXED_MATRIX = Object.freeze({
  payloadBytes: Object.freeze([1024, 8192, 32768]),
  concurrencyLevels: Object.freeze([1, 10, 50]),
  warmupOps: 500,
  measureOps: 5000,
  repetitions: 3,
});

const BENCHMARK_CONTAINER_CANDIDATES = Object.freeze({
  realtime_gateway: Object.freeze(
    uniqueNonEmpty([
      process.env.BENCHMARK_RTG_CONTAINER,
      'deepiri-realtime-gateway-rtg-local',
      'deepiri-realtime-gateway-dev',
    ])
  ),
  sugar_glider: Object.freeze(
    uniqueNonEmpty([
      process.env.BENCHMARK_SUGAR_GLIDER_CONTAINER,
      'deepiri-synapse-sugar-glider-rtg-local',
      'deepiri-synapse-sidecar-rtg-local',
    ])
  ),
});

function usage() {
  console.log(`End-to-end gateway benchmark (publish -> Sugar Glider -> Realtime Gateway socket delivery)

Usage:
  node scripts/dev/sugarglider/e2e_gateway_benchmark.js [options]

Options:
  --sugar-glider-url <url>          Sugar Glider base URL (default: ${DEFAULTS.sugarGliderUrl})
  --realtime-gateway-url <url>      Realtime Gateway base URL (default: ${DEFAULTS.realtimeGatewayUrl})
  --socket-path <path>              Socket.IO path (default: ${DEFAULTS.socketPath})
  --socket-transport <mode>         Socket transport: polling|websocket (default: ${DEFAULTS.socketTransport})
  --stream <name>                   Stream name for publish calls (default: ${DEFAULTS.stream})
  --delivery-timeout-ms <n>         Timeout waiting for socket delivery per event (default: ${DEFAULTS.deliveryTimeoutMs})
  --out-dir <dir>                   Output directory (default: benchmarks/end-to-end/<run-id>)
  --skip-health-checks              Skip /readyz and /health checks
  -h, --help                        Show this help

Matrix (hard-locked in code):
  payload_bytes: ${FIXED_MATRIX.payloadBytes.join(',')}
  concurrency_levels: ${FIXED_MATRIX.concurrencyLevels.join(',')}
  warmup_ops: ${FIXED_MATRIX.warmupOps}
  measure_ops: ${FIXED_MATRIX.measureOps}
  repetitions: ${FIXED_MATRIX.repetitions}

Examples:
  node scripts/dev/sugarglider/e2e_gateway_benchmark.js
  node scripts/dev/sugarglider/e2e_gateway_benchmark.js --out-dir benchmarks/end-to-end/20260412T000000Z
`);
}

function parseArgs(argv) {
  const options = {
    sugarGliderUrl: DEFAULTS.sugarGliderUrl,
    realtimeGatewayUrl: DEFAULTS.realtimeGatewayUrl,
    socketPath: DEFAULTS.socketPath,
    socketTransport: DEFAULTS.socketTransport,
    stream: DEFAULTS.stream,
    payloadBytes: [...FIXED_MATRIX.payloadBytes],
    concurrencyLevels: [...FIXED_MATRIX.concurrencyLevels],
    warmupOps: FIXED_MATRIX.warmupOps,
    measureOps: FIXED_MATRIX.measureOps,
    repetitions: FIXED_MATRIX.repetitions,
    deliveryTimeoutMs: DEFAULTS.deliveryTimeoutMs,
    outDir: null,
    skipHealthChecks: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--sugar-glider-url':
        options.sugarGliderUrl = requireValue(arg, argv[++i]);
        break;
      case '--realtime-gateway-url':
        options.realtimeGatewayUrl = requireValue(arg, argv[++i]);
        break;
      case '--socket-path':
        options.socketPath = requireValue(arg, argv[++i]);
        break;
      case '--socket-transport':
        options.socketTransport = parseSocketTransport(requireValue(arg, argv[++i]), arg);
        break;
      case '--stream':
        options.stream = requireValue(arg, argv[++i]);
        break;
      case '--payload-bytes':
      case '--concurrency-levels':
      case '--warmup-events':
      case '--measure-events':
      case '--warmup-ops':
      case '--measure-ops':
      case '--repetitions':
        requireValue(arg, argv[++i]);
        throw new Error(
          `${arg} cannot be overridden; matrix is locked to payload=${FIXED_MATRIX.payloadBytes.join(',')} ` +
            `concurrency=${FIXED_MATRIX.concurrencyLevels.join(',')} warmup_ops=${FIXED_MATRIX.warmupOps} ` +
            `measure_ops=${FIXED_MATRIX.measureOps} repetitions=${FIXED_MATRIX.repetitions}`
        );
        break;
      case '--delivery-timeout-ms':
        options.deliveryTimeoutMs = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--out-dir':
        options.outDir = requireValue(arg, argv[++i]);
        break;
      case '--skip-health-checks':
        options.skipHealthChecks = true;
        break;
      case '-h':
      case '--help':
        usage();
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function requireValue(flag, value) {
  if (!value || value.startsWith('--')) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function uniqueNonEmpty(values) {
  return [...new Set(values.filter((value) => typeof value === 'string' && value.trim() !== ''))];
}

function parsePositiveInt(value, flagName) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0 || Math.floor(parsed) !== parsed) {
    throw new Error(`Expected positive integer for ${flagName}, received: ${value}`);
  }
  return parsed;
}

function parseSocketTransport(value, flagName) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'polling' || normalized === 'websocket') {
    return normalized;
  }
  throw new Error(`Expected polling or websocket for ${flagName}, received: ${value}`);
}

function runIdFromDate(date = new Date()) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function quoteCsvCell(value) {
  if (value === null || value === undefined) {
    return '';
  }
  const raw = String(value);
  if (raw.includes('"') || raw.includes(',') || raw.includes('\n')) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
}

function percentile(valuesSorted, p) {
  if (!valuesSorted.length) {
    return 0;
  }
  if (valuesSorted.length === 1) {
    return valuesSorted[0];
  }
  const position = (p / 100) * (valuesSorted.length - 1);
  const lower = Math.floor(position);
  const upper = Math.ceil(position);
  if (lower === upper) {
    return valuesSorted[lower];
  }
  const weight = position - lower;
  return valuesSorted[lower] + (valuesSorted[upper] - valuesSorted[lower]) * weight;
}

function computeLatencyStats(latenciesMs) {
  if (!latenciesMs.length) {
    return {
      count: 0,
      avg_ms: 0,
      min_ms: 0,
      p50_ms: 0,
      p95_ms: 0,
      p99_ms: 0,
      max_ms: 0,
    };
  }

  const sorted = [...latenciesMs].sort((a, b) => a - b);
  const sum = sorted.reduce((acc, value) => acc + value, 0);
  return {
    count: sorted.length,
    avg_ms: sum / sorted.length,
    min_ms: sorted[0],
    p50_ms: percentile(sorted, 50),
    p95_ms: percentile(sorted, 95),
    p99_ms: percentile(sorted, 99),
    max_ms: sorted[sorted.length - 1],
  };
}

function parseMaybeJson(value) {
  if (typeof value !== 'string') {
    return value;
  }
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

function asObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value;
}

function normalizePayload(payloadRaw) {
  const parsed = parseMaybeJson(payloadRaw);
  return asObject(parsed);
}

function eventIdFromSocketEvent(eventData) {
  const root = asObject(eventData) || {};
  const payload = normalizePayload(root.payload) || {};
  return (
    payload.bench_event_id ||
    payload.benchEventId ||
    root.bench_event_id ||
    root.benchEventId ||
    null
  );
}

function scenarioIdFromSocketEvent(eventData) {
  const root = asObject(eventData) || {};
  const payload = normalizePayload(root.payload) || {};
  return (
    payload.bench_scenario_id ||
    payload.benchScenarioId ||
    root.bench_scenario_id ||
    root.benchScenarioId ||
    null
  );
}

function buildSizedPayload(baseFields, targetBytes) {
  const payload = { ...baseFields, filler: '' };
  const baseBytes = Buffer.byteLength(JSON.stringify(payload), 'utf8');
  const fillerLength = Math.max(0, targetBytes - baseBytes);
  payload.filler = 'x'.repeat(fillerLength);
  const actualBytes = Buffer.byteLength(JSON.stringify(payload), 'utf8');
  return { payload, actualBytes };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class PollingSocketIOClient {
  constructor({ baseUrl, socketPath, onEvent, log }) {
    this.baseUrl = baseUrl;
    this.socketPath = socketPath;
    this.onEvent = onEvent;
    this.log = log;
    this.sid = null;
    this.connected = false;
    this.closed = false;
    this.sendChain = Promise.resolve();
    this.pollPromise = null;
  }

  endpoint(extra = {}) {
    const base = new URL(this.socketPath, this.baseUrl);
    base.searchParams.set('EIO', '4');
    base.searchParams.set('transport', 'polling');
    base.searchParams.set('t', `${Date.now()}-${Math.random().toString(16).slice(2)}`);
    if (this.sid) {
      base.searchParams.set('sid', this.sid);
    }
    Object.entries(extra).forEach(([k, v]) => {
      if (v !== undefined && v !== null) {
        base.searchParams.set(k, String(v));
      }
    });
    return base.toString();
  }

  async connect() {
    const handshakeResp = await fetch(this.endpoint(), { method: 'GET' });
    if (!handshakeResp.ok) {
      throw new Error(`socket handshake failed (${handshakeResp.status})`);
    }
    const handshakeRaw = await handshakeResp.text();
    const packets = this.splitPayload(handshakeRaw);
    const openPacket = packets.find((packet) => packet.startsWith('0'));
    if (!openPacket) {
      throw new Error(`socket handshake missing open packet: ${handshakeRaw}`);
    }
    let open;
    try {
      open = JSON.parse(openPacket.slice(1));
    } catch (error) {
      throw new Error(`failed to parse socket handshake: ${String(error)}`);
    }
    if (!open.sid) {
      throw new Error(`socket handshake missing sid: ${handshakeRaw}`);
    }
    this.sid = open.sid;

    await this.sendEnginePacket('40');
    this.connected = true;
    this.closed = false;
    this.pollPromise = this.pollLoop();
    this.log(`[socket] connected sid=${this.sid}`);
  }

  async disconnect() {
    this.closed = true;
    this.connected = false;
    try {
      if (this.sid) {
        await this.sendEnginePacket('41');
      }
    } catch {
      // ignore disconnect errors
    }
    if (this.pollPromise) {
      await this.pollPromise.catch(() => {});
    }
    this.log('[socket] disconnected');
  }

  async sendEnginePacket(packet) {
    if (!this.sid) {
      throw new Error('socket sid is not initialized');
    }
    this.sendChain = this.sendChain.then(async () => {
      const resp = await fetch(this.endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain;charset=UTF-8' },
        body: packet,
      });
      if (!resp.ok) {
        const body = await resp.text().catch(() => '');
        throw new Error(`socket send failed (${resp.status}): ${body}`);
      }
    });
    return this.sendChain;
  }

  async pollLoop() {
    while (!this.closed) {
      let resp;
      try {
        resp = await fetch(this.endpoint(), { method: 'GET' });
      } catch (error) {
        if (this.closed) {
          return;
        }
        this.log(`[socket] poll error: ${String(error)}`);
        await sleep(250);
        continue;
      }

      if (!resp.ok) {
        if (this.closed) {
          return;
        }
        const body = await resp.text().catch(() => '');
        this.log(`[socket] poll status ${resp.status}: ${body}`);
        await sleep(250);
        continue;
      }

      const raw = await resp.text();
      if (!raw) {
        continue;
      }

      const packets = this.splitPayload(raw);
      for (const packet of packets) {
        await this.handleEnginePacket(packet);
      }
    }
  }

  splitPayload(payload) {
    if (!payload) {
      return [];
    }
    return payload.split('\x1e').filter(Boolean);
  }

  async handleEnginePacket(packet) {
    if (!packet) {
      return;
    }
    const engineType = packet[0];
    const body = packet.slice(1);
    switch (engineType) {
      case '0':
        return;
      case '1':
        this.closed = true;
        this.connected = false;
        return;
      case '2':
        await this.sendEnginePacket('3');
        return;
      case '3':
        return;
      case '4':
        this.handleSocketPacket(body);
        return;
      default:
        return;
    }
  }

  handleSocketPacket(packet) {
    if (!packet) {
      return;
    }

    if (packet.startsWith('0') || packet.startsWith('1')) {
      return;
    }

    if (packet.startsWith('2')) {
      const payload = packet.slice(1);
      try {
        const parsed = JSON.parse(payload);
        if (Array.isArray(parsed) && parsed.length >= 1) {
          const [eventName, eventData] = parsed;
          this.onEvent(eventName, eventData);
        }
      } catch (error) {
        this.log(`[socket] failed to parse event packet: ${String(error)}`);
      }
      return;
    }
  }
}

class WebSocketSocketIOClient {
  constructor({ baseUrl, socketPath, onEvent, log }) {
    this.baseUrl = baseUrl;
    this.socketPath = socketPath;
    this.onEvent = onEvent;
    this.log = log;
    this.socket = null;
    this.connected = false;
    this.closed = false;
  }

  endpoint() {
    const base = new URL(this.socketPath, this.baseUrl);
    base.protocol = base.protocol === 'https:' ? 'wss:' : 'ws:';
    base.searchParams.set('EIO', '4');
    base.searchParams.set('transport', 'websocket');
    return base.toString();
  }

  async connect() {
    this.socket = new WebSocket(this.endpoint());
    this.closed = false;
    await new Promise((resolve, reject) => {
      let settled = false;
      const settle = (fn) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timeoutHandle);
        fn();
      };
      const timeoutHandle = setTimeout(() => {
        settle(() => {
          try {
            this.socket?.close();
          } catch {
            // ignore close errors
          }
          reject(new Error('socket websocket connect timed out'));
        });
      }, 15000);

      const onConnect = () => {
        try {
          this.socket?.send('40');
        } catch (error) {
          settle(() => reject(new Error(`socket websocket connect failed: ${String(error)}`)));
        }
      };
      const onError = (error) => {
        settle(() => reject(new Error(`socket websocket connect failed: ${String(error)}`)));
      };

      const onClose = () => {
        this.connected = false;
        this.closed = true;
      };

      const onMessage = (messageEvent) => {
        const payload = this.asText(messageEvent.data);
        const packets = this.splitPayload(payload);
        for (const packet of packets) {
          this.handleEnginePacket(packet);
          if (!settled && packet.startsWith('40')) {
            this.connected = true;
            settle(resolve);
          }
        }
      };

      this.socket.addEventListener('open', onConnect);
      this.socket.addEventListener('error', onError);
      this.socket.addEventListener('close', onClose);
      this.socket.addEventListener('message', onMessage);
    });
    this.log('[socket] connected websocket');
  }

  async disconnect() {
    this.closed = true;
    this.connected = false;
    if (!this.socket) {
      return;
    }
    try {
      if (this.socket.readyState === WebSocket.OPEN) {
        this.socket.send('41');
      }
    } catch {
      // ignore disconnect packet errors
    }
    try {
      this.socket.close();
    } catch {
      // ignore close errors
    }
    this.log('[socket] disconnected');
    this.socket = null;
  }

  splitPayload(payload) {
    if (!payload) {
      return [];
    }
    return payload.split('\x1e').filter(Boolean);
  }

  asText(raw) {
    if (typeof raw === 'string') {
      return raw;
    }
    if (Buffer.isBuffer(raw)) {
      return raw.toString('utf8');
    }
    if (raw instanceof ArrayBuffer) {
      return Buffer.from(raw).toString('utf8');
    }
    if (ArrayBuffer.isView(raw)) {
      return Buffer.from(raw.buffer, raw.byteOffset, raw.byteLength).toString('utf8');
    }
    return String(raw || '');
  }

  handleEnginePacket(packet) {
    if (!packet) {
      return;
    }
    const engineType = packet[0];
    const body = packet.slice(1);
    switch (engineType) {
      case '0':
        return;
      case '1':
        this.closed = true;
        this.connected = false;
        return;
      case '2':
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
          this.socket.send('3');
        }
        return;
      case '3':
        return;
      case '4':
        this.handleSocketPacket(body);
        return;
      default:
        return;
    }
  }

  handleSocketPacket(packet) {
    if (!packet) {
      return;
    }

    if (packet.startsWith('0') || packet.startsWith('1')) {
      return;
    }

    if (packet.startsWith('2')) {
      const payload = packet.slice(1);
      try {
        const parsed = JSON.parse(payload);
        if (Array.isArray(parsed) && parsed.length >= 1) {
          const [eventName, eventData] = parsed;
          this.onEvent(eventName, eventData);
        }
      } catch (error) {
        this.log(`[socket] failed to parse websocket event packet: ${String(error)}`);
      }
    }
  }
}

function createSocketClient({ transport, baseUrl, socketPath, onEvent, log }) {
  if (transport === 'websocket') {
    return new WebSocketSocketIOClient({ baseUrl, socketPath, onEvent, log });
  }
  return new PollingSocketIOClient({ baseUrl, socketPath, onEvent, log });
}

async function checkJsonEndpoint(url, name) {
  const response = await fetch(url, { method: 'GET' });
  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(`${name} check failed (${response.status}): ${bodyText}`);
  }
  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch (error) {
    throw new Error(`${name} check returned non-JSON response: ${String(error)}`);
  }
  return parsed;
}

async function collectRuntimeSnapshot({ options, precheckedGatewayHealth }) {
  const snapshot = {
    captured_utc: nowUtcIso(),
    realtime_gateway_health: null,
    sugar_glider_config: null,
    container_env: {
      realtime_gateway: captureContainerEnvSnapshot(BENCHMARK_CONTAINER_CANDIDATES.realtime_gateway),
      sugar_glider: captureContainerEnvSnapshot(BENCHMARK_CONTAINER_CANDIDATES.sugar_glider),
    },
    validation: {
      websocket_native_addons_verified: false,
      websocket_native_addons_active: null,
      required_snapshots_complete: false,
    },
    errors: {},
  };

  try {
    if (precheckedGatewayHealth) {
      snapshot.realtime_gateway_health = precheckedGatewayHealth;
    } else {
      snapshot.realtime_gateway_health = await checkJsonEndpoint(
        `${stripTrailingSlash(options.realtimeGatewayUrl)}/health`,
        'realtime-gateway/health'
      );
    }
  } catch (error) {
    snapshot.errors.realtime_gateway_health = String(error);
  }

  try {
    snapshot.sugar_glider_config = await checkJsonEndpoint(
      `${stripTrailingSlash(options.sugarGliderUrl)}/v1/config`,
      'sugar-glider/v1/config'
    );
  } catch (error) {
    snapshot.errors.sugar_glider_config = String(error);
  }

  snapshot.validation.required_snapshots_complete = hasRequiredRuntimeSnapshots(snapshot);

  if (options.socketTransport === 'websocket') {
    const websocketNativeStatus = readWebsocketNativeAddonStatus(snapshot);
    snapshot.validation.websocket_native_addons_verified = websocketNativeStatus.verified;
    snapshot.validation.websocket_native_addons_active = websocketNativeStatus.active;
  }

  return snapshot;
}

function captureContainerEnvSnapshot(containerCandidates) {
  const candidates = uniqueNonEmpty(containerCandidates || []);
  for (const containerName of candidates) {
    const envSnapshot = inspectContainerEnv(containerName);
    if (envSnapshot.status === 'ok') {
      return envSnapshot;
    }
  }

  return {
    status: 'unavailable',
    container_name: '',
    candidates,
    env: {},
    env_lines: [],
    error: `unable to inspect container env for candidates=${candidates.join(',')}`,
  };
}

function inspectContainerEnv(containerName) {
  try {
    const raw = execSync(
      `docker inspect ${shellQuote(containerName)} --format '{{range .Config.Env}}{{println .}}{{end}}'`,
      { stdio: ['ignore', 'pipe', 'pipe'] }
    ).toString('utf8');
    const envLines = raw
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
      .sort();
    const env = {};
    for (const line of envLines) {
      const eqIndex = line.indexOf('=');
      if (eqIndex <= 0) {
        continue;
      }
      env[line.slice(0, eqIndex)] = line.slice(eqIndex + 1);
    }
    return {
      status: 'ok',
      container_name: containerName,
      candidates: [containerName],
      env,
      env_lines: envLines,
      error: '',
    };
  } catch (error) {
    return {
      status: 'unavailable',
      container_name: containerName,
      candidates: [containerName],
      env: {},
      env_lines: [],
      error: String(error),
    };
  }
}

function hasRequiredRuntimeSnapshots(snapshot) {
  return Boolean(
    snapshot?.sugar_glider_config &&
      snapshot?.container_env?.realtime_gateway?.status === 'ok' &&
      snapshot?.container_env?.sugar_glider?.status === 'ok'
  );
}

function assertRequiredRuntimeSnapshots(snapshot) {
  const failures = [];
  if (!snapshot?.sugar_glider_config) {
    failures.push('sugar-glider /v1/config');
  }
  if (snapshot?.container_env?.realtime_gateway?.status !== 'ok') {
    failures.push('realtime-gateway container env');
  }
  if (snapshot?.container_env?.sugar_glider?.status !== 'ok') {
    failures.push('sugar-glider container env');
  }
  if (failures.length > 0) {
    throw new Error(`runtime snapshot incomplete: missing ${failures.join(', ')}`);
  }
}

function parseBooleanish(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on';
}

function readWebsocketNativeAddonStatus(snapshot) {
  const health = asObject(snapshot?.realtime_gateway_health) || {};
  const socketInfo = asObject(health.socket_io) || {};
  const nativeAddons = asObject(socketInfo.native_addons) || {};
  const bufferutil = asObject(nativeAddons.bufferutil);
  const utf8Validate = asObject(nativeAddons.utf8_validate);

  if (bufferutil && utf8Validate && typeof bufferutil.active === 'boolean' && typeof utf8Validate.active === 'boolean') {
    return {
      verified: true,
      active: bufferutil.active && utf8Validate.active,
      details: {
        bufferutil,
        utf8_validate: utf8Validate,
      },
      source: 'realtime-gateway/health',
    };
  }

  const rtgEnv = asObject(snapshot?.container_env?.realtime_gateway?.env) || {};
  if (Object.keys(rtgEnv).length > 0) {
    const wsNoBufferUtil = parseBooleanish(rtgEnv.WS_NO_BUFFER_UTIL);
    const wsNoUtf8Validate = parseBooleanish(rtgEnv.WS_NO_UTF_8_VALIDATE);
    return {
      verified: true,
      active: !wsNoBufferUtil && !wsNoUtf8Validate,
      details: {
        WS_NO_BUFFER_UTIL: rtgEnv.WS_NO_BUFFER_UTIL || '',
        WS_NO_UTF_8_VALIDATE: rtgEnv.WS_NO_UTF_8_VALIDATE || '',
      },
      source: 'docker inspect env',
    };
  }

  return {
    verified: false,
    active: false,
    details: {},
    source: 'unknown',
  };
}

function assertWebsocketNativeAddonGuardrail(snapshot) {
  const status = readWebsocketNativeAddonStatus(snapshot);
  if (!status.verified) {
    throw new Error('websocket benchmark guardrail failed: unable to verify native addon status');
  }
  if (!status.active) {
    throw new Error(
      `websocket benchmark guardrail failed: native addons inactive (source=${status.source}, details=${JSON.stringify(
        status.details
      )})`
    );
  }
}

function writeRuntimeSnapshot(pathname, runtimeSnapshot) {
  fs.writeFileSync(pathname, `${JSON.stringify(runtimeSnapshot, null, 2)}\n`);
}

function nowUtcIso() {
  return new Date().toISOString();
}

function toFixedNumber(value, decimals = 6) {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Number(value.toFixed(decimals));
}

async function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  const cwd = process.cwd();
  const runId = runIdFromDate();
  const commandParts = ['node', path.relative(cwd, process.argv[1]), ...args];
  const commandString = commandParts.map(shellQuote).join(' ');
  const outDir = options.outDir
    ? path.resolve(cwd, options.outDir)
    : path.join(cwd, 'benchmarks', 'end-to-end', runId);
  const ctxMeta = collectRunContext(cwd);

  fs.mkdirSync(outDir, { recursive: true });
  if (!options.outDir) {
    const latestPath = path.join(cwd, 'benchmarks', 'end-to-end', 'latest-run.txt');
    fs.mkdirSync(path.dirname(latestPath), { recursive: true });
    fs.writeFileSync(latestPath, `${runId}\n`);
  }

  const summaryCsvPath = path.join(outDir, 'summary.csv');
  const reportPath = path.join(outDir, 'report.md');
  const manifestPath = path.join(outDir, 'manifest.json');
  const runtimeSnapshotPath = path.join(outDir, 'runtime_snapshot.json');

  const log = (message) => {
    process.stdout.write(`[${new Date().toISOString()}] ${message}\n`);
  };

  let precheckedGatewayHealth = null;
  if (!options.skipHealthChecks) {
    log(`Checking Sugar Glider readiness at ${options.sugarGliderUrl}/readyz`);
    const ready = await checkJsonEndpoint(`${stripTrailingSlash(options.sugarGliderUrl)}/readyz`, 'sugar-glider/readyz');
    if (!ready || ready.ready !== true) {
      throw new Error(`Sugar Glider not ready: ${JSON.stringify(ready)}`);
    }

    log(`Checking Realtime Gateway health at ${options.realtimeGatewayUrl}/health`);
    precheckedGatewayHealth = await checkJsonEndpoint(
      `${stripTrailingSlash(options.realtimeGatewayUrl)}/health`,
      'realtime-gateway/health'
    );
  }

  const pendingDeliveries = new Map();
  const resolvedEvents = { total: 0 };
  const socketEvents = [];

  const onSocketEvent = (eventName, eventData) => {
    if (eventName !== 'platform-event') {
      return;
    }
    socketEvents.push({
      timestamp_utc: nowUtcIso(),
      event_name: eventName,
      scenario_id: scenarioIdFromSocketEvent(eventData),
      event_id: eventIdFromSocketEvent(eventData),
    });
    const eventId = eventIdFromSocketEvent(eventData);
    if (!eventId) {
      return;
    }
    const waiter = pendingDeliveries.get(eventId);
    if (!waiter) {
      return;
    }
    pendingDeliveries.delete(eventId);
    clearTimeout(waiter.timeoutHandle);
    resolvedEvents.total += 1;
    waiter.resolve({
      ok: true,
      latencyMs: performance.now() - waiter.startedAtPerfMs,
      socketEvent: eventData,
      deliveredAtUtc: nowUtcIso(),
    });
  };

  const socketClient = createSocketClient({
    transport: options.socketTransport,
    baseUrl: options.realtimeGatewayUrl,
    socketPath: options.socketPath,
    onEvent: onSocketEvent,
    log,
  });

  const manifest = {
    benchmark: 'sugar-glider-end-to-end-gateway-delivery',
    timestamp_utc: nowUtcIso(),
    config: {
      payload_bytes: [...FIXED_MATRIX.payloadBytes],
      concurrency_levels: [...FIXED_MATRIX.concurrencyLevels],
      repetitions: FIXED_MATRIX.repetitions,
      warmup_ops: FIXED_MATRIX.warmupOps,
      measure_ops: FIXED_MATRIX.measureOps,
      delivery_timeout_ms: options.deliveryTimeoutMs,
      sugar_glider_url: options.sugarGliderUrl,
      realtime_gateway_url: options.realtimeGatewayUrl,
      socket_path: options.socketPath,
      socket_transport: options.socketTransport,
      stream: options.stream,
    },
    git: ctxMeta.git,
    environment: ctxMeta.environment,
    command: commandString,
    run_id: runId,
    runs: [],
    outputs: {
      manifest_json: manifestPath,
      summary_csv: summaryCsvPath,
      report_md: reportPath,
      runtime_snapshot_json: runtimeSnapshotPath,
    },
  };

  let runtimeSnapshot = null;
  let fatalError = null;
  try {
    runtimeSnapshot = await collectRuntimeSnapshot({
      options,
      precheckedGatewayHealth,
    });
    writeRuntimeSnapshot(runtimeSnapshotPath, runtimeSnapshot);
    manifest.runtime_snapshot = runtimeSnapshot;

    assertRequiredRuntimeSnapshots(runtimeSnapshot);
    if (options.socketTransport === 'websocket') {
      assertWebsocketNativeAddonGuardrail(runtimeSnapshot);
    }

    await socketClient.connect();
    await sleep(150);

    for (const payloadBytes of FIXED_MATRIX.payloadBytes) {
      for (const concurrency of FIXED_MATRIX.concurrencyLevels) {
        for (let repetition = 1; repetition <= FIXED_MATRIX.repetitions; repetition += 1) {
          const scenarioId = `t${options.socketTransport}-p${payloadBytes}-c${concurrency}-r${repetition}`;
          const baseName = `end_to_end_${options.socketTransport}_p${payloadBytes}_c${concurrency}_r${repetition}`;
          const rawPath = path.join(outDir, `${baseName}.json`);
          const outputLog = path.join(outDir, `${baseName}.log`);
          const started = new Date();
          const runStartPerf = performance.now();
          const runLogLines = [];
          const runLog = (message) => {
            const line = `[${new Date().toISOString()}] ${message}`;
            runLogLines.push(line);
            log(line);
          };

          const runRecord = {
            transport: `end_to_end_${options.socketTransport}`,
            payload_bytes: payloadBytes,
            concurrency,
            repetition,
            scenario_id: scenarioId,
            status: 'success',
            command: commandString,
            started_utc: started.toISOString(),
            finished_utc: null,
            duration_ms: null,
            output_json: rawPath,
            output_metrics_json: '',
            output_log: outputLog,
          };

          log(`Running scenario ${scenarioId}`);
          let scenarioResult = null;
          let scenarioError = null;
          try {
            scenarioResult = await runScenario({
              options,
              scenarioId,
              payloadBytes,
              concurrency,
              pendingDeliveries,
              log: runLog,
            });
          } catch (error) {
            runRecord.status = 'failed';
            scenarioError = String(error);
            runRecord.error = scenarioError;
          }

          runRecord.finished_utc = nowUtcIso();
          runRecord.duration_ms = Math.round(performance.now() - runStartPerf);
          fs.writeFileSync(outputLog, `${runLogLines.join('\n')}\n`);
          writeRawArtifact({
            outputPath: rawPath,
            runRecord,
            options,
            context: ctxMeta,
            scenarioResult,
            scenarioError,
          });
          manifest.runs.push(runRecord);
        }
      }
    }
  } catch (error) {
    fatalError = error;
  } finally {
    await socketClient.disconnect();
    if (pendingDeliveries.size) {
      for (const waiter of pendingDeliveries.values()) {
        clearTimeout(waiter.timeoutHandle);
        waiter.resolve({
          ok: false,
          timeout: true,
          message: 'run aborted before event delivery',
        });
      }
      pendingDeliveries.clear();
    }
  }

  const summaryRows = extractSummaryRows(manifest.runs);
  const aggregates = aggregateRows(summaryRows);
  writeSummaryCsv(summaryCsvPath, summaryRows);
  writeReport(reportPath, manifest, summaryRows, aggregates);

  if (fatalError) {
    manifest.status = 'failed';
    manifest.error = String(fatalError);
  } else {
    manifest.status = manifest.runs.every((run) => run.status === 'success') ? 'success' : 'partial_failure';
  }
  manifest.socket_event_matches = resolvedEvents.total;
  manifest.socket_events_observed = socketEvents.length;
  manifest.runtime_snapshot = runtimeSnapshot;
  manifest.timestamp_utc = nowUtcIso();
  writeManifest(manifestPath, manifest);

  if (fatalError) {
    throw fatalError;
  }

  log(`Benchmark complete. Output directory: ${outDir}`);
  log(`Manifest: ${manifestPath}`);
  log(`Summary CSV: ${summaryCsvPath}`);
  log(`Report: ${reportPath}`);
}

function stripTrailingSlash(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}

function shellQuote(value) {
  if (/^[A-Za-z0-9_./:@-]+$/.test(value)) {
    return value;
  }
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function runGitCommand(cwd, command) {
  try {
    return execSync(command, { cwd, stdio: ['ignore', 'pipe', 'ignore'] }).toString('utf8').trim();
  } catch {
    return '';
  }
}

function collectRunContext(cwd) {
  return {
    git: {
      commit_sha: runGitCommand(cwd, 'git rev-parse HEAD') || 'unknown',
      branch: runGitCommand(cwd, 'git rev-parse --abbrev-ref HEAD') || 'unknown',
      dirty: runGitCommand(cwd, 'git status --porcelain').length > 0,
    },
    environment: {
      hostname: os.hostname() || 'unknown',
      runner_cwd: cwd,
      node_version: process.version,
      node_exec_path: process.execPath,
      platform: process.platform,
      arch: process.arch,
      benchmark_node_version_target: process.env.BENCHMARK_NODE_VERSION || '',
      benchmark_node_bin_env: process.env.BENCHMARK_NODE_BIN || '',
    },
  };
}

function writeManifest(pathname, manifest) {
  fs.writeFileSync(pathname, `${JSON.stringify(manifest, null, 2)}\n`);
}

function writeRawArtifact({
  outputPath,
  runRecord,
  options,
  context,
  scenarioResult,
  scenarioError,
}) {
  let result = {
    status: 'missing',
    error: scenarioError || 'scenario result unavailable',
  };

  if (scenarioResult && typeof scenarioResult === 'object') {
    const measured = scenarioResult.measured || {};
    const totalEvents = Number(measured.total_events || 0);
    const successfulOps = Number(measured.delivered_events || 0);
    const failedOps = Math.max(0, totalEvents - successfulOps);
    result = {
      status: 'ok',
      metrics: {
        total_latency: {
          p50_ms: Number(measured.latency?.p50_ms || 0),
          p95_ms: Number(measured.latency?.p95_ms || 0),
          p99_ms: Number(measured.latency?.p99_ms || 0),
        },
        throughput_ops_per_sec: Number(measured.throughput_events_per_sec || 0),
        error_rate_pct: Number(measured.error_rate_pct || 0),
        successful_ops: successfulOps,
        failed_ops: failedOps,
        lost_events: Number(measured.lost_events || 0),
        publish_errors: Number(measured.publish_errors || 0),
        delivery_timeouts: Number(measured.delivery_timeouts || 0),
      },
      scenario: scenarioResult,
    };
  }

  const artifact = {
    schema_version: 'end-to-end-bench.raw.v1',
    transport: runRecord.transport,
    payload_bytes: runRecord.payload_bytes,
    concurrency: runRecord.concurrency,
    repetition: runRecord.repetition,
    command: runRecord.command,
    started_utc: runRecord.started_utc,
    finished_utc: runRecord.finished_utc,
    duration_ms: runRecord.duration_ms,
    config: {
      stream: options.stream,
      warmup_ops: FIXED_MATRIX.warmupOps,
      measure_ops: FIXED_MATRIX.measureOps,
      delivery_timeout_ms: options.deliveryTimeoutMs,
      sugar_glider_url: options.sugarGliderUrl,
      realtime_gateway_url: options.realtimeGatewayUrl,
      socket_path: options.socketPath,
      socket_transport: options.socketTransport,
    },
    git: context.git,
    environment: context.environment,
    result,
    status: runRecord.status,
    error: scenarioError || '',
  };

  fs.writeFileSync(outputPath, `${JSON.stringify(artifact, null, 2)}\n`);
}

async function runScenario({ options, scenarioId, payloadBytes, concurrency, pendingDeliveries, log }) {
  const runLog = typeof log === 'function' ? log : () => {};
  try {
    runLog(`Starting ${scenarioId} payload=${payloadBytes}B concurrency=${concurrency}`);
  } catch {
    // ignore logging failures
  }
  const scenarioRunId = `${scenarioId}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;

  const base = {
    benchmark: 'sugar-glider-end-to-end-gateway-delivery',
    timestamp_utc: nowUtcIso(),
    stream: options.stream,
    scenario_id: scenarioId,
    run_instance_id: scenarioRunId,
    payload_bytes_target: payloadBytes,
    concurrency,
    warmup_ops: options.warmupOps,
    measure_ops: options.measureOps,
    delivery_timeout_ms: options.deliveryTimeoutMs,
    socket_transport: options.socketTransport,
  };

  const warmup = await runPhase({
    options,
    phase: 'warmup',
    totalEvents: options.warmupOps,
    payloadBytes,
    concurrency,
    scenarioId,
    scenarioRunId,
    pendingDeliveries,
    collectLatencies: false,
  });

  const measured = await runPhase({
    options,
    phase: 'measured',
    totalEvents: options.measureOps,
    payloadBytes,
    concurrency,
    scenarioId,
    scenarioRunId,
    pendingDeliveries,
    collectLatencies: true,
  });

  const status = measured.delivered_events === options.measureOps && measured.publish_errors === 0 ? 'success' : 'degraded';
  return {
    ...base,
    status,
    warmup,
    measured,
  };
}

async function runPhase({
  options,
  phase,
  totalEvents,
  payloadBytes,
  concurrency,
  scenarioId,
  scenarioRunId,
  pendingDeliveries,
  collectLatencies,
}) {
  const latencies = [];
  const publishLatencies = [];
  let publishedEvents = 0;
  let deliveredEvents = 0;
  let publishErrors = 0;
  let deliveryTimeouts = 0;

  let nextIndex = 0;
  const phaseStartPerf = performance.now();
  const phaseStartUtc = nowUtcIso();

  async function worker() {
    while (true) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      if (currentIndex >= totalEvents) {
        return;
      }
      const eventId = `${scenarioRunId}-${phase}-${currentIndex}-${Math.random().toString(16).slice(2, 8)}`;
      const sentAtPerf = performance.now();

      const basePayload = {
        bench_scenario_id: scenarioId,
        bench_run_id: scenarioRunId,
        bench_phase: phase,
        bench_event_id: eventId,
        bench_sequence: currentIndex,
        bench_sent_utc: nowUtcIso(),
      };
      const { payload, actualBytes } = buildSizedPayload(basePayload, payloadBytes);

      const deliveryPromise = waitForDelivery({
        pendingDeliveries,
        eventId,
        timeoutMs: options.deliveryTimeoutMs,
      });

      let publishOk = false;
      try {
        const publishStarted = performance.now();
        await publishEvent({
          sugarGliderUrl: options.sugarGliderUrl,
          stream: options.stream,
          payload,
        });
        publishLatencies.push(performance.now() - publishStarted);
        publishOk = true;
        publishedEvents += 1;
      } catch {
        publishErrors += 1;
      }

      if (!publishOk) {
        cancelDeliveryWaiter({ pendingDeliveries, eventId });
        continue;
      }

      const delivery = await deliveryPromise;
      if (delivery.ok) {
        deliveredEvents += 1;
        if (collectLatencies) {
          latencies.push(delivery.latencyMs);
        }
      } else {
        deliveryTimeouts += 1;
      }

      if (collectLatencies && !delivery.ok) {
        latencies.push(performance.now() - sentAtPerf);
      }

      if (actualBytes !== payloadBytes && currentIndex === 0) {
        // keep deterministic payload size behavior transparent in raw result
        basePayload.bench_actual_payload_bytes = actualBytes;
      }
    }
  }

  const workers = [];
  for (let i = 0; i < concurrency; i += 1) {
    workers.push(worker());
  }
  await Promise.all(workers);

  const phaseEndPerf = performance.now();
  const phaseDurationMs = phaseEndPerf - phaseStartPerf;
  const stats = computeLatencyStats(latencies);
  const publishStats = computeLatencyStats(publishLatencies);
  const lostEvents = Math.max(0, totalEvents - deliveredEvents);
  const throughput = phaseDurationMs <= 0 ? 0 : deliveredEvents / (phaseDurationMs / 1000);
  const errorRatePct = totalEvents === 0 ? 0 : ((publishErrors + deliveryTimeouts) / totalEvents) * 100;

  return {
    phase,
    started_utc: phaseStartUtc,
    finished_utc: nowUtcIso(),
    duration_ms: Math.round(phaseDurationMs),
    total_events: totalEvents,
    published_events: publishedEvents,
    delivered_events: deliveredEvents,
    lost_events: lostEvents,
    publish_errors: publishErrors,
    delivery_timeouts: deliveryTimeouts,
    delivery_rate_pct: toFixedNumber(totalEvents === 0 ? 0 : (deliveredEvents / totalEvents) * 100, 4),
    throughput_events_per_sec: toFixedNumber(throughput, 4),
    error_rate_pct: toFixedNumber(errorRatePct, 4),
    latency: {
      avg_ms: toFixedNumber(stats.avg_ms, 6),
      min_ms: toFixedNumber(stats.min_ms, 6),
      p50_ms: toFixedNumber(stats.p50_ms, 6),
      p95_ms: toFixedNumber(stats.p95_ms, 6),
      p99_ms: toFixedNumber(stats.p99_ms, 6),
      max_ms: toFixedNumber(stats.max_ms, 6),
      count: stats.count,
    },
    publish_latency: {
      avg_ms: toFixedNumber(publishStats.avg_ms, 6),
      min_ms: toFixedNumber(publishStats.min_ms, 6),
      p50_ms: toFixedNumber(publishStats.p50_ms, 6),
      p95_ms: toFixedNumber(publishStats.p95_ms, 6),
      p99_ms: toFixedNumber(publishStats.p99_ms, 6),
      max_ms: toFixedNumber(publishStats.max_ms, 6),
      count: publishStats.count,
    },
    latency_samples_ms: collectLatencies ? latencies.map((value) => toFixedNumber(value, 6)) : [],
  };
}

function waitForDelivery({ pendingDeliveries, eventId, timeoutMs }) {
  return new Promise((resolve) => {
    const timeoutHandle = setTimeout(() => {
      pendingDeliveries.delete(eventId);
      resolve({
        ok: false,
        timeout: true,
      });
    }, timeoutMs);
    pendingDeliveries.set(eventId, {
      startedAtPerfMs: performance.now(),
      timeoutHandle,
      resolve,
    });
  });
}

function cancelDeliveryWaiter({ pendingDeliveries, eventId }) {
  const waiter = pendingDeliveries.get(eventId);
  if (!waiter) {
    return;
  }
  pendingDeliveries.delete(eventId);
  clearTimeout(waiter.timeoutHandle);
  waiter.resolve({ ok: false, canceled: true });
}

async function publishEvent({ sugarGliderUrl, stream, payload }) {
  const response = await fetch(`${stripTrailingSlash(sugarGliderUrl)}/v1/publish`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      stream,
      event_type: 'benchmark.gateway.delivery',
      sender: 'task-09-e2e-benchmark',
      priority: 'normal',
      payload,
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`publish failed (${response.status}): ${body}`);
  }
}

function extractSummaryRows(runs) {
  const rows = [];
  for (const run of runs) {
    const row = {
      transport: run.transport || `end_to_end_${DEFAULTS.socketTransport}`,
      payload_bytes: run.payload_bytes,
      concurrency: run.concurrency,
      repetition: run.repetition,
      p50_ms: 0,
      p95_ms: 0,
      p99_ms: 0,
      throughput_ops_per_sec: 0,
      error_rate_pct: 0,
      successful_ops: 0,
      failed_ops: 0,
      lost_events: 0,
      command: run.command,
      commit_sha: 'unknown',
      run_date_utc: run.started_utc,
      status: run.status,
    };

    if (!run.output_json || !fs.existsSync(run.output_json)) {
      rows.push(row);
      continue;
    }

    try {
      const artifact = JSON.parse(fs.readFileSync(run.output_json, 'utf8'));
      if (artifact?.git?.commit_sha) {
        row.commit_sha = artifact.git.commit_sha;
      }
      if (artifact?.result?.status === 'ok') {
        const metrics = artifact.result.metrics || {};
        row.p50_ms = Number(metrics.total_latency?.p50_ms || 0);
        row.p95_ms = Number(metrics.total_latency?.p95_ms || 0);
        row.p99_ms = Number(metrics.total_latency?.p99_ms || 0);
        row.throughput_ops_per_sec = Number(metrics.throughput_ops_per_sec || 0);
        row.error_rate_pct = Number(metrics.error_rate_pct || 0);
        row.successful_ops = Number(metrics.successful_ops || 0);
        row.failed_ops = Number(metrics.failed_ops || 0);
        row.lost_events = Number(metrics.lost_events || 0);
      }
    } catch (error) {
      row.status = 'failed';
      row.parse_error = String(error);
    }
    rows.push(row);
  }

  rows.sort((a, b) => {
    if (a.transport !== b.transport) {
      return a.transport.localeCompare(b.transport);
    }
    if (a.payload_bytes !== b.payload_bytes) {
      return a.payload_bytes - b.payload_bytes;
    }
    if (a.concurrency !== b.concurrency) {
      return a.concurrency - b.concurrency;
    }
    return a.repetition - b.repetition;
  });
  return rows;
}

function aggregateRows(rows) {
  const grouped = new Map();
  for (const row of rows) {
    const key = `${row.transport}:${row.payload_bytes}:${row.concurrency}`;
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }
    grouped.get(key).push(row);
  }

  const aggregate = [];
  for (const [key, bucket] of grouped.entries()) {
    const [transport, payloadRaw, concurrencyRaw] = key.split(':');
    const payloadBytes = Number(payloadRaw);
    const concurrency = Number(concurrencyRaw);
    aggregate.push({
      transport,
      payload_bytes: payloadBytes,
      concurrency,
      runs: bucket.length,
      p50_ms: mean(bucket.map((row) => row.p50_ms)),
      p95_ms: mean(bucket.map((row) => row.p95_ms)),
      p99_ms: mean(bucket.map((row) => row.p99_ms)),
      throughput_ops_per_sec: mean(bucket.map((row) => row.throughput_ops_per_sec)),
      error_rate_pct: mean(bucket.map((row) => row.error_rate_pct)),
      successful_ops: mean(bucket.map((row) => row.successful_ops)),
      failed_ops: mean(bucket.map((row) => row.failed_ops)),
      lost_events: mean(bucket.map((row) => row.lost_events)),
    });
  }

  aggregate.sort((a, b) => {
    if (a.transport !== b.transport) {
      return a.transport.localeCompare(b.transport);
    }
    if (a.payload_bytes !== b.payload_bytes) {
      return a.payload_bytes - b.payload_bytes;
    }
    return a.concurrency - b.concurrency;
  });
  return aggregate;
}

function writeSummaryCsv(summaryCsvPath, rows) {
  const header = [
    'transport',
    'payload_bytes',
    'concurrency',
    'repetition',
    'p50_ms',
    'p95_ms',
    'p99_ms',
    'throughput_ops_per_sec',
    'error_rate_pct',
    'successful_ops',
    'failed_ops',
    'lost_events',
    'command',
    'commit_sha',
    'run_date_utc',
    'status',
  ];
  const lines = [header.map(quoteCsvCell).join(',')];

  for (const row of rows) {
    lines.push(
      [
        row.transport,
        row.payload_bytes,
        row.concurrency,
        row.repetition,
        toFixedNumber(row.p50_ms, 6),
        toFixedNumber(row.p95_ms, 6),
        toFixedNumber(row.p99_ms, 6),
        toFixedNumber(row.throughput_ops_per_sec, 6),
        toFixedNumber(row.error_rate_pct, 6),
        toFixedNumber(row.successful_ops, 6),
        toFixedNumber(row.failed_ops, 6),
        toFixedNumber(row.lost_events, 6),
        row.command,
        row.commit_sha,
        row.run_date_utc,
        row.status,
      ]
        .map(quoteCsvCell)
        .join(',')
    );
  }

  fs.writeFileSync(summaryCsvPath, `${lines.join('\n')}\n`);
}

function writeReport(reportPath, manifest, rows, aggregates) {
  const lines = [];
  lines.push('# End-to-End Transport Benchmark Report');
  lines.push('');
  lines.push(`- generated_utc: \`${manifest.timestamp_utc}\``);
  lines.push(`- stream: \`${manifest.config.stream}\``);
  lines.push(`- matrix_payload_bytes: \`${manifest.config.payload_bytes.join(', ')}\``);
  lines.push(`- matrix_concurrency: \`${manifest.config.concurrency_levels.join(', ')}\``);
  lines.push(`- socket_transport: \`${manifest.config.socket_transport}\``);
  lines.push(`- repetitions: \`${manifest.config.repetitions}\``);
  lines.push(`- warmup_ops: \`${manifest.config.warmup_ops}\``);
  lines.push(`- measure_ops: \`${manifest.config.measure_ops}\``);
  lines.push('');
  lines.push('## Aggregated Metrics (mean across repetitions)');
  lines.push('');
  lines.push('| transport | payload_bytes | concurrency | runs | p50_ms | p95_ms | p99_ms | throughput_ops_per_sec | error_rate_pct | successful_ops_mean | failed_ops_mean | lost_events_mean |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (const item of aggregates) {
    lines.push(
      `| ${item.transport} | ${item.payload_bytes} | ${item.concurrency} | ${item.runs} | ${toFixedNumber(item.p50_ms, 4)} | ${toFixedNumber(item.p95_ms, 4)} | ${toFixedNumber(item.p99_ms, 4)} | ${toFixedNumber(item.throughput_ops_per_sec, 4)} | ${toFixedNumber(item.error_rate_pct, 4)} | ${toFixedNumber(item.successful_ops, 4)} | ${toFixedNumber(item.failed_ops, 4)} | ${toFixedNumber(item.lost_events, 4)} |`
    );
  }

  lines.push('');
  lines.push('## Raw Repetition Rows');
  lines.push('');
  lines.push('| transport | payload_bytes | concurrency | repetition | p50_ms | p95_ms | p99_ms | throughput_ops_per_sec | error_rate_pct | successful_ops | failed_ops | lost_events | commit_sha | run_date_utc | status |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|');
  for (const row of rows) {
    const sha = String(row.commit_sha || 'unknown').slice(0, 12);
    lines.push(
      `| ${row.transport} | ${row.payload_bytes} | ${row.concurrency} | ${row.repetition} | ${toFixedNumber(row.p50_ms, 4)} | ${toFixedNumber(row.p95_ms, 4)} | ${toFixedNumber(row.p99_ms, 4)} | ${toFixedNumber(row.throughput_ops_per_sec, 4)} | ${toFixedNumber(row.error_rate_pct, 4)} | ${toFixedNumber(row.successful_ops, 0)} | ${toFixedNumber(row.failed_ops, 0)} | ${toFixedNumber(row.lost_events, 0)} | \`${sha}\` | \`${row.run_date_utc}\` | ${row.status} |`
    );
  }
  fs.writeFileSync(reportPath, `${lines.join('\n')}\n`);
}

function mean(values) {
  if (!values.length) {
    return 0;
  }
  const total = values.reduce((acc, value) => acc + value, 0);
  return total / values.length;
}

main().catch((error) => {
  process.stderr.write(`ERROR: ${String(error)}\n`);
  process.exit(1);
});
