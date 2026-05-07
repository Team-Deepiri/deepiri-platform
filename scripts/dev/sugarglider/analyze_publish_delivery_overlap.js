#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULTS = {
  runDirs: [
    'benchmarks/end-to-end/20260427T034246Z-task5-rtg-hotpath-profile-run1',
    'benchmarks/end-to-end/20260427T035403Z-task6-sidecar-microtiming-run2',
  ],
};

function usage() {
  console.log(`Analyze publish-vs-delivery overlap from benchmark artifacts

Usage:
  node scripts/dev/sugarglider/analyze_publish_delivery_overlap.js [options]

Options:
  --run-dirs <csv>     Comma-separated benchmark run directories
  --out-dir <dir>      Output directory (default: timestamped under benchmarks/end-to-end)
  -h, --help

Defaults:
  run-dirs: ${DEFAULTS.runDirs.join(',')}
`);
}

function parseArgs(argv) {
  const options = {
    runDirs: [...DEFAULTS.runDirs],
    outDir: defaultOutDir(),
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--run-dirs':
        options.runDirs = parseCsvList(requireValue(arg, argv[++i]), arg);
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

function parseCsvList(value, flagName) {
  const out = value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (!out.length) {
    throw new Error(`Expected at least one value for ${flagName}`);
  }
  return out;
}

function defaultOutDir() {
  const runId = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return path.join('benchmarks', 'end-to-end', `${runId}-task23-publish-delivery-overlap`);
}

function runIdFromDir(runDir) {
  return path.basename(path.resolve(runDir));
}

function parseRawArtifacts(runDir) {
  const abs = path.resolve(runDir);
  if (!fs.existsSync(abs) || !fs.statSync(abs).isDirectory()) {
    throw new Error(`Run directory not found: ${runDir}`);
  }

  const files = fs
    .readdirSync(abs)
    .filter((name) => /^end_to_end(?:_websocket)?_p\d+_c\d+_r\d+\.json$/.test(name))
    .sort();

  if (!files.length) {
    throw new Error(`No raw benchmark artifacts found in ${runDir}`);
  }

  const rows = [];
  for (const file of files) {
    const fullPath = path.join(abs, file);
    const artifact = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    if (artifact?.result?.status !== 'ok') {
      continue;
    }
    const measured = artifact?.result?.scenario?.measured || {};
    const totalP95 = Number(artifact?.result?.metrics?.total_latency?.p95_ms || measured?.latency?.p95_ms || 0);
    const publishP95 = Number(measured?.publish_latency?.p95_ms || 0);
    const downstreamP95 = Math.max(0, totalP95 - publishP95);
    const publishSharePct = totalP95 > 0 ? (publishP95 / totalP95) * 100 : 0;
    const downstreamSharePct = Math.max(0, 100 - publishSharePct);

    rows.push({
      run_id: runIdFromDir(runDir),
      artifact: file,
      transport: String(artifact?.transport || ''),
      payload_bytes: Number(artifact?.payload_bytes || 0),
      concurrency: Number(artifact?.concurrency || 0),
      repetition: Number(artifact?.repetition || 0),
      throughput_ops_per_sec: Number(artifact?.result?.metrics?.throughput_ops_per_sec || 0),
      total_p95_ms: totalP95,
      publish_p95_ms: publishP95,
      downstream_p95_ms: downstreamP95,
      publish_share_pct: publishSharePct,
      downstream_share_pct: downstreamSharePct,
      error_rate_pct: Number(artifact?.result?.metrics?.error_rate_pct || 0),
      lost_events: Number(artifact?.result?.metrics?.lost_events || 0),
      failed_ops: Number(artifact?.result?.metrics?.failed_ops || 0),
    });
  }

  if (!rows.length) {
    throw new Error(`No successful benchmark rows found in ${runDir}`);
  }
  return rows;
}

function aggregate(rows, groupByRun) {
  const grouped = new Map();
  for (const row of rows) {
    const key = groupByRun
      ? `${row.run_id}:${row.payload_bytes}:${row.concurrency}`
      : `${row.payload_bytes}:${row.concurrency}`;
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }
    grouped.get(key).push(row);
  }

  const out = [];
  for (const [key, bucket] of grouped.entries()) {
    const parts = key.split(':');
    const payloadBytes = Number(parts[groupByRun ? 1 : 0]);
    const concurrency = Number(parts[groupByRun ? 2 : 1]);
    const runId = groupByRun ? parts[0] : 'all_runs';
    out.push({
      run_id: runId,
      payload_bytes: payloadBytes,
      concurrency,
      samples: bucket.length,
      throughput_ops_per_sec_mean: mean(bucket.map((r) => r.throughput_ops_per_sec)),
      total_p95_ms_mean: mean(bucket.map((r) => r.total_p95_ms)),
      publish_p95_ms_mean: mean(bucket.map((r) => r.publish_p95_ms)),
      downstream_p95_ms_mean: mean(bucket.map((r) => r.downstream_p95_ms)),
      publish_share_pct_mean: mean(bucket.map((r) => r.publish_share_pct)),
      downstream_share_pct_mean: mean(bucket.map((r) => r.downstream_share_pct)),
      error_rate_pct_mean: mean(bucket.map((r) => r.error_rate_pct)),
      lost_events_mean: mean(bucket.map((r) => r.lost_events)),
      failed_ops_mean: mean(bucket.map((r) => r.failed_ops)),
    });
  }

  out.sort((a, b) => {
    if (a.run_id !== b.run_id) {
      return a.run_id.localeCompare(b.run_id);
    }
    if (a.payload_bytes !== b.payload_bytes) {
      return a.payload_bytes - b.payload_bytes;
    }
    return a.concurrency - b.concurrency;
  });
  return out;
}

function writeCsv(filePath, rows, headers) {
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map((key) => csvEscape(row[key])).join(','));
  }
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

function writeMarkdown(filePath, runDirs, rawRows, runAggregate, combinedAggregate) {
  const lines = [];
  lines.push('# Publish vs Delivery Overlap Summary');
  lines.push('');
  lines.push(`- generated_utc: \`${new Date().toISOString()}\``);
  lines.push(`- source_run_count: \`${runDirs.length}\``);
  lines.push(`- source_runs: \`${runDirs.map((dir) => runIdFromDir(dir)).join(', ')}\``);
  lines.push(`- raw_rows: \`${rawRows.length}\``);
  lines.push('');

  lines.push('## Aggregated by Run and Cell');
  lines.push('');
  lines.push('| run_id | payload_bytes | concurrency | samples | throughput_ops_per_sec_mean | total_p95_ms_mean | publish_p95_ms_mean | downstream_p95_ms_mean | publish_share_pct_mean | downstream_share_pct_mean | error_rate_pct_mean |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (const row of runAggregate) {
    lines.push(
      `| ${row.run_id} | ${row.payload_bytes} | ${row.concurrency} | ${row.samples} | ${fixed(row.throughput_ops_per_sec_mean, 4)} | ${fixed(row.total_p95_ms_mean, 4)} | ${fixed(row.publish_p95_ms_mean, 4)} | ${fixed(row.downstream_p95_ms_mean, 4)} | ${fixed(row.publish_share_pct_mean, 2)} | ${fixed(row.downstream_share_pct_mean, 2)} | ${fixed(row.error_rate_pct_mean, 4)} |`
    );
  }

  lines.push('');
  lines.push('## Combined Cell View (All Runs)');
  lines.push('');
  lines.push('| payload_bytes | concurrency | samples | throughput_ops_per_sec_mean | total_p95_ms_mean | publish_p95_ms_mean | downstream_p95_ms_mean | publish_share_pct_mean | downstream_share_pct_mean |');
  lines.push('|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (const row of combinedAggregate) {
    lines.push(
      `| ${row.payload_bytes} | ${row.concurrency} | ${row.samples} | ${fixed(row.throughput_ops_per_sec_mean, 4)} | ${fixed(row.total_p95_ms_mean, 4)} | ${fixed(row.publish_p95_ms_mean, 4)} | ${fixed(row.downstream_p95_ms_mean, 4)} | ${fixed(row.publish_share_pct_mean, 2)} | ${fixed(row.downstream_share_pct_mean, 2)} |`
    );
  }

  const heavyRows = combinedAggregate
    .filter((row) => row.payload_bytes === 32768)
    .sort((a, b) => b.downstream_share_pct_mean - a.downstream_share_pct_mean);
  if (heavyRows.length) {
    lines.push('');
    lines.push('## Heavy-Path Readout (32768B)');
    lines.push('');
    for (const row of heavyRows) {
      lines.push(
        `- c=${row.concurrency}: publish_share=${fixed(row.publish_share_pct_mean, 2)}% downstream_share=${fixed(row.downstream_share_pct_mean, 2)}% total_p95=${fixed(row.total_p95_ms_mean, 4)}ms publish_p95=${fixed(row.publish_p95_ms_mean, 4)}ms`
      );
    }
  }

  fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

function fixed(value, digits) {
  if (!Number.isFinite(value)) {
    return '0';
  }
  return Number(value.toFixed(digits));
}

function mean(values) {
  if (!values.length) {
    return 0;
  }
  const total = values.reduce((sum, value) => sum + value, 0);
  return total / values.length;
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

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  ensureDir(options.outDir);

  const rawRows = [];
  for (const runDir of options.runDirs) {
    rawRows.push(...parseRawArtifacts(runDir));
  }

  const runAggregate = aggregate(rawRows, true);
  const combinedAggregate = aggregate(rawRows, false);

  const rawCsvPath = path.join(options.outDir, 'publish_delivery_overlap_raw.csv');
  const runCsvPath = path.join(options.outDir, 'publish_delivery_overlap_by_run_and_cell.csv');
  const combinedCsvPath = path.join(options.outDir, 'publish_delivery_overlap_combined_cells.csv');
  const summaryMdPath = path.join(options.outDir, 'publish_delivery_overlap_summary.md');

  writeCsv(rawCsvPath, rawRows, [
    'run_id',
    'artifact',
    'transport',
    'payload_bytes',
    'concurrency',
    'repetition',
    'throughput_ops_per_sec',
    'total_p95_ms',
    'publish_p95_ms',
    'downstream_p95_ms',
    'publish_share_pct',
    'downstream_share_pct',
    'error_rate_pct',
    'lost_events',
    'failed_ops',
  ]);
  writeCsv(runCsvPath, runAggregate, [
    'run_id',
    'payload_bytes',
    'concurrency',
    'samples',
    'throughput_ops_per_sec_mean',
    'total_p95_ms_mean',
    'publish_p95_ms_mean',
    'downstream_p95_ms_mean',
    'publish_share_pct_mean',
    'downstream_share_pct_mean',
    'error_rate_pct_mean',
    'lost_events_mean',
    'failed_ops_mean',
  ]);
  writeCsv(combinedCsvPath, combinedAggregate, [
    'run_id',
    'payload_bytes',
    'concurrency',
    'samples',
    'throughput_ops_per_sec_mean',
    'total_p95_ms_mean',
    'publish_p95_ms_mean',
    'downstream_p95_ms_mean',
    'publish_share_pct_mean',
    'downstream_share_pct_mean',
    'error_rate_pct_mean',
    'lost_events_mean',
    'failed_ops_mean',
  ]);
  writeMarkdown(summaryMdPath, options.runDirs, rawRows, runAggregate, combinedAggregate);

  console.log(`Output directory: ${options.outDir}`);
  console.log(`Raw CSV: ${rawCsvPath}`);
  console.log(`Run+cell CSV: ${runCsvPath}`);
  console.log(`Combined CSV: ${combinedCsvPath}`);
  console.log(`Summary: ${summaryMdPath}`);
}

try {
  main();
} catch (error) {
  console.error(`error: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
}
