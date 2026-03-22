// scripts/test_gateways_node.js
// Usage: node scripts/test_gateways_node.js [apiBase] [realtimeBase]

const [
  ,,
  apiBase = process.env.API_GATEWAY_URL || 'http://localhost:5100',
  realtimeBase = process.env.REALTIME_GATEWAY_URL || 'http://localhost:5008'
] = process.argv;

const endpoints = [
  { name: 'api-gateway:/health', url: `${apiBase}/health` },
  { name: 'auth-service:/health (proxied)', url: `${apiBase}/auth/health` },
  { name: 'realtime-gateway:/health', url: `${realtimeBase}/health` }
];

async function run() {
  let failed = false;

  for (const ep of endpoints) {
    console.log(`\n--> GET ${ep.url}`);
    try {
      const res = await fetch(ep.url, { method: 'GET' });
      const text = await res.text();
      console.log(`  HTTP ${res.status}`);
      console.log(`  Body: ${text}`);
      if (res.status >= 400) failed = true;
    } catch (err) {
      console.error(`  ❌ ${ep.name} failed:`, err.message || err);
      failed = true;
    }
  }

  if (failed) {
    console.error('\nOne or more tests failed.');
    process.exit(1);
  }

  console.log('\nAll middleware tests passed.');
}

run();
