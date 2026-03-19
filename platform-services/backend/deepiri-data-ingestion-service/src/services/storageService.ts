import { S3Client, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { config } from '../config/environment';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import * as path from 'path';

export interface UploadResult {
  url: string;
  storageKey: string;
  fileSize: number;
  mimeType: string;
}

class StorageService {
  private s3Client: S3Client;
  private bucket: string;

  constructor() {
    this.bucket = config.storage.bucket;

    this.s3Client = new S3Client({
      endpoint: config.storage.endpoint,
      region: config.storage.region,
      credentials: {
        accessKeyId: config.storage.accessKeyId,
        secretAccessKey: config.storage.secretAccessKey,
      },
      forcePathStyle: true,
    });
  }

  async uploadFile(
    file: Express.Multer.File,
    folder: string = 'documents'
  ): Promise<UploadResult> {
    const ext = path.extname(file.originalname);
    const storageKey = `${folder}/${uuidv4()}${ext}`;
    const mimeType = file.mimetype || 'application/octet-stream';

    const upload = new Upload({
      client: this.s3Client,
      params: {
        Bucket: this.bucket,
        Key: storageKey,
        Body: file.buffer,
        ContentType: mimeType,
        Metadata: {
          originalName: file.originalname,
          uploadedAt: new Date().toISOString(),
        },
      },
    });

    await upload.done();

    const url = `${config.storage.endpoint}/${this.bucket}/${storageKey}`;

    logger.info('File uploaded to storage', { storageKey, fileSize: file.size, mimeType });

    return { url, storageKey, fileSize: file.size, mimeType };
  }

  async deleteFile(storageKey: string): Promise<void> {
    await this.s3Client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: storageKey })
    );
    logger.info('File deleted from storage', { storageKey });
  }
}

export const storageService = new StorageService();
