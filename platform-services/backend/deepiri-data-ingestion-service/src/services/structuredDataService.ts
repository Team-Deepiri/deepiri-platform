import { PrismaClient, IngestionStatus, IngestionSourceType } from '@prisma/client';
import { eventPublisher } from '../streaming/eventPublisher';
import { logger } from '../utils/logger';
import { parse } from 'csv-parse/sync';

const prisma = new PrismaClient();

export class StructuredDataService {
  async ingestJson(userId: string, data: any, schemaName?: string) {
    const record = await prisma.ingestionRecord.create({
      data: {
        userId,
        sourceType: IngestionSourceType.JSON,
        status: IngestionStatus.PENDING,
        metadata: { schemaName },
      },
    });

    await eventPublisher.publishIngestionStarted(record.id, 'JSON');

    try {
      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.PROCESSING },
      });

      const rows = Array.isArray(data) ? data : [data];

      const structured = await prisma.structuredDataRecord.create({
        data: {
          ingestionRecordId: record.id,
          schemaName: schemaName || null,
          data: rows as any,
          rowCount: rows.length,
        },
      });

      await eventPublisher.publishDataReceived(record.id, schemaName, rows.length);

      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.COMPLETED },
      });

      await eventPublisher.publishIngestionCompleted(record.id, {
        structuredDataId: structured.id,
        rowCount: rows.length,
      });

      return { record: await this.getRecord(record.id), structuredData: structured };
    } catch (error: any) {
      logger.error('JSON ingestion failed', { recordId: record.id, error: error.message });
      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.FAILED, error: error.message },
      });
      await eventPublisher.publishIngestionFailed(record.id, error.message);
      throw error;
    }
  }

  async ingestCsv(userId: string, file: Express.Multer.File, schemaName?: string) {
    const csvContent = file.buffer.toString('utf-8');
    const rows = parse(csvContent, { columns: true, skip_empty_lines: true });

    const record = await prisma.ingestionRecord.create({
      data: {
        userId,
        sourceType: IngestionSourceType.CSV,
        status: IngestionStatus.PENDING,
        metadata: { schemaName, fileName: file.originalname },
      },
    });

    await eventPublisher.publishIngestionStarted(record.id, 'CSV');

    try {
      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.PROCESSING },
      });

      const structured = await prisma.structuredDataRecord.create({
        data: {
          ingestionRecordId: record.id,
          schemaName: schemaName || file.originalname.replace(/\.csv$/i, ''),
          data: rows as any,
          rowCount: rows.length,
        },
      });

      await eventPublisher.publishDataReceived(record.id, schemaName, rows.length);

      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.COMPLETED },
      });

      await eventPublisher.publishIngestionCompleted(record.id, {
        structuredDataId: structured.id,
        rowCount: rows.length,
      });

      return { record: await this.getRecord(record.id), structuredData: structured };
    } catch (error: any) {
      logger.error('CSV ingestion failed', { recordId: record.id, error: error.message });
      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.FAILED, error: error.message },
      });
      await eventPublisher.publishIngestionFailed(record.id, error.message);
      throw error;
    }
  }

  async getRecord(id: string) {
    return prisma.ingestionRecord.findUnique({
      where: { id },
      include: { structuredData: true },
    });
  }

  async listData(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [records, total] = await Promise.all([
      prisma.ingestionRecord.findMany({
        where: {
          userId,
          sourceType: { in: [IngestionSourceType.JSON, IngestionSourceType.CSV] },
        },
        include: { structuredData: true },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.ingestionRecord.count({
        where: {
          userId,
          sourceType: { in: [IngestionSourceType.JSON, IngestionSourceType.CSV] },
        },
      }),
    ]);
    return { records, total, page, limit };
  }
}

export const structuredDataService = new StructuredDataService();
