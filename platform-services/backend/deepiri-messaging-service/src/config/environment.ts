import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '5009', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  
  database: {
    url: process.env.DATABASE_URL || 'postgresql://user:password@localhost:5432/deepiri_messaging',
  },
  
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || '',
  },
  
  cyrex: {
    baseUrl: process.env.CYREX_URL || 'http://localhost:8000',
    apiKey: process.env.CYREX_API_KEY || 'change-me',
  },
  
  realtime: {
    gatewayUrl: process.env.REALTIME_GATEWAY_URL || 'http://localhost:5008',
  },
  
  auth: {
    // Auth is handled by API Gateway - this service just reads user context from headers
    enabled: false,
  },
};

