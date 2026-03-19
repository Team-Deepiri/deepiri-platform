import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '5012', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  database: {
    url: process.env.DATABASE_URL || 'postgresql://deepiri:deepiripassword@localhost:5432/deepiri',
  },

  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || 'redispassword',
  },

  storage: {
    provider: process.env.STORAGE_PROVIDER || 'minio',
    bucket: process.env.S3_BUCKET || 'ingestion-documents',
    region: process.env.S3_REGION || 'us-east-1',
    endpoint: process.env.S3_ENDPOINT || 'http://localhost:9000',
    accessKeyId: process.env.S3_ACCESS_KEY || 'minioadmin',
    secretAccessKey: process.env.S3_SECRET_KEY || 'minioadmin',
  },

  synapse: {
    url: process.env.SYNAPSE_URL || 'http://localhost:8002',
  },

  upload: {
    maxFileSizeMb: parseInt(process.env.MAX_FILE_SIZE_MB || '50', 10),
    allowedMimeTypes: (process.env.ALLOWED_MIME_TYPES || '').split(',').filter(Boolean).length > 0
      ? process.env.ALLOWED_MIME_TYPES!.split(',')
      : [
          'application/pdf',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/msword',
          'application/vnd.ms-excel',
          'text/csv',
          'text/plain',
          'application/json',
          'image/png',
          'image/jpeg',
        ],
  },
};
