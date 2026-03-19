"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
exports.secureLog = secureLog;
const winston_1 = __importDefault(require("winston"));
exports.logger = winston_1.default.createLogger({
    level: 'info',
    format: winston_1.default.format.json(),
    transports: [new winston_1.default.transports.Console({ format: winston_1.default.format.simple() })]
});
// List of sensitive field names
const SENSITIVE_FIELDS = [
    'password',
    'secret',
    'token',
    'key',
    'credential',
    'auth',
    'jwt',
    'api_key',
    'apiKey',
    'access_token',
    'refresh_token',
];
function sanitizeObject(obj, depth = 0) {
    if (depth > 10)
        return '[Max Depth Reached]';
    if (obj === null || obj === undefined) {
        return obj;
    }
    if (typeof obj === 'string') {
        // Check if string looks like a secret (long random string)
        if (obj.length > 20 && /^[a-zA-Z0-9+/=_-]+$/.test(obj)) {
            return '[REDACTED]';
        }
        return obj;
    }
    if (Array.isArray(obj)) {
        return obj.map(item => sanitizeObject(item, depth + 1));
    }
    if (typeof obj === 'object') {
        const sanitized = {};
        for (const [key, value] of Object.entries(obj)) {
            const lowerKey = key.toLowerCase();
            const isSensitive = SENSITIVE_FIELDS.some(field => lowerKey.includes(field));
            if (isSensitive) {
                sanitized[key] = '[REDACTED]';
            }
            else {
                sanitized[key] = sanitizeObject(value, depth + 1);
            }
        }
        return sanitized;
    }
    return obj;
}
function secureLog(level, message, data) {
    const sanitizedData = data ? sanitizeObject(data) : undefined;
    exports.logger[level](message, sanitizedData);
}
//# sourceMappingURL=secureLogger.js.map