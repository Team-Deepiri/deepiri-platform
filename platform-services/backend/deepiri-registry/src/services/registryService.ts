export interface RegistryEntry {
  name: string;
  repo?: string;
  healthUrl?: string;
  tier: 0 | 1 | 2 | 3;
  status: 'unknown' | 'healthy' | 'degraded' | 'down';
  lastSeen?: string;
  metadata?: Record<string, unknown>;
}

// Known in-network services' fixed health-check URLs. registerService()
// accepts a caller-supplied healthUrl, so rather than validate that string
// and re-use any part of it, we use its hostname only as a lookup key into
// this fixed map and return the corresponding constant URL untouched --
// nothing from the caller's input ends up in the request pollHealth() sends.
// Otherwise a caller could aim the registry server's outbound requests at an
// arbitrary internal or external host (SSRF, CodeQL js/request-forgery).
const ALLOWED_HEALTH_URLS: Record<string, string> = {
  'api-gateway': 'http://api-gateway:5000/health',
  'auth-service': 'http://auth-service:5001/health',
  truss: 'http://truss:5002/health',
  registry: 'http://registry:5003/health',
  telemetry: 'http://telemetry:5004/health',
  'external-bridge-service': 'http://external-bridge-service:5006/health',
  jobs: 'http://jobs:5007/health',
  'realtime-gateway': 'http://realtime-gateway:5008/health',
  'language-intelligence-service': 'http://language-intelligence-service:5010/health',
  'messaging-service': 'http://messaging-service:5009/health',
  cyrex: 'http://cyrex:8000/health',
  synapse: 'http://synapse:8002/health',
  'sugar-glider': 'http://sugar-glider:8081/health',
};

/**
 * Resolves a caller-supplied healthUrl to one of the fixed URLs in
 * ALLOWED_HEALTH_URLS, selected by hostname. The caller's path/query are
 * discarded entirely, not incorporated into the result -- returns undefined
 * if the input doesn't name a known service.
 */
function resolveTrustedHealthUrl(value: string): string | undefined {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return undefined;
  }
  return ALLOWED_HEALTH_URLS[parsed.hostname];
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
