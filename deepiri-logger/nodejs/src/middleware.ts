import type { Request, Response, NextFunction } from "express";
import type winston from "winston";

export function requestLogger(logger: winston.Logger) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const started = Date.now();
    const traceId = String(req.headers["x-trace-id"] ?? "");

    res.on("finish", () => {
      logger.info("HTTP request completed", {
        trace_id: traceId,
        method: req.method,
        path: req.originalUrl || req.url,
        status_code: res.statusCode,
        duration_ms: Date.now() - started,
      });
    });

    next();
  };
}
