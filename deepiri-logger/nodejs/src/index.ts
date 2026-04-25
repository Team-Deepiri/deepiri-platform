import winston from "winston";
import { deepiriJsonFormat } from "./formatters";
import { requestLogger } from "./middleware";

export function createLogger(serviceName: string, version = "unknown"): winston.Logger {
  return winston.createLogger({
    level: process.env.LOG_LEVEL || "info",
    format: winston.format.combine(deepiriJsonFormat(serviceName, version), winston.format.json()),
    transports: [new winston.transports.Console()],
  });
}

export { requestLogger };
