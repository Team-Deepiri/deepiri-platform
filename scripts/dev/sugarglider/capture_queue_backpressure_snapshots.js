#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULTS = {
  sugarGliderUrl: 'http://localhost:8081',
  realtimeGatewayUrl: 'http://localhost:5008',
  intervalMs: 500,
  durationMs: 30000,
  label: 'task24-backpressure-snapshot',
};

function usage() {
  console.log(`Capture queue/backpressure telemetry snapshots

Usage:
  node scripts/dev/sugarglider/capture_queue_backpressure_snapshots.js [options]

Options:
  --sugar-glider-url <url>      Sugar Glider base URL (default: ${DEFAULTS.sugarGliderUrl})
  --realtime-gateway-url <url>  Realtime Gateway base URL (default: ${DEFAULTS.realtimeGatewayUrl})
  --interval-ms <n>             Sampling interval in ms (default: ${DEFAULTS.intervalMs})
  --duration-ms <n>             Total sampling duration in ms (default: ${DEFAULTS.durationMs})
  --label <text>                Label for output metadata (default: ${DEFAULTS.label})
  --out-dir <dir>               Output directory (default: timestamped under benchmarks/end-to-end)
  -h, --help
`);
}

function parseArgs(argv) {
  const options = {
    sugarGliderUrl: DEFAULTS.sugarGliderUrl,
    realtimeGatewayUrl: DEFAULTS.realtimeGatewayUrl,
    intervalMs: DEFAULTS.intervalMs,
    durationMs: DEFAULTS.durationMs,
    label: DEFAULTS.label,
    outDir: defaultOutDir(),
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
      case '--interval-ms':
        options.intervalMs = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--duration-ms':
        options.durationMs = parsePositiveInt(requireValue(arg, argv[++i]), arg);
        break;
      case '--label':
        options.label = requireValue(arg, argv[++i]);
        break;
      case '--out-dir':
        options.outDir = requireValue(arg, argv[++i]);
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

function parsePositiveInt(value, flagName) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0 || Math.floor(parsed) !== parsed) {
    throw new Error(`Expected positive integer for ${flagName}, received: ${value}`);
  }
  return parsed;
}

function defaultOutDir() {
  const runId = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return path.join('benchmarks', 'end-to-end', `${runId}-task24-backpressure-snapshots`);
}

function stripTrailingSlash(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}

async function fetchJson(url) {
  const response = await fetch(url, { method: 'GET' });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text}`);
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`non-JSON response (${String(error)})`);
  }
}

function asNumber(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return parsed;
}

function safeGet(root, keys, fallback = 0) {
  let value = root;
  for (const key of keys) {
    if (!value || typeof value !== 'object' || !(key in value)) {
      return fallback;
    }
    value = value[key];
  }
  return value;
}

function toCsv(rows, headers) {
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map((header) => csvEscape(row[header])).join(','));
  }
  return `${lines.join('\n')}\n`;
}

function csvEscape(value) {
  if (value === undefined || value === null) {
    return '';
  }
  const text = String(value);
  if (!/[,"\n]/.test(text)) {
    return text;
  }
  return `"${text.replace(/"/g, '""')}"`;
}

function mean(values) {
  if (!values.length) {
    return 0;
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function min(values) {
  if (!values.length) {
    return 0;
  }
  return Math.min(...values);
}

function max(values) {
  if (!values.length) {
    return 0;
  }
  return Math.max(...values);
}

function fixed(value, digits) {
  if (!Number.isFinite(value)) {
    return '0';
  }
  return Number(value.toFixed(digits));
}

async function captureOnce(options, startedMs) {
  const nowMs = Date.now();
  const elapsedMs = nowMs - startedMs;
  const row = {
    timestamp_utc: new Date(nowMs).toISOString(),
    elapsed_ms: elapsedMs,
    sample_ok: 1,
    sample_error: '',
    publish_pipeline_queue_depth: 0,
    dispatcher_ack_queue_depth_peak: 0,
    dispatcher_ack_flush_calls: 0,
    dispatcher_ack_exec_duration_ms_total: 0,
    dispatcher_read_duration_ms_total: 0,
    ack_rpc_requests: 0,
    acked_entries: 0,
    rtg_connections: 0,
    rtg_profile_total_events: 0,
    rtg_profile_bucket_count: 0,
    rtg_profile_32768_c10_events: 0,
    rtg_profile_32768_c50_events: 0,
  };

  try {
    const sugarConfig = await fetchJson(`${stripTrailingSlash(options.sugarGliderUrl)}/v1/config`);
    const rtgHealth = await fetchJson(`${stripTrailingSlash(options.realtimeGatewayUrl)}/health`);
    const rtgProfile = await fetchJson(`${stripTrailingSlash(options.realtimeGatewayUrl)}/v1/streaming/profile`);

    const metrics = safeGet(sugarConfig, ['metrics'], {});
    row.publish_pipeline_queue_depth = asNumber(safeGet(sugarConfig, ['publish_pipeline_queue_depth'], 0));
    row.dispatcher_ack_queue_depth_peak = asNumber(safeGet(metrics, ['dispatcher_ack_queue_depth_peak'], 0));
    row.dispatcher_ack_flush_calls = asNumber(safeGet(metrics, ['dispatcher_ack_flush_calls'], 0));
    row.dispatcher_ack_exec_duration_ms_total = asNumber(safeGet(metrics, ['dispatcher_ack_exec_duration_ms_total'], 0));
    row.dispatcher_read_duration_ms_total = asNumber(safeGet(metrics, ['dispatcher_read_duration_ms_total'], 0));
    row.ack_rpc_requests = asNumber(safeGet(metrics, ['ack_rpc_requests'], 0));
    row.acked_entries = asNumber(safeGet(metrics, ['acked_entries'], 0));

    row.rtg_connections = asNumber(safeGet(rtgHealth, ['connections'], 0));
    row.rtg_profile_total_events = asNumber(safeGet(rtgProfile, ['total_events_tracked'], 0));
    row.rtg_profile_bucket_count = asNumber(safeGet(rtgProfile, ['bucket_count'], 0));

    const buckets = Array.isArray(safeGet(rtgProfile, ['buckets'], [])) ? safeGet(rtgProfile, ['buckets'], []) : [];
    for (const bucket of buckets) {
      if (bucket?.bucket === '32768:10') {
        row.rtg_profile_32768_c10_events = asNumber(bucket?.events);
      } else if (bucket?.bucket === '32768:50') {
        row.rtg_profile_32768_c50_events = asNumber(bucket?.events);
      }
    }
  } catch (error) {
    row.sample_ok = 0;
    row.sample_error = String(error instanceof Error ? error.message : error);
  }

  return row;
}

function summarize(rows) {
  const okRows = rows.filter((row) => row.sample_ok === 1);
  const values = (key) => okRows.map((row) => asNumber(row[key]));
  const first = okRows[0] || null;
  const last = okRows[okRows.length - 1] || null;

  return {
    samples_total: rows.length,
    samples_ok: okRows.length,
    samples_failed: rows.length - okRows.length,
    publish_pipeline_queue_depth: {
      min: min(values('publish_pipeline_queue_depth')),
      avg: mean(values('publish_pipeline_queue_depth')),
      max: max(values('publish_pipeline_queue_depth')),
    },
    dispatcher_ack_queue_depth_peak: {
      min: min(values('dispatcher_ack_queue_depth_peak')),
      avg: mean(values('dispatcher_ack_queue_depth_peak')),
      max: max(values('dispatcher_ack_queue_depth_peak')),
    },
    dispatcher_ack_flush_calls_delta: first && last ? asNumber(last.dispatcher_ack_flush_calls) - asNumber(first.dispatcher_ack_flush_calls) : 0,
    dispatcher_ack_exec_duration_ms_total_delta:
      first && last
        ? asNumber(last.dispatcher_ack_exec_duration_ms_total) - asNumber(first.dispatcher_ack_exec_duration_ms_total)
        : 0,
    dispatcher_read_duration_ms_total_delta:
      first && last
        ? asNumber(last.dispatcher_read_duration_ms_total) - asNumber(first.dispatcher_read_duration_ms_total)
        : 0,
    ack_rpc_requests_delta: first && last ? asNumber(last.ack_rpc_requests) - asNumber(first.ack_rpc_requests) : 0,
    acked_entries_delta: first && last ? asNumber(last.acked_entries) - asNumber(first.acked_entries) : 0,
    rtg_profile_total_events_delta:
      first && last ? asNumber(last.rtg_profile_total_events) - asNumber(first.rtg_profile_total_events) : 0,
    rtg_profile_32768_c10_events_delta:
      first && last ? asNumber(last.rtg_profile_32768_c10_events) - asNumber(first.rtg_profile_32768_c10_events) : 0,
    rtg_profile_32768_c50_events_delta:
      first && last ? asNumber(last.rtg_profile_32768_c50_events) - asNumber(first.rtg_profile_32768_c50_events) : 0,
  };
}

function writeSummaryMarkdown(filePath, options, summary) {
  const lines = [];
  lines.push('# Queue and Backpressure Snapshot Summary');
  lines.push('');
  lines.push(`- generated_utc: \`${new Date().toISOString()}\``);
  lines.push(`- label: \`${options.label}\``);
  lines.push(`- sugar_glider_url: \`${options.sugarGliderUrl}\``);
  lines.push(`- realtime_gateway_url: \`${options.realtimeGatewayUrl}\``);
  lines.push(`- interval_ms: \`${options.intervalMs}\``);
  lines.push(`- duration_ms: \`${options.durationMs}\``);
  lines.push('');
  lines.push('## Sample Health');
  lines.push('');
  lines.push(`- samples_total: \`${summary.samples_total}\``);
  lines.push(`- samples_ok: \`${summary.samples_ok}\``);
  lines.push(`- samples_failed: \`${summary.samples_failed}\``);
  lines.push('');
  lines.push('## Queue/Depth Readout');
  lines.push('');
  lines.push(`- publish_pipeline_queue_depth min/avg/max: \`${fixed(summary.publish_pipeline_queue_depth.min, 2)} / ${fixed(summary.publish_pipeline_queue_depth.avg, 2)} / ${fixed(summary.publish_pipeline_queue_depth.max, 2)}\``);
  lines.push(`- dispatcher_ack_queue_depth_peak min/avg/max: \`${fixed(summary.dispatcher_ack_queue_depth_peak.min, 2)} / ${fixed(summary.dispatcher_ack_queue_depth_peak.avg, 2)} / ${fixed(summary.dispatcher_ack_queue_depth_peak.max, 2)}\``);
  lines.push('');
  lines.push('## Counter Deltas');
  lines.push('');
  lines.push(`- dispatcher_ack_flush_calls delta: \`${summary.dispatcher_ack_flush_calls_delta}\``);
  lines.push(`- dispatcher_ack_exec_duration_ms_total delta: \`${summary.dispatcher_ack_exec_duration_ms_total_delta}\``);
  lines.push(`- dispatcher_read_duration_ms_total delta: \`${summary.dispatcher_read_duration_ms_total_delta}\``);
  lines.push(`- ack_rpc_requests delta: \`${summary.ack_rpc_requests_delta}\``);
  lines.push(`- acked_entries delta: \`${summary.acked_entries_delta}\``);
  lines.push(`- rtg_profile_total_events delta: \`${summary.rtg_profile_total_events_delta}\``);
  lines.push(`- rtg_profile_32768_c10_events delta: \`${summary.rtg_profile_32768_c10_events_delta}\``);
  lines.push(`- rtg_profile_32768_c50_events delta: \`${summary.rtg_profile_32768_c50_events_delta}\``);
  lines.push('');
  lines.push('## Interpretation');
  lines.push('');
  lines.push('- Use sustained depth max/avg and counter deltas to locate where pressure accumulates during heavy probes.');
  lines.push('- Pair this output with benchmark latency/throughput rows to decide whether queue pressure is upstream publish-side or downstream delivery-side.');
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  fs.mkdirSync(options.outDir, { recursive: true });

  const startedMs = Date.now();
  const endMs = startedMs + options.durationMs;
  const rows = [];

  while (Date.now() <= endMs) {
    rows.push(await captureOnce(options, startedMs));
    if (Date.now() > endMs) {
      break;
    }
    await sleep(options.intervalMs);
  }

  const summary = summarize(rows);

  const jsonPath = path.join(options.outDir, 'queue_backpressure_snapshots.json');
  const csvPath = path.join(options.outDir, 'queue_backpressure_snapshots.csv');
  const summaryPath = path.join(options.outDir, 'queue_backpressure_summary.md');

  fs.writeFileSync(
    jsonPath,
    `${JSON.stringify({ generated_utc: new Date().toISOString(), options, summary, rows }, null, 2)}\n`
  );
  fs.writeFileSync(
    csvPath,
    toCsv(rows, [
      'timestamp_utc',
      'elapsed_ms',
      'sample_ok',
      'sample_error',
      'publish_pipeline_queue_depth',
      'dispatcher_ack_queue_depth_peak',
      'dispatcher_ack_flush_calls',
      'dispatcher_ack_exec_duration_ms_total',
      'dispatcher_read_duration_ms_total',
      'ack_rpc_requests',
      'acked_entries',
      'rtg_connections',
      'rtg_profile_total_events',
      'rtg_profile_bucket_count',
      'rtg_profile_32768_c10_events',
      'rtg_profile_32768_c50_events',
    ])
  );
  writeSummaryMarkdown(summaryPath, options, summary);

  console.log(`Output directory: ${options.outDir}`);
  console.log(`Snapshot JSON: ${jsonPath}`);
  console.log(`Snapshot CSV: ${csvPath}`);
  console.log(`Summary: ${summaryPath}`);
}

main().catch((error) => {
  console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
