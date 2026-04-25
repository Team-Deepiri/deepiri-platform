import winston from "winston";

const emailRe = /([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g;
const bearerRe = /(bearer\s+)[A-Za-z0-9._\-+/=]+/gi;
const keyValueRe = /\b(api[_-]?key|token|secret|password)\b\s*[:=]\s*([\"']?)([^\s,;\"']+)/gi;
const sensitiveKeys = new Set([
  "api_key",
  "apikey",
  "token",
  "secret",
  "password",
  "authorization",
  "access_token",
  "refresh_token",
]);

function maskString(value: string): string {
  return value
    .replace(emailRe, "***@***")
    .replace(bearerRe, "$1***")
    .replace(keyValueRe, "$1=$2***");
}

export function scrubPii(value: unknown): unknown {
  if (typeof value === "string") return maskString(value);

  if (Array.isArray(value)) return value.map(scrubPii);

  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      const normalized = k.toLowerCase().replace(/-/g, "_");
      out[k] = sensitiveKeys.has(normalized) ? "***" : scrubPii(v);
    }
    return out;
  }

  return value;
}

export function deepiriJsonFormat(serviceName: string, version: string): winston.Logform.Format {
  return winston.format((info) => {
    const message = scrubPii(String(info.message ?? ""));
    const level = String(info.level ?? "info").toUpperCase();
    const traceId = String((info as any).trace_id ?? "");
    const context = scrubPii({ ...info });

    delete (context as any).level;
    delete (context as any).message;
    delete (context as any).timestamp;

    return {
      timestamp: new Date().toISOString(),
      level,
      service_name: serviceName,
      version,
      trace_id: traceId,
      message,
      context,
    } as any;
  })();
}
