export interface RegistryEntry {
  name: string;
  repo?: string;
  healthUrl?: string;
  tier: 0 | 1 | 2 | 3;
  status: 'unknown' | 'healthy' | 'degraded' | 'down';
  lastSeen?: string;
  metadata?: Record<string, unknown>;
}

// Known in-network service hostnames health checks are allowed to target.
// registerService() accepts caller-supplied healthUrl values, so without this
// allowlist a caller could point pollHealth()'s fetch at an arbitrary internal
// or external host (SSRF) -- see CodeQL js/request-forgery.
const ALLOWED_HEALTH_HOSTS = new Set([
  'api-gateway',
  'auth-service',
  'truss',
  'registry',
  'telemetry',
  'external-bridge-service',
  'jobs',
  'realtime-gateway',
  'language-intelligence-service',
  'messaging-service',
  'cyrex',
  'synapse',
  'sugar-glider',
  'localhost',
  '127.0.0.1',
]);

function isAllowedHealthUrl(value: string): boolean {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return false;
  }
  return (parsed.protocol === 'http:' || parsed.protocol === 'https:') && ALLOWED_HEALTH_HOSTS.has(parsed.hostname);
}

const store = new Map<string, RegistryEntry>();

class RegistryService {
  listServices(): RegistryEntry[] {
    return Array.from(store.values());
  }

  getService(name: string): RegistryEntry | undefined {
    return store.get(name);
  }

  registerService(payload: Partial<RegistryEntry> & { name: string }): RegistryEntry {
    const existing = store.get(payload.name);
    const healthUrl = payload.healthUrl ?? existing?.healthUrl;
    if (healthUrl && !isAllowedHealthUrl(healthUrl)) {
      throw new Error(`Rejected healthUrl for "${payload.name}": host is not an allowed internal service.`);
    }
    const entry: RegistryEntry = {
      name: payload.name,
      repo: payload.repo ?? existing?.repo,
      healthUrl,
      tier: (payload.tier ?? existing?.tier ?? 1) as RegistryEntry['tier'],
      status: payload.status ?? existing?.status ?? 'unknown',
      lastSeen: new Date().toISOString(),
      metadata: payload.metadata ?? existing?.metadata,
    };
    store.set(entry.name, entry);
    return entry;
  }

  async pollHealth(): Promise<RegistryEntry[]> {
    const results: RegistryEntry[] = [];
    for (const entry of store.values()) {
      if (!entry.healthUrl || !isAllowedHealthUrl(entry.healthUrl)) continue;
      try {
        const res = await fetch(entry.healthUrl, { signal: AbortSignal.timeout(5000) });
        entry.status = res.ok ? 'healthy' : 'degraded';
      } catch {
        entry.status = 'down';
      }
      entry.lastSeen = new Date().toISOString();
      store.set(entry.name, entry);
      results.push(entry);
    }
    return results;
  }
}

export const registryService = new RegistryService();
