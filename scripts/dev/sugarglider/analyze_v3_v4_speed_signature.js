#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULTS = {
  controlRuns: [
    'benchmarks/end-to-end/20260423T221540Z-heavy-path-boost-v3-fixed',
    'benchmarks/end-to-end/20260423T222329Z-heavy-path-boost-v3-fixed-repeat2',
  ],
  candidateRuns: [
    'benchmarks/end-to-end/20260427T020235Z-v4-iteration3-fastpath-run1',
    'benchmarks/end-to-end/20260427T020718Z-v4-iteration3-fastpath-run2',
  ],
};

function usage() {
  console.log(`Analyze Mark v3 vs Mark v4 speed signature

Builds a reproducible comparison package that highlights:
- throughput deltas by payload/concurrency cell
- p95 latency deltas by cell
- publish vs downstream p95 share shifts

Usage:
  node scripts/dev/sugarglider/analyze_v3_v4_speed_signature.js [options]

Options:
  --control-runs <csv>      Comma-separated run directories for Mark v3 control
  --candidate-runs <csv>    Comma-separated run directories for Mark v4 candidate
  --out-dir <dir>           Output directory (default: timestamped in benchmarks/end-to-end)
  -h, --help

Defaults:
  control-runs: ${DEFAULTS.controlRuns.join(',')}
  candidate-runs: ${DEFAULTS.candidateRuns.join(',')}
`);
}

function parseArgs(argv) {
  const options = {
    controlRuns: [...DEFAULTS.controlRuns],
    candidateRuns: [...DEFAULTS.candidateRuns],
    outDir: defaultOutDir(),
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--control-runs':
        options.controlRuns = parseCsvList(requireValue(arg, argv[++i]), arg);
        break;
      case '--candidate-runs':
        options.candidateRuns = parseCsvList(requireValue(arg, argv[++i]), arg);
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
  const items = value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (!items.length) {
    throw new Error(`Expected at least one value for ${flagName}`);
  }
  return items;
}

function defaultOutDir() {
  const runId = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return path.join('benchmarks', 'end-to-end', `${runId}-task3-v3-v4-speed-signature`);
}

function parseComparisonMeanRatio(runDir) {
  const csvPath = path.join(runDir, 'comparison_vs_20260412.csv');
  if (!fs.existsSync(csvPath)) {
    return null;
  }
  const rows = parseCsv(fs.readFileSync(csvPath, 'utf8'));
  if (!rows.length) {
    return null;
  }
  const values = rows
    .map((row) => Number(row.throughput_ratio_rerun_vs_baseline))
    .filter((value) => Number.isFinite(value) && value > 0);
  return values.length ? mean(values) : null;
}

function parseManifestNodeVersion(runDir) {
  const manifestPath = path.join(runDir, 'manifest.json');
  if (!fs.existsSync(manifestPath)) {
    return '';
  }
  try {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return String(manifest?.context?.environment?.node_version || manifest?.environment?.node_version || '');
  } catch {
    return '';
  }
}

function loadRunSet({ label, runDirs }) {
  const runSummaries = [];
  const samples = [];

  for (const rawRunDir of runDirs) {
    const runDir = path.resolve(rawRunDir);
    if (!fs.existsSync(runDir) || !fs.statSync(runDir).isDirectory()) {
      throw new Error(`[${label}] run directory not found: ${rawRunDir}`);
    }

    const files = fs
      .readdirSync(runDir)
      .filter((name) => /^end_to_end(?:_websocket)?_p\d+_c\d+_r\d+\.json$/.test(name))
      .sort();

    if (!files.length) {
      throw new Error(`[${label}] no raw benchmark artifacts found in ${rawRunDir}`);
    }

    let okCount = 0;
    for (const name of files) {
      const artifactPath = path.join(runDir, name);
      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
      if (artifact?.result?.status !== 'ok') {
        continue;
      }
      okCount += 1;
      const metrics = artifact.result.metrics || {};
      const measured = artifact?.result?.scenario?.measured || {};
      const totalEvents = Number(measured.total_events || 0);
      const deliveredEvents = Number(measured.delivered_events || 0);
      samples.push({
        run_id: path.basename(runDir),
        payload_bytes: Number(artifact.payload_bytes || 0),
        concurrency: Number(artifact.concurrency || 0),
        repetition: Number(artifact.repetition || 0),
        throughput_ops_per_sec: Number(metrics.throughput_ops_per_sec || measured.throughput_events_per_sec || 0),
        p95_ms: Number(metrics.total_latency?.p95_ms || measured.latency?.p95_ms || 0),
        publish_p95_ms: Number(measured.publish_latency?.p95_ms || 0),
        error_rate_pct: Number(metrics.error_rate_pct || measured.error_rate_pct || 0),
        lost_events: Number(metrics.lost_events || measured.lost_events || 0),
        failed_ops: Number(metrics.failed_ops || Math.max(0, totalEvents - deliveredEvents)),
      });
    }

    runSummaries.push({
      run_id: path.basename(runDir),
      raw_dir: rawRunDir,
      ok_samples: okCount,
      throughput_ratio_vs_20260412_mean: parseComparisonMeanRatio(runDir),
      node_version: parseManifestNodeVersion(runDir),
    });
  }

  return {
    label,
    runs: runSummaries,
    samples,
    cells: aggregateCells(samples),
  };
}

function aggregateCells(samples) {
  const grouped = new Map();
  for (const sample of samples) {
    const key = `${sample.payload_bytes}:${sample.concurrency}`;
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }
    grouped.get(key).push(sample);
  }

  const cells = [];
  for (const [key, bucket] of grouped.entries()) {
    const [payloadRaw, concurrencyRaw] = key.split(':');
    const throughputValues = bucket.map((sample) => sample.throughput_ops_per_sec);
    const p95Values = bucket.map((sample) => sample.p95_ms);
    const publishP95Values = bucket.map((sample) => sample.publish_p95_ms);
    const throughputMean = mean(throughputValues);
    const p95Mean = mean(p95Values);
    const publishP95Mean = mean(publishP95Values);
    const downstreamP95Mean = Math.max(0, p95Mean - publishP95Mean);
    const publishSharePct = p95Mean > 0 ? (publishP95Mean / p95Mean) * 100 : 0;
    const throughputStd = stddev(throughputValues);
    cells.push({
      payload_bytes: Number(payloadRaw),
      concurrency: Number(concurrencyRaw),
      samples: bucket.length,
      throughput_mean_ops_per_sec: throughputMean,
      throughput_std_ops_per_sec: throughputStd,
      throughput_cv_pct: throughputMean > 0 ? (throughputStd / throughputMean) * 100 : 0,
      p95_mean_ms: p95Mean,
      publish_p95_mean_ms: publishP95Mean,
      downstream_p95_mean_ms: downstreamP95Mean,
      publish_share_pct: publishSharePct,
      downstream_share_pct: Math.max(0, 100 - publishSharePct),
      error_rate_pct_mean: mean(bucket.map((sample) => sample.error_rate_pct)),
      lost_events_mean: mean(bucket.map((sample) => sample.lost_events)),
      failed_ops_mean: mean(bucket.map((sample) => sample.failed_ops)),
    });
  }

  cells.sort((a, b) => {
    if (a.payload_bytes !== b.payload_bytes) {
      return a.payload_bytes - b.payload_bytes;
    }
    return a.concurrency - b.concurrency;
  });
  return cells;
}

function buildComparison(controlCells, candidateCells) {
  const controlByKey = new Map(controlCells.map((row) => [cellKey(row), row]));
  const candidateByKey = new Map(candidateCells.map((row) => [cellKey(row), row]));
  const sharedKeys = [...controlByKey.keys()].filter((key) => candidateByKey.has(key));

  const rows = sharedKeys.map((key) => {
    const control = controlByKey.get(key);
    const candidate = candidateByKey.get(key);
    const throughputRatio =
      control.throughput_mean_ops_per_sec > 0
        ? candidate.throughput_mean_ops_per_sec / control.throughput_mean_ops_per_sec
        : 0;
    const p95Ratio = control.p95_mean_ms > 0 ? candidate.p95_mean_ms / control.p95_mean_ms : 0;
    return {
      payload_bytes: control.payload_bytes,
      concurrency: control.concurrency,
      control_throughput_ops_per_sec: control.throughput_mean_ops_per_sec,
      candidate_throughput_ops_per_sec: candidate.throughput_mean_ops_per_sec,
      throughput_ratio_candidate_vs_control: throughputRatio,
      throughput_delta_ops_per_sec: candidate.throughput_mean_ops_per_sec - control.throughput_mean_ops_per_sec,
      control_p95_ms: control.p95_mean_ms,
      candidate_p95_ms: candidate.p95_mean_ms,
      p95_ratio_candidate_vs_control: p95Ratio,
      control_publish_share_pct: control.publish_share_pct,
      candidate_publish_share_pct: candidate.publish_share_pct,
      publish_share_delta_pct_points: candidate.publish_share_pct - control.publish_share_pct,
      control_downstream_share_pct: control.downstream_share_pct,
      candidate_downstream_share_pct: candidate.downstream_share_pct,
      downstream_share_delta_pct_points: candidate.downstream_share_pct - control.downstream_share_pct,
      control_throughput_cv_pct: control.throughput_cv_pct,
      candidate_throughput_cv_pct: candidate.throughput_cv_pct,
      reliability_regressed:
        candidate.error_rate_pct_mean > control.error_rate_pct_mean ||
        candidate.lost_events_mean > control.lost_events_mean ||
        candidate.failed_ops_mean > control.failed_ops_mean,
    };
  });

  rows.sort((a, b) => {
    if (a.payload_bytes !== b.payload_bytes) {
      return a.payload_bytes - b.payload_bytes;
    }
    return a.concurrency - b.concurrency;
  });

  return rows;
}

function cellKey(row) {
  return `${row.payload_bytes}:${row.concurrency}`;
}

function writeCsv(filePath, rows, headers) {
  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map((header) => csvEscape(row[header])).join(','));
  }
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`);
}

function csvEscape(value) {
  if (value === undefined || value === null) {
    return '';
  }
  const stringValue = String(value);
  if (!/[,"\n]/.test(stringValue)) {
    return stringValue;
  }
  return `"${stringValue.replace(/"/g, '""')}"`;
}

function parseCsv(content) {
  const lines = content
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean);
  if (!lines.length) {
    return [];
  }
  const headers = lines[0].split(',').map((value) => value.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const cells = lines[i].split(',').map((value) => value.trim());
    const row = {};
    for (let j = 0; j < headers.length; j += 1) {
      row[headers[j]] = cells[j] || '';
    }
    rows.push(row);
  }
  return rows;
}

function writeMarkdownReport({ reportPath, controlSet, candidateSet, comparisonRows, options }) {
  const heavyRows = comparisonRows.filter((row) => row.payload_bytes === 32768);
  const meanThroughputRatio = mean(comparisonRows.map((row) => row.throughput_ratio_candidate_vs_control));
  const meanP95Ratio = mean(comparisonRows.map((row) => row.p95_ratio_candidate_vs_control));
  const heavyThroughputRatio = mean(heavyRows.map((row) => row.throughput_ratio_candidate_vs_control));
  const heavyP95Ratio = mean(heavyRows.map((row) => row.p95_ratio_candidate_vs_control));
  const heavyPublishShift = mean(heavyRows.map((row) => row.publish_share_delta_pct_points));
  const heavyDownstreamShift = mean(heavyRows.map((row) => row.downstream_share_delta_pct_points));
  const topRegressions = [...comparisonRows]
    .sort((a, b) => a.throughput_ratio_candidate_vs_control - b.throughput_ratio_candidate_vs_control)
    .slice(0, 3);

  const lines = [];
  lines.push('# Mark v3 vs Mark v4 Speed Signature Report');
  lines.push('');
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push('');
  lines.push('## Inputs');
  lines.push('');
  lines.push(`- Control runs: ${options.controlRuns.join(', ')}`);
  lines.push(`- Candidate runs: ${options.candidateRuns.join(', ')}`);
  lines.push(`- Matched cells: ${comparisonRows.length}`);
  lines.push('');
  lines.push('## High-Level Metrics');
  lines.push('');
  lines.push(`- Mean throughput ratio (candidate/control): ${formatRatio(meanThroughputRatio)}`);
  lines.push(`- Mean p95 ratio (candidate/control): ${formatRatio(meanP95Ratio)}`);
  lines.push(`- Heavy-path throughput ratio (32768B cells): ${formatRatio(heavyThroughputRatio)}`);
  lines.push(`- Heavy-path p95 ratio (32768B cells): ${formatRatio(heavyP95Ratio)}`);
  lines.push(`- Heavy-path publish-share shift: ${formatSignedPercentPoints(heavyPublishShift)}`);
  lines.push(`- Heavy-path downstream-share shift: ${formatSignedPercentPoints(heavyDownstreamShift)}`);
  lines.push('');
  lines.push('## Per-Run Baseline Ratios (vs 2026-04-12)');
  lines.push('');
  lines.push('| Set | Run | Mean Throughput Ratio | Node | Samples |');
  lines.push('|---|---|---:|---|---:|');
  for (const run of controlSet.runs) {
    lines.push(
      `| control | ${run.run_id} | ${formatRatio(run.throughput_ratio_vs_20260412_mean)} | ${run.node_version || 'unknown'} | ${run.ok_samples} |`
    );
  }
  for (const run of candidateSet.runs) {
    lines.push(
      `| candidate | ${run.run_id} | ${formatRatio(run.throughput_ratio_vs_20260412_mean)} | ${run.node_version || 'unknown'} | ${run.ok_samples} |`
    );
  }
  lines.push('');
  lines.push('## Heavy-Path Cells (32768B)');
  lines.push('');
  lines.push('| Cell | Throughput Ratio | p95 Ratio | Publish Share Delta | Downstream Share Delta | Control CV | Candidate CV |');
  lines.push('|---|---:|---:|---:|---:|---:|---:|');
  for (const row of heavyRows) {
    lines.push(
      `| 32768B @ c=${row.concurrency} | ${formatRatio(row.throughput_ratio_candidate_vs_control)} | ${formatRatio(row.p95_ratio_candidate_vs_control)} | ${formatSignedPercentPoints(row.publish_share_delta_pct_points)} | ${formatSignedPercentPoints(row.downstream_share_delta_pct_points)} | ${formatPct(row.control_throughput_cv_pct)} | ${formatPct(row.candidate_throughput_cv_pct)} |`
    );
  }
  lines.push('');
  lines.push('## Worst Throughput Regressions');
  lines.push('');
  lines.push('| Cell | Throughput Ratio | Throughput Delta (ops/s) | p95 Ratio |');
  lines.push('|---|---:|---:|---:|');
  for (const row of topRegressions) {
    lines.push(
      `| ${row.payload_bytes}B @ c=${row.concurrency} | ${formatRatio(row.throughput_ratio_candidate_vs_control)} | ${formatSignedNumber(row.throughput_delta_ops_per_sec)} | ${formatRatio(row.p95_ratio_candidate_vs_control)} |`
    );
  }
  lines.push('');
  lines.push('## Signature Readout');
  lines.push('');
  if (heavyThroughputRatio < 1 && heavyDownstreamShift > 0 && heavyPublishShift < 0) {
    lines.push('- Candidate loses heavy-path throughput while publish share falls and downstream share rises.');
    lines.push('- This indicates heavy-path bottlenecks are primarily downstream (delivery/dispatch/ack), not publish.');
  } else {
    lines.push('- Heavy-path signature is mixed; no single-stage conclusion is strong enough yet.');
  }
  if (meanP95Ratio > 1) {
    lines.push('- Candidate tail latency is higher overall than control, consistent with reduced throughput.');
  } else {
    lines.push('- Candidate tail latency is not globally worse than control.');
  }
  const cvRegressionCount = comparisonRows.filter(
    (row) => row.candidate_throughput_cv_pct > row.control_throughput_cv_pct
  ).length;
  lines.push(
    `- Throughput variance increased in ${cvRegressionCount}/${comparisonRows.length} matched cells.`
  );
  lines.push('');

  fs.writeFileSync(reportPath, `${lines.join('\n')}\n`);
}

function mean(values) {
  if (!values.length) {
    return 0;
  }
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function stddev(values) {
  if (values.length <= 1) {
    return 0;
  }
  const avg = mean(values);
  const variance = mean(values.map((value) => (value - avg) ** 2));
  return Math.sqrt(variance);
}

function formatRatio(value) {
  if (!Number.isFinite(value) || value <= 0) {
    return 'n/a';
  }
  return `${value.toFixed(4)}x`;
}

function formatPct(value) {
  if (!Number.isFinite(value)) {
    return 'n/a';
  }
  return `${value.toFixed(2)}%`;
}

function formatSignedPercentPoints(value) {
  if (!Number.isFinite(value)) {
    return 'n/a';
  }
  const prefix = value > 0 ? '+' : '';
  return `${prefix}${value.toFixed(2)} pp`;
}

function formatSignedNumber(value) {
  if (!Number.isFinite(value)) {
    return 'n/a';
  }
  const prefix = value > 0 ? '+' : '';
  return `${prefix}${value.toFixed(2)}`;
}

function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    const controlSet = loadRunSet({ label: 'control', runDirs: options.controlRuns });
    const candidateSet = loadRunSet({ label: 'candidate', runDirs: options.candidateRuns });
    const comparisonRows = buildComparison(controlSet.cells, candidateSet.cells);
    if (!comparisonRows.length) {
      throw new Error('No overlapping payload/concurrency cells between control and candidate sets.');
    }

    const outDir = path.resolve(options.outDir);
    fs.mkdirSync(outDir, { recursive: true });
    const csvPath = path.join(outDir, 'v3_v4_speed_signature.csv');
    const reportPath = path.join(outDir, 'v3_v4_speed_signature.md');

    writeCsv(csvPath, comparisonRows, [
      'payload_bytes',
      'concurrency',
      'control_throughput_ops_per_sec',
      'candidate_throughput_ops_per_sec',
      'throughput_ratio_candidate_vs_control',
      'throughput_delta_ops_per_sec',
      'control_p95_ms',
      'candidate_p95_ms',
      'p95_ratio_candidate_vs_control',
      'control_publish_share_pct',
      'candidate_publish_share_pct',
      'publish_share_delta_pct_points',
      'control_downstream_share_pct',
      'candidate_downstream_share_pct',
      'downstream_share_delta_pct_points',
      'control_throughput_cv_pct',
      'candidate_throughput_cv_pct',
      'reliability_regressed',
    ]);

    writeMarkdownReport({
      reportPath,
      controlSet,
      candidateSet,
      comparisonRows,
      options,
    });

    console.log(`Speed signature analysis complete.`);
    console.log(`Output directory: ${outDir}`);
    console.log(`CSV: ${csvPath}`);
    console.log(`Report: ${reportPath}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
