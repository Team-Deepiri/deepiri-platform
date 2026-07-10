export interface RegistryEntry {
  name: string;
  repo?: string;
  healthUrl?: string;
  tier: 0 | 1 | 2 | 3;
  status: 'unknown' | 'healthy' | 'degraded' | 'down';
  lastSeen?: string;
  metadata?: Record<string, unknown>;
}

// Known in-network service base URLs health checks are allowed to target.
// registerService() accepts a caller-supplied healthUrl, so rather than just
// validating that string and re-using it, we look up the trusted base URL
// from this fixed map and only take the path/query off the caller's input --
// otherwise pollHealth()'s fetch would let a caller aim outbound requests at
// an arbitrary internal or external host (SSRF, CodeQL js/request-forgery).
const ALLOWED_HEALTH_BASE_URLS: Record<string, string> = {
  'api-gateway': 'http://api-gateway:5000',
  'auth-service': 'http://auth-service:5001',
  truss: 'http://truss:5002',
  registry: 'http://registry:5003',
  telemetry: 'http://telemetry:5004',
  'external-bridge-service': 'http://external-bridge-service:5006',
  jobs: 'http://jobs:5007',
  'realtime-gateway': 'http://realtime-gateway:5008',
  'language-intelligence-service': 'http://language-intelligence-service:5010',
  'messaging-service': 'http://messaging-service:5009',
  cyrex: 'http://cyrex:8000',
  synapse: 'http://synapse:8002',
  'sugar-glider': 'http://sugar-glider:8081',
};

/**
 * Resolves a caller-supplied healthUrl to a same-shape URL whose scheme and
 * host are taken from ALLOWED_HEALTH_BASE_URLS (a fixed, trusted value), not
 * from the input string -- only the path/query are carried over from the
 * caller. Returns undefined if the input doesn't name a known service.
 */
function resolveTrustedHealthUrl(value: string): string | undefined {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return undefined;
  }
  const trustedBase = ALLOWED_HEALTH_BASE_URLS[parsed.hostname];
  if (!trustedBase) {
    return undefined;
  }
  return new URL(parsed.pathname + parsed.search, trustedBase).toString();
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
    if (healthUrl && resolveTrustedHealthUrl(healthUrl) === undefined) {
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
      if (!entry.healthUrl) continue;
      const trustedUrl = resolveTrustedHealthUrl(entry.healthUrl);
      if (!trustedUrl) continue;
      try {
        const res = await fetch(trustedUrl, { signal: AbortSignal.timeout(5000) });
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
