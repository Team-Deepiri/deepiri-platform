export interface RegistryEntry {
  name: string;
  repo?: string;
  healthUrl?: string;
  tier: 0 | 1 | 2 | 3;
  status: 'unknown' | 'healthy' | 'degraded' | 'down';
  lastSeen?: string;
  metadata?: Record<string, unknown>;
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
    const entry: RegistryEntry = {
      name: payload.name,
      repo: payload.repo ?? existing?.repo,
      healthUrl: payload.healthUrl ?? existing?.healthUrl,
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
