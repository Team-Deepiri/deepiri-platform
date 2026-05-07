#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const DEFAULTS = {
  payloadBytes: [32768],
  concurrencyLevels: [1, 10],
  warmupOps: 500,
  measureOps: 5000,
  repetitions: 5,
  socketTransport: 'polling',
  benchmarkNodeVersion: '23.11.0',
};

const FORWARDED_VALUE_FLAGS = new Set([
  '--sugar-glider-url',
  '--realtime-gateway-url',
  '--socket-path',
  '--socket-transport',
  '--stream',
  '--delivery-timeout-ms',
  '--out-dir',
]);

const FORWARDED_BOOL_FLAGS = new Set(['--skip-health-checks']);

function usage() {
  console.log(`Sugar Glider targeted end-to-end probe

Runs the existing official benchmark engine with a temporary probe matrix.
The official e2e_gateway_benchmark.js file remains locked and unchanged.

Usage:
  node scripts/dev/sugarglider/e2e_gateway_probe.js [options]

Probe options:
  --payload-bytes <csv>             Payload sizes (default: ${DEFAULTS.payloadBytes.join(',')})
  --concurrency-levels <csv>        Concurrency levels (default: ${DEFAULTS.concurrencyLevels.join(',')})
  --warmup-ops <n>                  Warmup events per scenario (default: ${DEFAULTS.warmupOps})
  --measure-ops <n>                 Measured events per scenario (default: ${DEFAULTS.measureOps})
  --repetitions <n>                 Repetitions per cell (default: ${DEFAULTS.repetitions})
  --include-c50                     Add c=50 guardrail to the selected concurrency list
  --dry-run                         Validate matrix patching without running the benchmark

Runtime pinning:
  BENCHMARK_NODE_BIN               Explicit node binary for benchmark execution
  BENCHMARK_NODE_VERSION           Preferred pinned node version (default: ${DEFAULTS.benchmarkNodeVersion})
  BENCHMARK_NODE_PIN               Pinning toggle true|false (default: true)

Forwarded benchmark options:
  --sugar-glider-url <url>
  --realtime-gateway-url <url>
  --socket-path <path>
  --socket-transport <mode>
  --stream <name>
  --delivery-timeout-ms <n>
  --out-dir <dir>
  --skip-health-checks
  -h, --help

Examples:
  node scripts/dev/sugarglider/e2e_gateway_probe.js
  node scripts/dev/sugarglider/e2e_gateway_probe.js --include-c50
  node scripts/dev/sugarglider/e2e_gateway_probe.js --concurrency-levels 1,10 --repetitions 7
`);
}

function parseArgs(argv) {
  const probe = {
    payloadBytes: [...DEFAULTS.payloadBytes],
    concurrencyLevels: [...DEFAULTS.concurrencyLevels],
    warmupOps: DEFAULTS.warmupOps,
    measureOps: DEFAULTS.measureOps,
    repetitions: DEFAULTS.repetitions,
  };
  const forwarded = [];
  let hasOutDir = false;
  let dryRun = false;
  let socketTransport = DEFAULTS.socketTransport;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--payload-bytes':
        probe.payloadBytes = parsePositiveIntList(requireValue(arg, argv[++i]), arg);
        break;
      case '--concurrency-levels':
        probe.concurrencyLevels = parsePositiveIntList(requireValue(arg, argv[++i]), arg);
        break;
      case '--warmup-ops':
        probe.warmupOps = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--measure-ops':
        probe.measureOps = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--repetitions':
        probe.repetitions = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--include-c50':
        probe.concurrencyLevels = uniqueSorted([...probe.concurrencyLevels, 50]);
        break;
      case '--dry-run':
        dryRun = true;
        break;
      case '-h':
      case '--help':
        usage();
        process.exit(0);
      default:
        if (FORWARDED_VALUE_FLAGS.has(arg)) {
          const value = requireValue(arg, argv[++i]);
          if (arg === '--socket-transport') {
            socketTransport = parseSocketTransport(value, arg);
          }
          forwarded.push(arg, value);
          if (arg === '--out-dir') {
            hasOutDir = true;
          }
          break;
        }
        if (FORWARDED_BOOL_FLAGS.has(arg)) {
          forwarded.push(arg);
          break;
        }
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!hasOutDir) {
    forwarded.push('--out-dir', defaultOutDir());
  }

  return {
    probe: {
      ...probe,
      payloadBytes: uniqueSorted(probe.payloadBytes),
      concurrencyLevels: uniqueSorted(probe.concurrencyLevels),
    },
    forwarded,
    dryRun,
    socketTransport,
  };
}

function requireValue(flag, value) {
  if (!value || value.startsWith('--')) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function parsePositiveIntList(value, flagName) {
  const parsed = value
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => parsePositiveInt(part, flagName));
  if (!parsed.length) {
    throw new Error(`Expected at least one positive integer for ${flagName}`);
  }
  return parsed;
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

function parseBooleanish(value, fallback) {
  if (value === undefined || value === null || String(value).trim() === '') {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  if (normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on') {
    return true;
  }
  if (normalized === '0' || normalized === 'false' || normalized === 'no' || normalized === 'off') {
    return false;
  }
  return fallback;
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((a, b) => a - b);
}

function defaultOutDir() {
  const runId = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return path.join('benchmarks', 'end-to-end', `${runId}-mark-v3-heavy-probe`);
}

function unique(values) {
  return [...new Set(values.filter((value) => typeof value === 'string' && value.trim() !== ''))];
}

function inspectNodeRuntime(nodeBin) {
  const script =
    "process.stdout.write(JSON.stringify({version:process.version,execPath:process.execPath,websocketType:typeof WebSocket}))";
  const result = spawnSync(nodeBin, ['-e', script], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error) {
    return {
      ok: false,
      error: String(result.error),
      status: result.status,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  }
  if (result.status !== 0) {
    return {
      ok: false,
      error: `non-zero exit status ${result.status}`,
      status: result.status,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  }
  try {
    const parsed = JSON.parse(result.stdout || '{}');
    return {
      ok: true,
      version: parsed.version || 'unknown',
      execPath: parsed.execPath || nodeBin,
      websocketType: parsed.websocketType || 'undefined',
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  } catch (error) {
    return {
      ok: false,
      error: `failed to parse node runtime probe: ${String(error)}`,
      status: result.status,
      stdout: result.stdout || '',
      stderr: result.stderr || '',
    };
  }
}

function resolveBenchmarkNodeRuntime({ socketTransport }) {
  const requestedVersion = (process.env.BENCHMARK_NODE_VERSION || DEFAULTS.benchmarkNodeVersion).trim();
  const pinEnabled = parseBooleanish(process.env.BENCHMARK_NODE_PIN, true);
  const explicitNodeBin = (process.env.BENCHMARK_NODE_BIN || '').trim();
  const candidates = [];

  if (explicitNodeBin) {
    candidates.push(explicitNodeBin);
  }
  if (pinEnabled) {
    candidates.push(`/opt/homebrew/Cellar/node/${requestedVersion}/bin/node`);
    candidates.push(path.join(os.homedir(), '.nvm', 'versions', 'node', `v${requestedVersion}`, 'bin', 'node'));
  }
  candidates.push(process.execPath);
  candidates.push('node');

  const failures = [];
  for (const candidate of unique(candidates)) {
    const runtime = inspectNodeRuntime(candidate);
    if (!runtime.ok) {
      failures.push(`${candidate}: ${runtime.error}`);
      continue;
    }
    if (socketTransport === 'websocket' && runtime.websocketType !== 'function') {
      failures.push(
        `${candidate}: websocket transport requires WebSocket support (got typeof WebSocket=${runtime.websocketType})`
      );
      continue;
    }
    return {
      bin: candidate,
      version: runtime.version,
      execPath: runtime.execPath,
      websocketType: runtime.websocketType,
      pinEnabled,
      requestedVersion,
    };
  }

  throw new Error(
    `unable to resolve benchmark node runtime for socket_transport=${socketTransport}. ` +
      `Failures: ${failures.join(' | ')}`
  );
}

function buildPatchedSource(source, probe) {
  const matrixReplacement = `const FIXED_MATRIX = Object.freeze({
  payloadBytes: Object.freeze([${probe.payloadBytes.join(', ')}]),
  concurrencyLevels: Object.freeze([${probe.concurrencyLevels.join(', ')}]),
  warmupOps: ${probe.warmupOps},
  measureOps: ${probe.measureOps},
  repetitions: ${probe.repetitions},
});`;

  const next = source.replace(
    /const FIXED_MATRIX = Object\.freeze\(\{\n\s+payloadBytes: Object\.freeze\(\[[^\]]+\]\),\n\s+concurrencyLevels: Object\.freeze\(\[[^\]]+\]\),\n\s+warmupOps: \d+,\n\s+measureOps: \d+,\n\s+repetitions: \d+,\n\}\);/,
    matrixReplacement
  );

  if (next === source) {
    throw new Error('Unable to patch FIXED_MATRIX in e2e_gateway_benchmark.js');
  }
  return next.replace(
    "benchmark: 'sugar-glider-end-to-end-gateway-delivery'",
    "benchmark: 'sugar-glider-targeted-end-to-end-probe'"
  );
}

function run() {
  const { probe, forwarded, dryRun, socketTransport } = parseArgs(process.argv.slice(2));
  const repoRoot = path.resolve(__dirname, '..', '..', '..');
  const benchmarkPath = path.join(__dirname, 'e2e_gateway_benchmark.js');
  const source = fs.readFileSync(benchmarkPath, 'utf8');
  const patchedSource = buildPatchedSource(source, probe);
  const runtime = resolveBenchmarkNodeRuntime({ socketTransport });

  if (dryRun) {
    console.log(
      `[probe:dry-run] payload_bytes=${probe.payloadBytes.join(',')} concurrency=${probe.concurrencyLevels.join(',')} ` +
        `warmup_ops=${probe.warmupOps} measure_ops=${probe.measureOps} repetitions=${probe.repetitions}`
    );
    console.log(`[probe:dry-run] forwarded_args=${JSON.stringify(forwarded)}`);
    console.log(`[probe:dry-run] patched_bytes=${Buffer.byteLength(patchedSource, 'utf8')}`);
    console.log(
      `[probe:dry-run] node_bin=${runtime.bin} node_version=${runtime.version} websocket_type=${runtime.websocketType} ` +
        `pin_enabled=${runtime.pinEnabled} requested_version=${runtime.requestedVersion}`
    );
    return;
  }

  const tempPath = path.join(os.tmpdir(), `deepiri-sugar-glider-probe-${process.pid}.js`);

  fs.writeFileSync(tempPath, patchedSource, 'utf8');
  try {
    console.log(
      `[probe] payload_bytes=${probe.payloadBytes.join(',')} concurrency=${probe.concurrencyLevels.join(',')} ` +
        `warmup_ops=${probe.warmupOps} measure_ops=${probe.measureOps} repetitions=${probe.repetitions}`
    );
    console.log(
      `[probe] node_bin=${runtime.bin} node_version=${runtime.version} websocket_type=${runtime.websocketType} ` +
        `pin_enabled=${runtime.pinEnabled} requested_version=${runtime.requestedVersion}`
    );
    const result = spawnSync(runtime.bin, [tempPath, ...forwarded], {
      cwd: repoRoot,
      env: {
        ...process.env,
        BENCHMARK_NODE_VERSION: runtime.requestedVersion,
        BENCHMARK_NODE_BIN: runtime.bin,
      },
      stdio: 'inherit',
    });
    if (result.error) {
      throw result.error;
    }
    process.exit(result.status === null ? 1 : result.status);
  } finally {
    fs.rmSync(tempPath, { force: true });
  }
}

try {
  run();
} catch (error) {
  process.stderr.write(`ERROR: ${String(error)}\n`);
  process.exit(1);
}
