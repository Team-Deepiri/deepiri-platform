import winston from 'winston';
export declare const logger: winston.Logger;
export declare function secureLog(level: 'info' | 'warn' | 'error', message: string, data?: any): void;
