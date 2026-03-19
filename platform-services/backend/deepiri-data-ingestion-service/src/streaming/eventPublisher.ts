import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
import { config } from '../config/environment';
import { logger } from '../utils/logger';

let streamingClient: StreamingClient | null = null;

export async function initializeEventPublisher(): Promise<void> {
  try {
    streamingClient = new StreamingClient(
      config.redis.host,
      config.redis.port,
      config.redis.password
    );
    await streamingClient.connect();
    logger.info('Connected to Redis Streams for event publishing');
  } catch (error: any) {
    logger.error('Failed to initialize event publisher', { error: error.message });
    throw error;
  }
}

async function publishEvent(event: StreamEvent): Promise<void> {
  if (!streamingClient) await initializeEventPublisher();
  await streamingClient!.publish(StreamTopics.INGESTION_EVENTS, event);
}

function buildEvent(eventName: string, data: Record<string, any>): StreamEvent {
  return {
    event: eventName,
    timestamp: new Date().toISOString(),
    source: 'data-ingestion-service',
    service: 'data-ingestion',
    action: eventName,
    data,
  };
}

export async function publishIngestionStarted(recordId: string, sourceType: string): Promise<void> {
  await publishEvent(buildEvent('ingestion-started', { recordId, sourceType }));
  logger.info(`Published ingestion-started: ${recordId}`);
}

export async function publishDocumentUploaded(recordId: string, documentId: string, fileName: string): Promise<void> {
  await publishEvent(buildEvent('document-uploaded', { recordId, documentId, fileName }));
  logger.info(`Published document-uploaded: ${documentId}`);
}

export async function publishDataReceived(recordId: string, schemaName?: string, rowCount?: number): Promise<void> {
  await publishEvent(buildEvent('data-received', { recordId, schemaName, rowCount }));
  logger.info(`Published data-received: ${recordId}`);
}

export async function publishIngestionProcessing(recordId: string): Promise<void> {
  await publishEvent(buildEvent('ingestion-processing', { recordId }));
  logger.info(`Published ingestion-processing: ${recordId}`);
}

export async function publishIngestionCompleted(recordId: string, metadata?: Record<string, any>): Promise<void> {
  await publishEvent(buildEvent('ingestion-completed', { recordId, ...(metadata || {}) }));
  logger.info(`Published ingestion-completed: ${recordId}`);
}

export async function publishIngestionFailed(recordId: string, error: string): Promise<void> {
  await publishEvent(buildEvent('ingestion-failed', { recordId, error }));
  logger.error(`Published ingestion-failed: ${recordId}`);
}

export async function publishBatchStarted(batchId: string, batchSize: number): Promise<void> {
  await publishEvent(buildEvent('batch-started', { batchId, batchSize }));
  logger.info(`Published batch-started: ${batchId}`);
}

export async function publishBatchCompleted(batchId: string, completed: number, failed: number): Promise<void> {
  await publishEvent(buildEvent('batch-completed', { batchId, completed, failed }));
  logger.info(`Published batch-completed: ${batchId}`);
}

export const eventPublisher = {
  publishIngestionStarted,
  publishDocumentUploaded,
  publishDataReceived,
  publishIngestionProcessing,
  publishIngestionCompleted,
  publishIngestionFailed,
  publishBatchStarted,
  publishBatchCompleted,
};
