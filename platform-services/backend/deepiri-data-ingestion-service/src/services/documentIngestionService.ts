import { PrismaClient, IngestionStatus, IngestionSourceType } from '@prisma/client';
import { storageService } from './storageService';
import { eventPublisher } from '../streaming/eventPublisher';
import { logger } from '../utils/logger';
import crypto from 'crypto';

const prisma = new PrismaClient();

export class DocumentIngestionService {
  async ingestDocument(userId: string, file: Express.Multer.File) {
    const record = await prisma.ingestionRecord.create({
      data: {
        userId,
        sourceType: IngestionSourceType.DOCUMENT,
        status: IngestionStatus.PENDING,
        metadata: { originalName: file.originalname, mimeType: file.mimetype },
      },
    });

    await eventPublisher.publishIngestionStarted(record.id, 'DOCUMENT');

    try {
      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.PROCESSING },
      });
      await eventPublisher.publishIngestionProcessing(record.id);

      const uploadResult = await storageService.uploadFile(file, 'ingestion/documents');
      const checksum = crypto.createHash('sha256').update(file.buffer).digest('hex');

      const doc = await prisma.ingestionDocument.create({
        data: {
          ingestionRecordId: record.id,
          fileName: file.originalname,
          mimeType: file.mimetype,
          storagePath: uploadResult.storageKey,
          storageUrl: uploadResult.url,
          fileSize: file.size,
          checksum,
        },
      });

      await eventPublisher.publishDocumentUploaded(record.id, doc.id, file.originalname);

      await prisma.ingestionRecord.update({
        where: { id: record.id },
        data: { status: IngestionStatus.COMPLETED },
      });

      await eventPublisher.publishIngestionCompleted(record.id, {
        documentId: doc.id,
        fileSize: file.size,
      });

      return { record: await this.getRecord(record.id), document: doc };
    } catch (error: any) {
      logger.error('Document ingestion failed', { recordId: record.id, error: error.message });
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
      include: { documents: true, structuredData: true },
    });
  }

  async listDocuments(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [records, total] = await Promise.all([
      prisma.ingestionRecord.findMany({
        where: { userId, sourceType: IngestionSourceType.DOCUMENT },
        include: { documents: true },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.ingestionRecord.count({
        where: { userId, sourceType: IngestionSourceType.DOCUMENT },
      }),
    ]);
    return { records, total, page, limit };
  }

  async deleteDocument(id: string, userId: string) {
    const record = await prisma.ingestionRecord.findFirst({
      where: { id, userId },
      include: { documents: true },
    });
    if (!record) throw new Error('Record not found');

    for (const doc of record.documents) {
      await storageService.deleteFile(doc.storagePath);
    }

    await prisma.ingestionRecord.delete({ where: { id } });
    return { deleted: true };
  }
}

export const documentIngestionService = new DocumentIngestionService();
