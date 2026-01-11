# Regulatory-Contract-Lease Language Intelligence Platform
## Complete Implementation Plan - Phases 1 & 2

---

## Executive Summary

**Platform**: Regulatory-Contract-Lease Language Intelligence Platform  
**Target Market**: $28-50B SAM (starting with $20-35B for core 4 features)  
**Buyers**: CCO, General Counsel, Real Estate leadership  
**Timeline**: 
- Phase 1: Months 1-6 (Lease Abstraction MVP)
- Phase 2: Months 7-12 (Contract Intelligence + Obligation Dependency Graph)

**Revenue Targets**: 
- Phase 1: $1-2M
- Phase 2: $3-5M

---

## PHASE 1: Lease Abstraction MVP - COMPLETE IMPLEMENTATION

### Phase 1.10: Document Service Implementation

**File**: `src/services/documentService.ts`

```typescript
import AWS from 'aws-sdk';
import { S3 } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { config } from '../config/environment';
import { logger } from '../utils/logger';
import pdf from 'pdf-parse';
import mammoth from 'mammoth';
import * as fs from 'fs';
import * as path from 'path';

export class DocumentService {
  private s3Client: S3;
  private bucketName: string;

  constructor() {
    this.bucketName = config.storage.bucket;
    
    if (config.storage.provider === 's3') {
      this.s3Client = new S3({
        region: config.storage.region,
        credentials: {
          accessKeyId: config.storage.accessKeyId,
          secretAccessKey: config.storage.secretAccessKey,
        },
      });
    } else if (config.storage.provider === 'minio') {
      // MinIO configuration
      this.s3Client = new S3({
        endpoint: config.storage.endpoint,
        region: config.storage.region,
        credentials: {
          accessKeyId: config.storage.accessKeyId,
          secretAccessKey: config.storage.secretAccessKey,
        },
        forcePathStyle: true, // Required for MinIO
      });
    }
  }

  /**
   * Upload document to S3/MinIO
   */
  async uploadDocument(
    file: Express.Multer.File,
    folder: string = 'documents'
  ): Promise<string> {
    try {
      const fileExtension = path.extname(file.originalname);
      const fileName = `${folder}/${Date.now()}-${file.originalname}`;
      
      const uploadParams = {
        Bucket: this.bucketName,
        Key: fileName,
        Body: file.buffer,
        ContentType: file.mimetype,
        Metadata: {
          originalName: file.originalname,
          uploadedAt: new Date().toISOString(),
        },
      };

      const upload = new Upload({
        client: this.s3Client,
        params: uploadParams,
      });

      await upload.done();

      const documentUrl = `s3://${this.bucketName}/${fileName}`;
      
      logger.info('Document uploaded', {
        fileName,
        size: file.size,
        url: documentUrl,
      });

      return documentUrl;
    } catch (error: any) {
      logger.error('Document upload failed', { error: error.message });
      throw new Error(`Failed to upload document: ${error.message}`);
    }
  }

  /**
   * Extract text from document
   */
  async extractText(documentUrl: string): Promise<string> {
    try {
      // Parse S3 URL
      const urlMatch = documentUrl.match(/s3:\/\/([^/]+)\/(.+)/);
      if (!urlMatch) {
        throw new Error('Invalid document URL format');
      }

      const [, bucket, key] = urlMatch;

      // Download file from S3
      const response = await this.s3Client.getObject({
        Bucket: bucket,
        Key: key,
      });

      const fileBuffer = await this.streamToBuffer(response.Body as any);
      const fileExtension = path.extname(key).toLowerCase();

      // Extract text based on file type
      let extractedText: string;

      switch (fileExtension) {
        case '.pdf':
          extractedText = await this.extractTextFromPDF(fileBuffer);
          break;
        case '.docx':
          extractedText = await this.extractTextFromDocx(fileBuffer);
          break;
        case '.doc':
          extractedText = await this.extractTextFromDoc(fileBuffer);
          break;
        case '.txt':
          extractedText = fileBuffer.toString('utf-8');
          break;
        default:
          throw new Error(`Unsupported file type: ${fileExtension}`);
      }

      logger.info('Text extracted from document', {
        documentUrl,
        textLength: extractedText.length,
      });

      return extractedText;
    } catch (error: any) {
      logger.error('Text extraction failed', {
        documentUrl,
        error: error.message,
      });
      throw new Error(`Failed to extract text: ${error.message}`);
    }
  }

  /**
   * Extract text from PDF
   */
  private async extractTextFromPDF(buffer: Buffer): Promise<string> {
    try {
      const data = await pdf(buffer);
      return data.text;
    } catch (error: any) {
      throw new Error(`PDF extraction failed: ${error.message}`);
    }
  }

  /**
   * Extract text from DOCX
   */
  private async extractTextFromDocx(buffer: Buffer): Promise<string> {
    try {
      const result = await mammoth.extractRawText({ buffer });
      return result.value;
    } catch (error: any) {
      throw new Error(`DOCX extraction failed: ${error.message}`);
    }
  }

  /**
   * Extract text from DOC (legacy Word format)
   */
  private async extractTextFromDoc(buffer: Buffer): Promise<string> {
    // For .doc files, we'd need a different library like 'textract' or convert to .docx first
    // For now, throw an error suggesting conversion
    throw new Error('DOC format not directly supported. Please convert to DOCX or PDF.');
  }

  /**
   * Stream to buffer helper
   */
  private async streamToBuffer(stream: any): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      stream.on('data', (chunk: Buffer) => chunks.push(chunk));
      stream.on('error', reject);
      stream.on('end', () => resolve(Buffer.concat(chunks)));
    });
  }

  /**
   * Get document metadata
   */
  async getDocumentMetadata(documentUrl: string): Promise<any> {
    try {
      const urlMatch = documentUrl.match(/s3:\/\/([^/]+)\/(.+)/);
      if (!urlMatch) {
        throw new Error('Invalid document URL format');
      }

      const [, bucket, key] = urlMatch;

      const response = await this.s3Client.headObject({
        Bucket: bucket,
        Key: key,
      });

      return {
        size: response.ContentLength,
        contentType: response.ContentType,
        lastModified: response.LastModified,
        metadata: response.Metadata,
      };
    } catch (error: any) {
      logger.error('Failed to get document metadata', { error: error.message });
      throw error;
    }
  }

  /**
   * Delete document
   */
  async deleteDocument(documentUrl: string): Promise<void> {
    try {
      const urlMatch = documentUrl.match(/s3:\/\/([^/]+)\/(.+)/);
      if (!urlMatch) {
        throw new Error('Invalid document URL format');
      }

      const [, bucket, key] = urlMatch;

      await this.s3Client.deleteObject({
        Bucket: bucket,
        Key: key,
      });

      logger.info('Document deleted', { documentUrl });
    } catch (error: any) {
      logger.error('Failed to delete document', { error: error.message });
      throw error;
    }
  }
}

export const documentService = new DocumentService();
```

**Add to `package.json` dependencies**:
```json
"aws-sdk": "^2.1500.0",
"@aws-sdk/client-s3": "^3.490.0",
"@aws-sdk/lib-storage": "^3.490.0",
"pdf-parse": "^1.1.1",
"mammoth": "^1.6.0"
```

---

### Phase 1.11: Obligation Service Implementation

**File**: `src/services/obligationService.ts`

```typescript
import { prisma } from '../db';
import { logger } from '../utils/logger';
import type { Obligation, Prisma } from '@prisma/client';

export interface CreateObligationInput {
  leaseId?: string;
  contractId?: string;
  description: string;
  obligationType: string;
  party?: string;
  deadline?: Date;
  startDate?: Date;
  endDate?: Date;
  frequency?: string;
  amount?: number;
  currency?: string;
  sourceClause?: string;
  confidence?: number;
  tags?: string[];
  notes?: string;
}

export class ObligationService {
  /**
   * Create obligation from abstraction result
   */
  async createObligationsFromAbstraction(
    leaseId: string,
    obligations: any[]
  ): Promise<Obligation[]> {
    const createdObligations: Obligation[] = [];

    for (const obl of obligations) {
      try {
        const obligation = await prisma.obligation.create({
          data: {
            leaseId,
            description: obl.description || '',
            obligationType: this.mapObligationType(obl.obligationType || obl.type),
            party: this.mapParty(obl.party),
            deadline: obl.deadline ? new Date(obl.deadline) : null,
            frequency: obl.frequency || obl.recurrencePattern,
            amount: obl.amount ? parseFloat(obl.amount.toString()) : null,
            currency: obl.currency || 'USD',
            sourceClause: obl.sourceClause || '',
            confidence: obl.confidence || 0.8,
            tags: obl.tags || [],
            notes: obl.notes,
            status: 'PENDING',
          },
        });

        createdObligations.push(obligation);
      } catch (error: any) {
        logger.error('Failed to create obligation', {
          leaseId,
          error: error.message,
          obligation: obl,
        });
        // Continue with other obligations
      }
    }

    logger.info('Obligations created from abstraction', {
      leaseId,
      count: createdObligations.length,
    });

    return createdObligations;
  }

  /**
   * Get obligations by lease ID
   */
  async getObligationsByLeaseId(leaseId: string): Promise<Obligation[]> {
    return prisma.obligation.findMany({
      where: { leaseId },
      orderBy: { deadline: 'asc' },
    });
  }

  /**
   * Get obligations by contract ID
   */
  async getObligationsByContractId(contractId: string): Promise<Obligation[]> {
    return prisma.obligation.findMany({
      where: { contractId },
      orderBy: { deadline: 'asc' },
    });
  }

  /**
   * Get overdue obligations
   */
  async getOverdueObligations(leaseId?: string, contractId?: string): Promise<Obligation[]> {
    const where: Prisma.ObligationWhereInput = {
      deadline: { lt: new Date() },
      status: { not: 'COMPLETED' },
    };

    if (leaseId) {
      where.leaseId = leaseId;
    }
    if (contractId) {
      where.contractId = contractId;
    }

    return prisma.obligation.findMany({
      where,
      orderBy: { deadline: 'asc' },
    });
  }

  /**
   * Update obligation status
   */
  async updateObligationStatus(
    obligationId: string,
    status: string,
    completedAt?: Date
  ): Promise<Obligation> {
    return prisma.obligation.update({
      where: { id: obligationId },
      data: {
        status: status as any,
        completedAt: completedAt || (status === 'COMPLETED' ? new Date() : null),
      },
    });
  }

  /**
   * Map obligation type from abstraction to database enum
   */
  private mapObligationType(type: string): string {
    const typeMap: Record<string, string> = {
      PAYMENT: 'PAYMENT',
      MAINTENANCE: 'MAINTENANCE',
      NOTIFICATION: 'NOTIFICATION',
      COMPLIANCE: 'COMPLIANCE',
      RENEWAL: 'RENEWAL',
      TERMINATION: 'TERMINATION',
      INSURANCE: 'INSURANCE',
      TAX: 'TAX',
      UTILITY: 'UTILITY',
      REPAIR: 'REPAIR',
      INSPECTION: 'INSPECTION',
    };

    return typeMap[type.toUpperCase()] || 'OTHER';
  }

  /**
   * Map party from abstraction to database format
   */
  private mapParty(party: string): string {
    const partyMap: Record<string, string> = {
      TENANT: 'TENANT',
      LANDLORD: 'LANDLORD',
      BOTH: 'BOTH',
    };

    return partyMap[party?.toUpperCase()] || 'TENANT';
  }
}

export const obligationService = new ObligationService();
```

---

### Phase 1.12: Event Publisher Implementation

**File**: `src/streaming/eventPublisher.ts`

```typescript
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
    logger.info('[Language Intelligence] Connected to Redis Streams');
  } catch (error: any) {
    logger.error('[Language Intelligence] Failed to initialize event publisher:', error);
    throw error;
  }
}

export async function publishLeaseCreated(leaseId: string, leaseNumber: string): Promise<void> {
  if (!streamingClient) await initializeEventPublisher();
  
  const event: StreamEvent = {
    event: 'lease-created',
    timestamp: new Date().toISOString(),
    source: 'language-intelligence-service',
    service: 'language-intelligence',
    action: 'lease-created',
    data: { leaseId, leaseNumber },
  };
  
  await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
  logger.info(`[Language Intelligence] Published lease-created: ${leaseId}`);
}

export async function publishLeaseProcessed(
  leaseId: string,
  metadata: { processingTimeMs: number; confidence: number }
): Promise<void> {
  if (!streamingClient) await initializeEventPublisher();
  
  const event: StreamEvent = {
    event: 'lease-processed',
    timestamp: new Date().toISOString(),
    source: 'language-intelligence-service',
    service: 'language-intelligence',
    action: 'lease-processed',
    data: { leaseId, ...metadata },
  };
  
  await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
  logger.info(`[Language Intelligence] Published lease-processed: ${leaseId}`);
}

export async function publishLeaseProcessingError(
  leaseId: string,
  error: string
): Promise<void> {
  if (!streamingClient) await initializeEventPublisher();
  
  const event: StreamEvent = {
    event: 'lease-processing-error',
    timestamp: new Date().toISOString(),
    source: 'language-intelligence-service',
    service: 'language-intelligence',
    action: 'lease-processing-error',
    data: { leaseId, error },
  };
  
  await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
  logger.error(`[Language Intelligence] Published lease-processing-error: ${leaseId}`);
}

export async function publishLeaseVersionCreated(
  leaseId: string,
  versionId: string,
  versionNumber: number
): Promise<void> {
  if (!streamingClient) await initializeEventPublisher();
  
  const event: StreamEvent = {
    event: 'lease-version-created',
    timestamp: new Date().toISOString(),
    source: 'language-intelligence-service',
    service: 'language-intelligence',
    action: 'lease-version-created',
    data: { leaseId, versionId, versionNumber },
  };
  
  await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
  logger.info(`[Language Intelligence] Published lease-version-created: ${versionId}`);
}

export const eventPublisher = {
  publishLeaseCreated,
  publishLeaseProcessed,
  publishLeaseProcessingError,
  publishLeaseVersionCreated,
};
```

---

### Phase 1.13: Server Setup & Middleware

**File**: `src/server.ts`

```typescript
import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import winston from 'winston';
import multer from 'multer';
import routes from './routes';
import { connectDatabase } from './db';
import { initializeEventPublisher } from './streaming/eventPublisher';
import { logger } from './utils/logger';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5003', 10);

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// File upload configuration
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

// Add multer to request for file uploads
app.use((req: Request, res: Response, next) => {
  (req as any).upload = upload;
  next();
});

// Database connection
connectDatabase()
  .catch((err: Error) => {
    logger.error('Language Intelligence Service: Failed to connect to PostgreSQL', err);
    process.exit(1);
  });

// Initialize event publisher
initializeEventPublisher().catch((err) => {
  logger.error('Failed to initialize event publisher:', err);
});

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ 
    status: 'healthy', 
    service: 'language-intelligence-service', 
    timestamp: new Date().toISOString() 
  });
});

// Routes
app.use('/api/v1', routes);

// Error handler
const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  logger.error('Language Intelligence Service error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
};
app.use(errorHandler);

app.listen(PORT, () => {
  logger.info(`Language Intelligence Service running on port ${PORT}`);
});

export default app;
```

**File**: `src/index.ts`

```typescript
import './server';
```

---

### Phase 1.14: Middleware Implementation

**File**: `src/routes/middleware/auth.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import axios from 'axios';
import { config } from '../../config/environment';
import { logger } from '../../utils/logger';

export interface AuthUser {
  id: string;
  email: string;
  organizationId?: string;
  role?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      res.status(401).json({ error: 'No authentication token provided' });
      return;
    }

    // Verify token with auth service
    const response = await axios.get(`${config.auth.authServiceUrl}/api/v1/auth/verify`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    req.user = response.data.user;
    next();
  } catch (error: any) {
    logger.error('Authentication failed', { error: error.message });
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

**File**: `src/routes/middleware/validation.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';

export function handleValidationErrors(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    res.status(400).json({
      error: 'Validation failed',
      errors: errors.array(),
    });
    return;
  }
  
  next();
}
```

---

## PHASE 2: Contract Intelligence + Obligation Dependency Graph (Months 7-12)

### Phase 2 Overview

**Goal**: Add contract clause evolution tracking and obligation dependency graph.

**Why These Next**:
- Synergy with leases—clause evolution tracking naturally extends to lease clauses
- Obligation-dependency graph is a zero-competition differentiator that shows cascade effects from contracts to leases
- Together, these give you "contract-to-lease" intelligence that competitors lack

**Success Metrics**:
- Process 50+ contracts/month
- Track clause evolution across versions
- Build dependency graphs for 100+ obligations
- 3+ enterprise customers

---

### Phase 2.1: Database Schema Extensions

**Add to** `prisma/schema.prisma`:

```prisma
// ============================================
// PHASE 2: CONTRACT INTELLIGENCE MODELS
// ============================================

model Contract {
  id                String        @id @default(uuid()) @db.Uuid
  contractNumber    String        @unique @db.VarChar(100)
  contractName      String        @db.VarChar(255)
  partyA            String        @db.VarChar(255)
  partyB            String        @db.VarChar(255)
  contractType      String?       @map("contract_type") @db.VarChar(100) // "SERVICE", "SUPPLY", "MSA", "NDA", etc.
  jurisdiction      String?       @db.VarChar(100)
  documentUrl       String        @map("document_url") @db.Text
  rawText           String        @map("raw_text") @db.Text
  status            ContractStatus @default(PENDING) @db.VarChar(50)
  
  // Abstracted data
  abstractedTerms   Json?         @map("abstracted_terms")
  keyClauses        Json?         @map("key_clauses")
  financialTerms    Json?         @map("financial_terms")
  
  // Processing metadata
  processingStatus  String?       @map("processing_status") @db.VarChar(50)
  processingError   String?       @map("processing_error") @db.Text
  processedAt       DateTime?     @map("processed_at") @db.Timestamp
  processingTimeMs  Int?          @map("processing_time_ms")
  extractionConfidence Float?    @map("extraction_confidence") @db.DoublePrecision
  
  // User/tenant information
  userId            String?       @map("user_id") @db.Uuid
  organizationId    String?       @map("organization_id") @db.Uuid
  
  // Metadata
  tags              String[]      @default([])
  notes             String?       @db.Text
  metadata          Json?         @default("{}")
  createdAt         DateTime      @default(now()) @map("created_at") @db.Timestamp
  updatedAt         DateTime      @updatedAt @map("updated_at") @db.Timestamp
  createdBy         String?       @map("created_by") @db.Uuid
  updatedBy         String?       @map("updated_by") @db.Uuid
  
  // Relations
  clauses           Clause[]
  versions          ContractVersion[]
  obligations       Obligation[]
  dependencies      ObligationDependency[] @relation("SourceContract")
  targetDependencies ObligationDependency[] @relation("TargetContract")
  
  @@index([contractNumber])
  @@index([partyA])
  @@index([partyB])
  @@index([status])
  @@index([userId])
  @@index([organizationId])
  @@map("contracts")
}

model Clause {
  id                String        @id @default(uuid()) @db.Uuid
  contractId        String        @map("contract_id") @db.Uuid
  clauseNumber      String?       @map("clause_number") @db.VarChar(50)
  clauseType        String        @map("clause_type") @db.VarChar(100) // "TERMINATION", "PAYMENT", "LIABILITY", "INDEMNIFICATION", etc.
  clauseTitle       String?       @map("clause_title") @db.VarChar(255)
  clauseText        String        @map("clause_text") @db.Text
  versionNumber     Int           @map("version_number")
  extractedAt       DateTime      @default(now()) @map("extracted_at") @db.Timestamp
  
  // Evolution tracking
  previousVersionId String?       @map("previous_version_id") @db.Uuid
  changes           Json?         // What changed from previous version
  changeType        String?       @map("change_type") @db.VarChar(50) // "ADDED", "MODIFIED", "DELETED", "UNCHANGED"
  changeSummary     String?       @map("change_summary") @db.Text
  significantChange Boolean       @default(false) @map("significant_change")
  
  // Metadata
  confidence        Float?         @db.DoublePrecision
  sourceSection     String?       @map("source_section") @db.VarChar(100)
  pageNumber        Int?          @map("page_number")
  tags              String[]      @default([])
  metadata          Json?         @default("{}")
  
  // Relations
  contract          Contract       @relation(fields: [contractId], references: [id], onDelete: Cascade)
  previousVersion   Clause?        @relation("ClauseVersions", fields: [previousVersionId], references: [id])
  nextVersions      Clause[]       @relation("ClauseVersions")
  regulationMappings RegulationMapping[]
  
  @@index([contractId, versionNumber])
  @@index([clauseType])
  @@index([changeType])
  @@index([previousVersionId])
  @@map("clauses")
}

model ContractVersion {
  id                String        @id @default(uuid()) @db.Uuid
  contractId        String        @map("contract_id") @db.Uuid
  versionNumber     Int           @map("version_number")
  documentUrl       String        @map("document_url") @db.Text
  rawText           String        @map("raw_text") @db.Text
  abstractedTerms   Json          @map("abstracted_terms")
  
  // Change tracking
  changes           Json?         // Diff from previous version
  changeSummary     String?       @map("change_summary") @db.Text
  changeType        String?       @map("change_type") @db.VarChar(50) // "AMENDMENT", "RENEWAL", "TERMINATION", "NEW_VERSION"
  significantChanges Boolean      @default(false) @map("significant_changes")
  
  // Processing metadata
  processedAt       DateTime      @default(now()) @map("processed_at") @db.Timestamp
  processingTimeMs Int?          @map("processing_time_ms")
  
  // Metadata
  metadata          Json?         @default("{}")
  createdAt         DateTime      @default(now()) @map("created_at") @db.Timestamp
  createdBy         String?       @map("created_by") @db.Uuid
  
  // Relations
  contract          Contract       @relation(fields: [contractId], references: [id], onDelete: Cascade)
  
  @@unique([contractId, versionNumber])
  @@index([contractId])
  @@index([versionNumber])
  @@index([processedAt])
  @@map("contract_versions")
}

model ObligationDependency {
  id                String        @id @default(uuid()) @db.Uuid
  sourceObligationId String       @map("source_obligation_id") @db.Uuid
  targetObligationId String       @map("target_obligation_id") @db.Uuid
  dependencyType    DependencyType @map("dependency_type") @db.VarChar(50)
  description       String?       @db.Text
  
  // Source and target context
  sourceContractId  String?       @map("source_contract_id") @db.Uuid
  targetContractId  String?       @map("target_contract_id") @db.Uuid
  sourceLeaseId      String?       @map("source_lease_id") @db.Uuid
  targetLeaseId      String?       @map("target_lease_id") @db.Uuid
  
  // Dependency strength and metadata
  confidence        Float?         @db.DoublePrecision // 0-1 confidence in dependency
  strength          String?        @db.VarChar(50) // "STRONG", "MODERATE", "WEAK"
  conditions        Json?          // Conditions under which dependency applies
  triggerEvents     String[]      @default([]) @map("trigger_events") // Events that trigger dependency
  
  // Cascade analysis
  cascadeDepth      Int?           @default(1) @map("cascade_depth") // How many levels deep
  cascadeImpact     String?         @map("cascade_impact") @db.VarChar(50) // "HIGH", "MEDIUM", "LOW"
  
  // Metadata
  detectedAt        DateTime       @default(now()) @map("detected_at") @db.Timestamp
  detectedBy        String?       @map("detected_by") @db.VarChar(100) // "AI", "MANUAL", "RULE"
  verified          Boolean        @default(false)
  verifiedBy        String?        @map("verified_by") @db.Uuid
  verifiedAt        DateTime?      @map("verified_at") @db.Timestamp
  tags              String[]       @default([])
  notes             String?        @db.Text
  metadata          Json?          @default("{}")
  
  // Relations
  sourceObligation   Obligation    @relation("SourceObligations", fields: [sourceObligationId], references: [id], onDelete: Cascade)
  targetObligation   Obligation    @relation("TargetObligations", fields: [targetObligationId], references: [id], onDelete: Cascade)
  sourceContract     Contract?     @relation("SourceContract", fields: [sourceContractId], references: [id])
  targetContract     Contract?     @relation("TargetContract", fields: [targetContractId], references: [id])
  
  @@unique([sourceObligationId, targetObligationId])
  @@index([sourceObligationId])
  @@index([targetObligationId])
  @@index([sourceContractId])
  @@index([targetContractId])
  @@index([dependencyType])
  @@index([cascadeImpact])
  @@map("obligation_dependencies")
}

enum ContractStatus {
  PENDING
  PROCESSING
  COMPLETED
  ERROR
  ARCHIVED
}

enum DependencyType {
  TRIGGERS      // Source obligation triggers target
  BLOCKS        // Source obligation blocks target
  MODIFIES      // Source obligation modifies target
  REQUIRES      // Source obligation requires target
  PRECEDES      // Source obligation must occur before target
  ENABLES       // Source obligation enables target
  INVALIDATES   // Source obligation invalidates target
}
```

**Update Obligation model** (add relations):

```prisma
model Obligation {
  // ... existing fields ...
  
  // Relations (Phase 2 additions)
  contract          Contract?     @relation(fields: [contractId], references: [id], onDelete: Cascade)
  sourceDependencies ObligationDependency[] @relation("SourceObligations")
  targetDependencies ObligationDependency[] @relation("TargetObligations")
  
  // ... rest of model ...
}
```

---

### Phase 2.2: Contract Document Processor

**File**: `deepiri-platform/diri-cyrex/app/services/document_processors/contract_processor.py`

```python
"""
Contract Document Processor
Extracts structured data from contract documents using LLM
"""
from typing import Dict, Any, Optional, List
import json
import re
from datetime import datetime

from ...logging_config import get_logger
from ...integrations.llm_providers import get_llm_provider
from ...integrations.rag_pipeline import RAGPipeline

logger = get_logger("cyrex.contract_processor")


class ContractProcessor:
    """
    Process contract documents and extract structured terms
    
    Extracts:
    - Contract parties and details
    - Key clauses with types
    - Financial terms
    - Obligations
    - Termination conditions
    - Liability and indemnification terms
    """
    
    def __init__(self, llm_provider=None, rag_pipeline: Optional[RAGPipeline] = None):
        self.llm_provider = llm_provider or get_llm_provider()
        self.rag_pipeline = rag_pipeline
        
        self.extraction_prompt = """You are an expert contract analyst. Extract structured data from the following contract document.

Contract Document Text:
{document_text}

Extract the following information and return as JSON:

{{
  "parties": {{
    "partyA": {{
      "name": "string",
      "entityType": "CORPORATION|LLC|INDIVIDUAL|PARTNERSHIP",
      "contactInfo": {{"email": "string", "phone": "string"}}
    }},
    "partyB": {{
      "name": "string",
      "entityType": "CORPORATION|LLC|INDIVIDUAL|PARTNERSHIP",
      "contactInfo": {{"email": "string", "phone": "string"}}
    }}
  }},
  "contractDetails": {{
    "contractType": "SERVICE|SUPPLY|MSA|NDA|LICENSE|PARTNERSHIP|OTHER",
    "jurisdiction": "string",
    "governingLaw": "string",
    "effectiveDate": "YYYY-MM-DD",
    "expirationDate": "YYYY-MM-DD",
    "autoRenewal": boolean,
    "renewalTerms": "string"
  }},
  "financialTerms": {{
    "paymentTerms": "string",
    "paymentSchedule": [
      {{"amount": number, "currency": "USD", "dueDate": "YYYY-MM-DD", "milestone": "string"}}
    ],
    "lateFees": "string",
    "terminationFees": "string",
    "penalties": "string"
  }},
  "clauses": [
    {{
      "clauseNumber": "string",
      "clauseType": "TERMINATION|PAYMENT|LIABILITY|INDEMNIFICATION|CONFIDENTIALITY|NON_COMPETE|FORCE_MAJEURE|DISPUTE_RESOLUTION|INTELLECTUAL_PROPERTY|WARRANTY|OTHER",
      "clauseTitle": "string",
      "clauseText": "string",
      "appliesTo": "PARTY_A|PARTY_B|BOTH",
      "section": "string",
      "pageNumber": number
    }}
  ],
  "obligations": [
    {{
      "description": "string",
      "obligationType": "PAYMENT|DELIVERY|PERFORMANCE|NOTIFICATION|COMPLIANCE|RENEWAL|TERMINATION|CONFIDENTIALITY|OTHER",
      "party": "PARTY_A|PARTY_B|BOTH",
      "deadline": "YYYY-MM-DD",
      "frequency": "ONE_TIME|MONTHLY|QUARTERLY|ANNUAL",
      "amount": number,
      "currency": "USD",
      "conditions": "string",
      "triggers": ["string"],
      "dependencies": ["string"]
    }}
  ],
  "terminationTerms": {{
    "terminationRights": [
      {{"party": "PARTY_A|PARTY_B|BOTH", "conditions": "string", "noticeRequired": number}}
    ],
    "terminationPenalties": "string",
    "survivalClauses": ["string"]
  }},
  "liabilityTerms": {{
    "limitationOfLiability": "string",
    "indemnification": [
      {{"indemnifyingParty": "PARTY_A|PARTY_B", "indemnifiedParty": "PARTY_A|PARTY_B", "scope": "string"}}
    ],
    "insuranceRequirements": [
      {{"type": "GENERAL_LIABILITY|PROFESSIONAL|ERRORS_OMISSIONS", "minimumCoverage": number, "requiredBy": "PARTY_A|PARTY_B"}}
    ]
  }},
  "intellectualProperty": {{
    "ownership": "string",
    "licenses": [
      {{"licensor": "PARTY_A|PARTY_B", "licensee": "PARTY_A|PARTY_B", "scope": "string"}}
    ],
    "restrictions": ["string"]
  }},
  "disputeResolution": {{
    "governingLaw": "string",
    "jurisdiction": "string",
    "arbitration": boolean,
    "arbitrationRules": "string",
    "mediation": boolean
  }}
}}

Be precise and extract only information that is explicitly stated in the document. If information is not available, use null.
Return ONLY valid JSON, no additional text."""

    async def process(
        self,
        document_text: str,
        document_url: str,
        contract_number: Optional[str] = None,
        party_a: Optional[str] = None,
        party_b: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Process contract document and extract structured terms
        """
        start_time = datetime.now()
        
        try:
            logger.info("Processing contract document",
                       document_url=document_url,
                       text_length=len(document_text))
            
            # Use RAG for similar contract examples
            context = ""
            if self.rag_pipeline:
                try:
                    similar_contracts = await self.rag_pipeline.query(
                        query=f"contract clauses obligations {contract_number or ''}",
                        top_k=3
                    )
                    if similar_contracts:
                        context = "\n\nSimilar contract examples:\n" + "\n".join(
                            [doc.get("content", "") for doc in similar_contracts]
                        )
                except Exception as e:
                    logger.warning("RAG retrieval failed", error=str(e))
            
            # Format prompt
            prompt = self.extraction_prompt.format(
                document_text=document_text[:50000]
            )
            
            if context:
                prompt += context
            
            # Call LLM
            llm = self.llm_provider.get_llm()
            response = await llm.ainvoke(prompt)
            
            # Parse JSON response
            content = response.content if hasattr(response, 'content') else str(response)
            
            # Extract JSON
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
            else:
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
                if json_match:
                    json_str = json_match.group(0)
                else:
                    raise ValueError("No JSON found in LLM response")
            
            abstracted_terms = json.loads(json_str)
            abstracted_terms = self._validate_and_clean(abstracted_terms)
            
            processing_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)
            
            logger.info("Contract processing completed",
                       document_url=document_url,
                       processing_time_ms=processing_time_ms,
                       clauses_count=len(abstracted_terms.get("clauses", [])),
                       obligations_count=len(abstracted_terms.get("obligations", [])))
            
            return {
                "abstractedTerms": abstracted_terms,
                "keyClauses": abstracted_terms.get("clauses", []),
                "financialTerms": abstracted_terms.get("financialTerms", {}),
                "obligations": abstracted_terms.get("obligations", []),
                "terminationTerms": abstracted_terms.get("terminationTerms", {}),
                "liabilityTerms": abstracted_terms.get("liabilityTerms", {}),
                "intellectualProperty": abstracted_terms.get("intellectualProperty", {}),
                "disputeResolution": abstracted_terms.get("disputeResolution", {}),
                "confidence": self._calculate_confidence(abstracted_terms),
                "processingTimeMs": processing_time_ms,
            }
            
        except Exception as e:
            logger.error("Error processing contract document",
                        document_url=document_url,
                        error=str(e))
            raise
    
    def _validate_and_clean(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and clean extracted data"""
        for key, value in data.items():
            if isinstance(value, list):
                data[key] = [item for item in value if item is not None]
            elif isinstance(value, dict):
                data[key] = self._validate_and_clean(value)
        return data
    
    def _calculate_confidence(self, abstracted_terms: Dict[str, Any]) -> float:
        """Calculate confidence score"""
        required_fields = ["parties", "contractDetails", "clauses"]
        populated_fields = sum(1 for field in required_fields if abstracted_terms.get(field))
        base_confidence = populated_fields / len(required_fields)
        
        if abstracted_terms.get("obligations"):
            base_confidence += 0.1
        
        return min(1.0, base_confidence)
```

---

### Phase 2.3: Clause Evolution Tracker

**File**: `deepiri-platform/diri-cyrex/app/services/clause_evolution_tracker.py`

```python
"""
Clause Evolution Tracker
Tracks how contract clauses evolve across versions
"""
from typing import Dict, List, Any, Optional
from datetime import datetime
import json
import difflib

from ...logging_config import get_logger
from ...integrations.llm_providers import get_llm_provider

logger = get_logger("cyrex.clause_evolution")


class ClauseEvolutionTracker:
    """
    Track clause changes across contract versions
    
    Identifies:
    - New clauses
    - Modified clauses
    - Deleted clauses
    - Language changes within clauses
    """
    
    def __init__(self, llm_provider=None):
        self.llm_provider = llm_provider or get_llm_provider()
    
    async def track_clause_changes(
        self,
        contract_id: str,
        old_version_clauses: List[Dict[str, Any]],
        new_version_clauses: List[Dict[str, Any]],
        old_version_number: int,
        new_version_number: int,
    ) -> Dict[str, Any]:
        """
        Compare clauses between two contract versions
        
        Returns:
            Dictionary with:
            - new_clauses: Clauses added in new version
            - modified_clauses: Clauses changed
            - deleted_clauses: Clauses removed
            - unchanged_clauses: Clauses that didn't change
            - summary: Text summary of changes
        """
        try:
            logger.info("Tracking clause changes",
                          contract_id=contract_id,
                          old_version=old_version_number,
                          new_version=new_version_number)
            
            # Build clause maps by identifier
            old_clause_map = self._build_clause_map(old_version_clauses)
            new_clause_map = self._build_clause_map(new_version_clauses)
            
            # Identify changes
            new_clauses = []
            modified_clauses = []
            deleted_clauses = []
            unchanged_clauses = []
            
            # Find new and modified clauses
            for clause_id, new_clause in new_clause_map.items():
                if clause_id not in old_clause_map:
                    new_clauses.append(new_clause)
                else:
                    old_clause = old_clause_map[clause_id]
                    changes = await self._compare_clauses(old_clause, new_clause)
                    if changes["has_changes"]:
                        modified_clauses.append({
                            "clause": new_clause,
                            "old_clause": old_clause,
                            "changes": changes,
                        })
                    else:
                        unchanged_clauses.append(new_clause)
            
            # Find deleted clauses
            for clause_id, old_clause in old_clause_map.items():
                if clause_id not in new_clause_map:
                    deleted_clauses.append(old_clause)
            
            # Generate summary using LLM
            summary = await self._generate_change_summary(
                new_clauses,
                modified_clauses,
                deleted_clauses,
                old_version_number,
                new_version_number,
            )
            
            result = {
                "contract_id": contract_id,
                "old_version": old_version_number,
                "new_version": new_version_number,
                "new_clauses": new_clauses,
                "modified_clauses": modified_clauses,
                "deleted_clauses": deleted_clauses,
                "unchanged_clauses": unchanged_clauses,
                "summary": summary,
                "statistics": {
                    "total_old_clauses": len(old_version_clauses),
                    "total_new_clauses": len(new_version_clauses),
                    "new_count": len(new_clauses),
                    "modified_count": len(modified_clauses),
                    "deleted_count": len(deleted_clauses),
                    "unchanged_count": len(unchanged_clauses),
                },
            }
            
            logger.info("Clause changes tracked",
                       contract_id=contract_id,
                       new_count=len(new_clauses),
                       modified_count=len(modified_clauses),
                       deleted_count=len(deleted_clauses))
            
            return result
            
        except Exception as e:
            logger.error("Error tracking clause changes",
                        contract_id=contract_id,
                        error=str(e))
            raise
    
    def _build_clause_map(self, clauses: List[Dict[str, Any]]) -> Dict[str, str]:
        """Build map of clauses by identifier"""
        clause_map = {}
        for clause in clauses:
            # Use clause number, type, or first 50 chars as identifier
            clause_id = (
                clause.get("clauseNumber") or
                f"{clause.get('clauseType', 'UNKNOWN')}_{hash(clause.get('clauseText', '')[:50])}"
            )
            clause_map[clause_id] = clause
        return clause_map
    
    async def _compare_clauses(
        self,
        old_clause: Dict[str, Any],
        new_clause: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Compare two clauses and identify changes"""
        changes = {
            "has_changes": False,
            "text_changed": False,
            "type_changed": False,
            "title_changed": False,
            "text_diff": None,
            "change_type": "UNCHANGED",
        }
        
        # Compare clause text
        old_text = old_clause.get("clauseText", "")
        new_text = new_clause.get("clauseText", "")
        
        if old_text != new_text:
            changes["text_changed"] = True
            changes["has_changes"] = True
            
            # Generate diff
            diff = list(difflib.unified_diff(
                old_text.splitlines(keepends=True),
                new_text.splitlines(keepends=True),
                lineterm='',
            ))
            changes["text_diff"] = ''.join(diff)
        
        # Compare clause type
        if old_clause.get("clauseType") != new_clause.get("clauseType"):
            changes["type_changed"] = True
            changes["has_changes"] = True
        
        # Compare title
        if old_clause.get("clauseTitle") != new_clause.get("clauseTitle"):
            changes["title_changed"] = True
            changes["has_changes"] = True
        
        # Determine change type
        if changes["has_changes"]:
            if changes["text_changed"] and len(new_text) > len(old_text) * 1.5:
                changes["change_type"] = "SIGNIFICANT_MODIFICATION"
            elif changes["text_changed"]:
                changes["change_type"] = "MODIFICATION"
            elif changes["type_changed"]:
                changes["change_type"] = "TYPE_CHANGE"
            else:
                changes["change_type"] = "MINOR_MODIFICATION"
        
        return changes
    
    async def _generate_change_summary(
        self,
        new_clauses: List[Dict],
        modified_clauses: List[Dict],
        deleted_clauses: List[Dict],
        old_version: int,
        new_version: int,
    ) -> str:
        """Generate human-readable summary of changes"""
        llm = self.llm_provider.get_llm()
        
        prompt = f"""Summarize the changes between contract version {old_version} and {new_version}:

New Clauses ({len(new_clauses)}):
{json.dumps([c.get('clauseTitle') or c.get('clauseType') for c in new_clauses[:10]], indent=2)}

Modified Clauses ({len(modified_clauses)}):
{json.dumps([c['clause'].get('clauseTitle') or c['clause'].get('clauseType') for c in modified_clauses[:10]], indent=2)}

Deleted Clauses ({len(deleted_clauses)}):
{json.dumps([c.get('clauseTitle') or c.get('clauseType') for c in deleted_clauses[:10]], indent=2)}

Provide a concise summary (2-3 sentences) of the key changes."""
        
        response = await llm.ainvoke(prompt)
        return response.content if hasattr(response, 'content') else str(response)
```

---

### Phase 2.4: Obligation Dependency Graph Builder

**File**: `deepiri-platform/diri-cyrex/app/services/obligation_dependency_graph.py`

```python
"""
Obligation Dependency Graph Builder
Builds graph of obligation dependencies across contracts/leases
"""
from typing import Dict, List, Any, Optional, Set, Tuple
from datetime import datetime
import networkx as nx
from collections import defaultdict

from ...logging_config import get_logger
from ...integrations.llm_providers import get_llm_provider

logger = get_logger("cyrex.obligation_dependency")


class ObligationDependencyGraph:
    """
    Build and analyze obligation dependency graphs
    
    Identifies:
    - Which obligations trigger others
    - Cascade effects
    - Dependency chains
    - Critical path obligations
    """
    
    def __init__(self, llm_provider=None):
        self.llm_provider = llm_provider or get_llm_provider()
        self.graph = nx.DiGraph()  # Directed graph for dependencies
    
    async def build_graph(
        self,
        contract_ids: List[str],
        lease_ids: List[str],
        obligations: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Build dependency graph from obligations
        
        Args:
            contract_ids: List of contract IDs to analyze
            lease_ids: List of lease IDs to analyze
            obligations: List of obligation dictionaries with dependencies
            
        Returns:
            Dictionary with graph structure and analysis
        """
        try:
            logger.info("Building obligation dependency graph",
                       contract_count=len(contract_ids),
                       lease_count=len(lease_ids),
                       obligation_count=len(obligations))
            
            # Clear existing graph
            self.graph.clear()
            
            # Add obligations as nodes
            for obligation in obligations:
                obligation_id = obligation.get("id") or obligation.get("obligation_id")
                if not obligation_id:
                    continue
                
                self.graph.add_node(
                    obligation_id,
                    **{
                        "description": obligation.get("description", ""),
                        "type": obligation.get("obligationType") or obligation.get("type", ""),
                        "deadline": obligation.get("deadline"),
                        "contract_id": obligation.get("contractId"),
                        "lease_id": obligation.get("leaseId"),
                        "party": obligation.get("party", ""),
                    }
                )
            
            # Analyze dependencies using LLM
            dependencies = await self._analyze_dependencies(obligations)
            
            # Add edges for dependencies
            for dep in dependencies:
                source_id = dep.get("source_obligation_id")
                target_id = dep.get("target_obligation_id")
                
                if source_id and target_id and source_id in self.graph and target_id in self.graph:
                    self.graph.add_edge(
                        source_id,
                        target_id,
                        **{
                            "dependency_type": dep.get("dependency_type", "TRIGGERS"),
                            "confidence": dep.get("confidence", 0.5),
                            "description": dep.get("description", ""),
                            "strength": dep.get("strength", "MODERATE"),
                        }
                    )
            
            # Analyze graph structure
            analysis = self._analyze_graph_structure()
            
            # Find critical paths
            critical_paths = self._find_critical_paths()
            
            # Find cascade risks
            cascade_risks = self._identify_cascade_risks()
            
            result = {
                "graph": {
                    "nodes": len(self.graph.nodes()),
                    "edges": len(self.graph.edges()),
                },
                "dependencies": dependencies,
                "analysis": analysis,
                "critical_paths": critical_paths,
                "cascade_risks": cascade_risks,
                "statistics": {
                    "total_obligations": len(obligations),
                    "total_dependencies": len(dependencies),
                    "max_cascade_depth": max([len(path) for path in critical_paths] + [0]),
                },
            }
            
            logger.info("Dependency graph built",
                       nodes=result["graph"]["nodes"],
                       edges=result["graph"]["edges"],
                       dependencies=len(dependencies))
            
            return result
            
        except Exception as e:
            logger.error("Error building dependency graph", error=str(e))
            raise
    
    async def _analyze_dependencies(
        self,
        obligations: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        """
        Use LLM to analyze dependencies between obligations
        """
        llm = self.llm_provider.get_llm()
        
        # Prepare obligation descriptions for LLM
        obligation_descriptions = []
        for i, obl in enumerate(obligations):
            obligation_descriptions.append(
                f"Obligation {i+1} (ID: {obl.get('id', 'unknown')}):\n"
                f"Description: {obl.get('description', '')}\n"
                f"Type: {obl.get('obligationType', '')}\n"
                f"Deadline: {obl.get('deadline', 'N/A')}\n"
                f"Party: {obl.get('party', '')}\n"
                f"Contract: {obl.get('contractId', 'N/A')}\n"
                f"Lease: {obl.get('leaseId', 'N/A')}\n"
            )
        
        prompt = f"""Analyze these obligations and identify dependencies between them.

Obligations:
{chr(10).join(obligation_descriptions)}

For each pair of obligations, determine if there's a dependency relationship:
- TRIGGERS: One obligation triggers another
- BLOCKS: One obligation blocks another
- MODIFIES: One obligation modifies another
- REQUIRES: One obligation requires another
- PRECEDES: One obligation must occur before another
- ENABLES: One obligation enables another

Return as JSON array:
[
  {{
    "source_obligation_id": "obligation_id",
    "target_obligation_id": "obligation_id",
    "dependency_type": "TRIGGERS|BLOCKS|MODIFIES|REQUIRES|PRECEDES|ENABLES",
    "description": "explanation of dependency",
    "confidence": 0.0-1.0,
    "strength": "STRONG|MODERATE|WEAK"
  }}
]

Only include dependencies you're confident about (confidence > 0.6)."""
        
        response = await llm.ainvoke(prompt)
        content = response.content if hasattr(response, 'content') else str(response)
        
        # Parse JSON
        import json
        import re
        json_match = re.search(r'\[.*\]', content, re.DOTALL)
        if json_match:
            dependencies = json.loads(json_match.group(0))
        else:
            dependencies = []
        
        return dependencies
    
    def _analyze_graph_structure(self) -> Dict[str, Any]:
        """Analyze graph structure"""
        if len(self.graph.nodes()) == 0:
            return {}
        
        # Calculate metrics
        in_degrees = dict(self.graph.in_degree())
        out_degrees = dict(self.graph.out_degree())
        
        # Find root nodes (no incoming edges)
        root_nodes = [node for node, degree in in_degrees.items() if degree == 0]
        
        # Find leaf nodes (no outgoing edges)
        leaf_nodes = [node for node, degree in out_degrees.items() if degree == 0]
        
        # Find highly connected nodes (hubs)
        hub_threshold = len(self.graph.nodes()) * 0.1
        hub_nodes = [
            node for node, degree in out_degrees.items()
            if degree >= hub_threshold
        ]
        
        return {
            "root_nodes": root_nodes,
            "leaf_nodes": leaf_nodes,
            "hub_nodes": hub_nodes,
            "max_in_degree": max(in_degrees.values()) if in_degrees else 0,
            "max_out_degree": max(out_degrees.values()) if out_degrees else 0,
            "is_acyclic": nx.is_directed_acyclic_graph(self.graph),
        }
    
    def _find_critical_paths(self) -> List[List[str]]:
        """Find critical paths in dependency graph"""
        if not nx.is_directed_acyclic_graph(self.graph):
            return []
        
        # Find longest paths from root nodes
        root_nodes = [node for node in self.graph.nodes() if self.graph.in_degree(node) == 0]
        critical_paths = []
        
        for root in root_nodes:
            # Find all paths from this root
            leaf_nodes = [node for node in self.graph.nodes() if self.graph.out_degree(node) == 0]
            
            for leaf in leaf_nodes:
                try:
                    paths = list(nx.all_simple_paths(self.graph, root, leaf))
                    if paths:
                        # Get longest path
                        longest_path = max(paths, key=len)
                        if len(longest_path) > 1:  # Only paths with dependencies
                            critical_paths.append(longest_path)
                except nx.NetworkXNoPath:
                    continue
        
        # Sort by length (longest first)
        critical_paths.sort(key=len, reverse=True)
        
        return critical_paths[:10]  # Return top 10
    
    def _identify_cascade_risks(self) -> List[Dict[str, Any]]:
        """Identify obligations with high cascade risk"""
        cascade_risks = []
        
        for node in self.graph.nodes():
            # Count how many obligations depend on this one
            descendants = list(nx.descendants(self.graph, node))
            cascade_count = len(descendants)
            
            if cascade_count > 0:
                # Calculate cascade depth
                max_depth = 0
                for desc in descendants:
                    try:
                        path_length = nx.shortest_path_length(self.graph, node, desc)
                        max_depth = max(max_depth, path_length)
                    except nx.NetworkXNoPath:
                        continue
                
                cascade_risks.append({
                    "obligation_id": node,
                    "cascade_count": cascade_count,
                    "max_depth": max_depth,
                    "risk_level": "HIGH" if cascade_count > 5 or max_depth > 3 else "MEDIUM" if cascade_count > 2 else "LOW",
                })
        
        # Sort by cascade count
        cascade_risks.sort(key=lambda x: x["cascade_count"], reverse=True)
        
        return cascade_risks
    
    async def find_cascading_obligations(
        self,
        obligation_id: str,
    ) -> List[Dict[str, Any]]:
        """
        Find all obligations that depend on this one (cascade analysis)
        """
        if obligation_id not in self.graph:
            return []
        
        # Get all descendants
        descendants = list(nx.descendants(self.graph, obligation_id))
        
        cascading_obligations = []
        for desc_id in descendants:
            try:
                # Get path from source to descendant
                path = nx.shortest_path(self.graph, obligation_id, desc_id)
                
                # Get edge data
                edge_data = self.graph.get_edge_data(obligation_id, path[1] if len(path) > 1 else desc_id)
                
                cascading_obligations.append({
                    "obligation_id": desc_id,
                    "dependency_path": path,
                    "dependency_type": edge_data.get("dependency_type", "UNKNOWN") if edge_data else "UNKNOWN",
                    "depth": len(path) - 1,
                    "description": self.graph.nodes[desc_id].get("description", ""),
                })
            except nx.NetworkXNoPath:
                continue
        
        # Sort by depth
        cascading_obligations.sort(key=lambda x: x["depth"])
        
        return cascading_obligations
```

**Add to requirements**:
```txt
networkx>=3.2
```

---

### Phase 2.5: Contract Intelligence Agent (LangGraph)

**File**: `deepiri-platform/diri-cyrex/app/agents/implementations/contract_intelligence_agent.py`

```python
"""
LangGraph-based Contract Intelligence Agent
Multi-step workflow for contract analysis
"""
from typing import Dict, List, Optional, Any, TypedDict, Annotated
from datetime import datetime
import operator

from ...base_agent import BaseAgent
from ...core.types import AgentConfig, AgentRole
from ...logging_config import get_logger
from ...services.document_processors.contract_processor import ContractProcessor
from ...services.clause_evolution_tracker import ClauseEvolutionTracker
from ...services.obligation_dependency_graph import ObligationDependencyGraph
from ...integrations.llm_providers import get_llm_provider

logger = get_logger("cyrex.agent.contract_intelligence")

# LangGraph imports
HAS_LANGGRAPH = False
try:
    from langgraph.graph import StateGraph, END, START
    from langchain_core.messages import BaseMessage
    HAS_LANGGRAPH = True
except ImportError:
    logger.warning("LangGraph not available")
    StateGraph = None
    END = None
    START = None


class ContractIntelligenceState(TypedDict):
    """State for contract intelligence workflow"""
    messages: List[Any]
    workflow_id: str
    contract_id: str
    document_text: str
    document_url: str
    
    # Processing results
    extracted_data: Optional[Dict[str, Any]]
    clauses: List[Dict[str, Any]]
    obligations: List[Dict[str, Any]]
    dependencies: List[Dict[str, Any]]
    
    # Status
    current_step: str
    status: str
    error: Optional[str]
    metadata: Dict[str, Any]


class ContractIntelligenceAgent(BaseAgent):
    """
    Multi-step workflow for contract analysis:
    1. Document Parser - Extract text
    2. Structure Extractor - Extract clauses and obligations
    3. Clause Analyzer - Analyze clause types and relationships
    4. Dependency Mapper - Map obligation dependencies
    5. Evolution Tracker - Track changes from previous version (if applicable)
    6. Finalizer - Compile results
    """
    
    def __init__(
        self,
        agent_config: AgentConfig,
        llm_provider=None,
        session_id: Optional[str] = None,
    ):
        super().__init__(agent_config, llm_provider, session_id)
        self.contract_processor = ContractProcessor(llm_provider)
        self.clause_tracker = ClauseEvolutionTracker(llm_provider)
        self.dependency_graph = ObligationDependencyGraph(llm_provider)
        self.graph = None
        
        if HAS_LANGGRAPH:
            self._build_workflow()
    
    def _build_workflow(self):
        """Build LangGraph workflow"""
        if not HAS_LANGGRAPH:
            return
        
        workflow = StateGraph(ContractIntelligenceState)
        
        # Add nodes
        workflow.add_node("document_parser", self._node_document_parser)
        workflow.add_node("structure_extractor", self._node_structure_extractor)
        workflow.add_node("clause_analyzer", self._node_clause_analyzer)
        workflow.add_node("dependency_mapper", self._node_dependency_mapper)
        workflow.add_node("evolution_tracker", self._node_evolution_tracker)
        workflow.add_node("finalizer", self._node_finalizer)
        
        # Define edges
        workflow.set_entry_point("document_parser")
        workflow.add_edge("document_parser", "structure_extractor")
        workflow.add_edge("structure_extractor", "clause_analyzer")
        workflow.add_edge("clause_analyzer", "dependency_mapper")
        workflow.add_edge("dependency_mapper", "evolution_tracker")
        workflow.add_edge("evolution_tracker", "finalizer")
        workflow.add_edge("finalizer", END)
        
        self.graph = workflow.compile()
        logger.info("Contract intelligence workflow built")
    
    async def _node_document_parser(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 1: Extract document text"""
        state["current_step"] = "document_parser"
        return state
    
    async def _node_structure_extractor(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 2: Extract structured contract terms"""
        try:
            result = await self.contract_processor.process(
                document_text=state["document_text"],
                document_url=state["document_url"],
            )
            
            state["extracted_data"] = result
            state["clauses"] = result.get("keyClauses", [])
            state["obligations"] = result.get("obligations", [])
            state["current_step"] = "structure_extractor"
        except Exception as e:
            state["error"] = f"Structure extraction failed: {str(e)}"
            state["status"] = "error"
        
        return state
    
    async def _node_clause_analyzer(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 3: Analyze clauses"""
        # Additional clause analysis can be done here
        state["current_step"] = "clause_analyzer"
        return state
    
    async def _node_dependency_mapper(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 4: Map obligation dependencies"""
        try:
            if state.get("obligations"):
                graph_result = await self.dependency_graph.build_graph(
                    contract_ids=[state["contract_id"]],
                    lease_ids=[],
                    obligations=state["obligations"],
                )
                
                state["dependencies"] = graph_result.get("dependencies", [])
                state["current_step"] = "dependency_mapper"
        except Exception as e:
            logger.warning("Dependency mapping failed", error=str(e))
            state["dependencies"] = []
        
        return state
    
    async def _node_evolution_tracker(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 5: Track clause evolution (if previous version exists)"""
        # This would compare with previous version if available
        state["current_step"] = "evolution_tracker"
        return state
    
    async def _node_finalizer(self, state: ContractIntelligenceState) -> ContractIntelligenceState:
        """Node 6: Compile final results"""
        state["status"] = "completed"
        state["current_step"] = "finalizer"
        return state
    
    async def process_contract(
        self,
        contract_id: str,
        document_text: str,
        document_url: str,
        contract_number: Optional[str] = None,
        party_a: Optional[str] = None,
        party_b: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Process contract through workflow"""
        if not self.graph:
            # Fallback
            return await self.contract_processor.process(
                document_text, document_url, contract_number, party_a, party_b
            )
        
        initial_state: ContractIntelligenceState = {
            "messages": [],
            "workflow_id": f"contract_{contract_id}_{datetime.now().isoformat()}",
            "contract_id": contract_id,
            "document_text": document_text,
            "document_url": document_url,
            "extracted_data": None,
            "clauses": [],
            "obligations": [],
            "dependencies": [],
            "current_step": "start",
            "status": "pending",
            "error": None,
            "metadata": {},
        }
        
        final_state = await self.graph.ainvoke(initial_state)
        
        if final_state.get("error"):
            raise Exception(final_state["error"])
        
        return {
            "abstractedTerms": final_state.get("extracted_data", {}).get("abstractedTerms"),
            "clauses": final_state.get("clauses", []),
            "obligations": final_state.get("obligations", []),
            "dependencies": final_state.get("dependencies", []),
        }
```

---

### Phase 2.6: Contract API Routes (Platform Service)

**File**: `src/routes/contractRoutes.ts`

```typescript
import { Router, Request, Response } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { contractIntelligenceService } from '../services/contractIntelligenceService';
import { documentService } from '../services/documentService';
import { authenticate } from '../routes/middleware/auth';
import { handleValidationErrors } from '../routes/middleware/validation';
import { logger } from '../utils/logger';

const router = Router();

/**
 * POST /api/v1/contracts/upload
 */
router.post(
  '/upload',
  authenticate,
  [
    body('contractNumber').notEmpty(),
    body('contractName').notEmpty(),
    body('partyA').notEmpty(),
    body('partyB').notEmpty(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const file = req.file;
      if (!file) {
        return res.status(400).json({ error: 'No file uploaded' });
      }
      
      const documentUrl = await documentService.uploadDocument(file, 'contracts');
      
      const contract = await contractIntelligenceService.createContract({
        contractNumber: req.body.contractNumber,
        contractName: req.body.contractName,
        partyA: req.body.partyA,
        partyB: req.body.partyB,
        contractType: req.body.contractType,
        jurisdiction: req.body.jurisdiction,
        documentUrl,
        userId: req.user?.id,
      });
      
      // Trigger async processing
      contractIntelligenceService.processContractAsync(contract.id).catch((error) => {
        logger.error('Failed to process contract', { contractId: contract.id, error });
      });
      
      res.status(201).json({
        success: true,
        data: contract,
      });
    } catch (error: any) {
      logger.error('Error uploading contract', { error: error.message });
      res.status(500).json({ error: 'Failed to upload contract', message: error.message });
    }
  }
);

/**
 * GET /api/v1/contracts/:id/clauses
 */
router.get(
  '/:id/clauses',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const clauses = await contractIntelligenceService.getClausesByContractId(req.params.id);
      res.json({ success: true, data: clauses });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to fetch clauses', message: error.message });
    }
  }
);

/**
 * GET /api/v1/contracts/:id/clauses/evolution
 */
router.get(
  '/:id/clauses/evolution',
  authenticate,
  [
    param('id').isUUID(),
    query('fromVersion').optional().isInt(),
    query('toVersion').optional().isInt(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const evolution = await contractIntelligenceService.getClauseEvolution(
        req.params.id,
        req.query.fromVersion ? parseInt(req.query.fromVersion as string) : undefined,
        req.query.toVersion ? parseInt(req.query.toVersion as string) : undefined,
      );
      
      res.json({ success: true, data: evolution });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to get clause evolution', message: error.message });
    }
  }
);

/**
 * GET /api/v1/contracts/:id/obligations/dependencies
 */
router.get(
  '/:id/obligations/dependencies',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const dependencies = await contractIntelligenceService.getObligationDependencies(
        req.params.id
      );
      
      res.json({ success: true, data: dependencies });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to get dependencies', message: error.message });
    }
  }
);

/**
 * GET /api/v1/contracts/:id/obligations/:obligationId/cascade
 */
router.get(
  '/:id/obligations/:obligationId/cascade',
  authenticate,
  [param('id').isUUID(), param('obligationId').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const cascade = await contractIntelligenceService.getCascadingObligations(
        req.params.obligationId
      );
      
      res.json({ success: true, data: cascade });
    } catch (error: any) {
      res.status(500).json({ error: 'Failed to get cascade', message: error.message });
    }
  }
);

export default router;
```

---

### Phase 2.7: Contract Intelligence Service

**File**: `src/services/contractIntelligenceService.ts`

```typescript
import { prisma } from '../db';
import { cyrexClient } from './cyrexClient';
import { documentService } from './documentService';
import { obligationService } from './obligationService';
import { eventPublisher } from '../streaming/eventPublisher';
import { logger } from '../utils/logger';
import type { Contract, Clause, ContractVersion, ObligationDependency, Prisma } from '@prisma/client';

export class ContractIntelligenceService {
  /**
   * Create contract
   */
  async createContract(input: any): Promise<Contract> {
    const contract = await prisma.contract.create({
      data: {
        contractNumber: input.contractNumber,
        contractName: input.contractName,
        partyA: input.partyA,
        partyB: input.partyB,
        contractType: input.contractType,
        jurisdiction: input.jurisdiction,
        documentUrl: input.documentUrl,
        rawText: '',
        status: 'PENDING',
        userId: input.userId,
      },
    });
    
    await eventPublisher.publishContractCreated(contract.id, contract.contractNumber);
    return contract;
  }
  
  /**
   * Process contract
   */
  async processContract(contractId: string): Promise<Contract> {
    const contract = await prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');
    
    await prisma.contract.update({
      where: { id: contractId },
      data: { status: 'PROCESSING', processingStatus: 'PROCESSING' },
    });
    
    try {
      const extractedText = await documentService.extractText(contract.documentUrl);
      
      const result = await cyrexClient.abstractContract({
        contractId,
        documentText: extractedText,
        documentUrl: contract.documentUrl,
        contractNumber: contract.contractNumber,
        partyA: contract.partyA,
        partyB: contract.partyB,
      });
      
      // Update contract
      const updated = await prisma.contract.update({
        where: { id: contractId },
        data: {
          status: 'COMPLETED',
          processingStatus: 'COMPLETED',
          rawText: extractedText,
          abstractedTerms: result.abstractedTerms,
          keyClauses: result.keyClauses,
          financialTerms: result.financialTerms,
          extractionConfidence: result.confidence,
          processedAt: new Date(),
        },
      });
      
      // Create clauses
      if (result.clauses) {
        await this.createClauses(contractId, result.clauses, 1);
      }
      
      // Create obligations
      if (result.obligations) {
        await obligationService.createObligationsFromAbstraction(contractId, result.obligations, 'contract');
      }
      
      // Build dependency graph
      if (result.obligations && result.obligations.length > 0) {
        await this.buildDependencyGraph(contractId, result.obligations);
      }
      
      await eventPublisher.publishContractProcessed(contractId);
      return updated;
    } catch (error: any) {
      await prisma.contract.update({
        where: { id: contractId },
        data: { status: 'ERROR', processingError: error.message },
      });
      throw error;
    }
  }
  
  /**
   * Create clauses
   */
  async createClauses(
    contractId: string,
    clauses: any[],
    versionNumber: number
  ): Promise<Clause[]> {
    const created: Clause[] = [];
    
    for (const clause of clauses) {
      const createdClause = await prisma.clause.create({
        data: {
          contractId,
          clauseNumber: clause.clauseNumber,
          clauseType: clause.clauseType,
          clauseTitle: clause.clauseTitle,
          clauseText: clause.clauseText,
          versionNumber,
          sourceSection: clause.section,
          pageNumber: clause.pageNumber,
        },
      });
      created.push(createdClause);
    }
    
    return created;
  }
  
  /**
   * Get clause evolution
   */
  async getClauseEvolution(
    contractId: string,
    fromVersion?: number,
    toVersion?: number
  ): Promise<any> {
    // Get versions
    const versions = await prisma.contractVersion.findMany({
      where: { contractId },
      orderBy: { versionNumber: 'asc' },
    });
    
    if (versions.length < 2) {
      return { message: 'Not enough versions to compare' };
    }
    
    const from = fromVersion || versions[0].versionNumber;
    const to = toVersion || versions[versions.length - 1].versionNumber;
    
    const fromVersionData = versions.find(v => v.versionNumber === from);
    const toVersionData = versions.find(v => v.versionNumber === to);
    
    if (!fromVersionData || !toVersionData) {
      throw new Error('Version not found');
    }
    
    // Call Cyrex to compare
    const evolution = await cyrexClient.trackClauseEvolution({
      contractId,
      oldVersionClauses: (fromVersionData.abstractedTerms as any).clauses || [],
      newVersionClauses: (toVersionData.abstractedTerms as any).clauses || [],
      oldVersionNumber: from,
      newVersionNumber: to,
    });
    
    return evolution;
  }
  
  /**
   * Build dependency graph
   */
  async buildDependencyGraph(contractId: string, obligations: any[]): Promise<void> {
    const result = await cyrexClient.buildDependencyGraph({
      contractIds: [contractId],
      leaseIds: [],
      obligations,
    });
    
    // Store dependencies in database
    for (const dep of result.dependencies || []) {
      await prisma.obligationDependency.create({
        data: {
          sourceObligationId: dep.source_obligation_id,
          targetObligationId: dep.target_obligation_id,
          dependencyType: dep.dependency_type,
          description: dep.description,
          confidence: dep.confidence,
          strength: dep.strength,
          sourceContractId: contractId,
        },
      });
    }
  }
  
  /**
   * Get obligation dependencies
   */
  async getObligationDependencies(contractId: string): Promise<ObligationDependency[]> {
    return prisma.obligationDependency.findMany({
      where: {
        OR: [
          { sourceContractId: contractId },
          { targetContractId: contractId },
        ],
      },
      include: {
        sourceObligation: true,
        targetObligation: true,
      },
    });
  }
  
  /**
   * Get cascading obligations
   */
  async getCascadingObligations(obligationId: string): Promise<any> {
    const result = await cyrexClient.findCascadingObligations({ obligationId });
    return result;
  }
  
  async processContractAsync(contractId: string): Promise<void> {
    setImmediate(async () => {
      try {
        await this.processContract(contractId);
      } catch (error: any) {
        logger.error('Error in async contract processing', { contractId, error: error.message });
      }
    });
  }
  
  async getClausesByContractId(contractId: string): Promise<Clause[]> {
    return prisma.clause.findMany({
      where: { contractId },
      orderBy: { clauseNumber: 'asc' },
    });
  }
}

export const contractIntelligenceService = new ContractIntelligenceService();
```

---

### Phase 2.8: Cyrex Contract API Routes

**File**: `deepiri-platform/diri-cyrex/app/routes/contract_intelligence_api.py`

```python
"""
Contract Intelligence API Routes
FastAPI endpoints for contract processing
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any

from ...logging_config import get_logger
from ...agents.agent_factory import AgentFactory
from ...core.types import AgentRole, AgentConfig
from ...integrations.llm_providers import get_llm_provider
from ...services.clause_evolution_tracker import ClauseEvolutionTracker
from ...services.obligation_dependency_graph import ObligationDependencyGraph

logger = get_logger("cyrex.api.contract_intelligence")

router = APIRouter(prefix="/contract-intelligence", tags=["Contract Intelligence"])


class AbstractContractRequest(BaseModel):
    contractId: str
    documentText: str
    documentUrl: str
    contractNumber: Optional[str] = None
    partyA: Optional[str] = None
    partyB: Optional[str] = None


class TrackClauseEvolutionRequest(BaseModel):
    contractId: str
    oldVersionClauses: List[Dict[str, Any]]
    newVersionClauses: List[Dict[str, Any]]
    oldVersionNumber: int
    newVersionNumber: int


class BuildDependencyGraphRequest(BaseModel):
    contractIds: List[str]
    leaseIds: List[str]
    obligations: List[Dict[str, Any]]


@router.post("/abstract")
async def abstract_contract(request: AbstractContractRequest):
    """Process contract and return abstracted terms"""
    try:
        agent_config = AgentConfig(
            role=AgentRole.CUSTOM,
            model_name="gpt-4-turbo-preview",
            temperature=0.1,
        )
        
        agent = await AgentFactory.create_agent(
            agent_config=agent_config,
            llm_provider=get_llm_provider(),
            agent_type="contract_intelligence",
        )
        
        result = await agent.process_contract(
            contract_id=request.contractId,
            document_text=request.documentText,
            document_url=request.documentUrl,
            contract_number=request.contractNumber,
            party_a=request.partyA,
            party_b=request.partyB,
        )
        
        return {"success": True, "data": result}
    except Exception as e:
        logger.error("Contract abstraction error", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/track-clause-evolution")
async def track_clause_evolution(request: TrackClauseEvolutionRequest):
    """Track clause changes between versions"""
    try:
        tracker = ClauseEvolutionTracker()
        result = await tracker.track_clause_changes(
            contract_id=request.contractId,
            old_version_clauses=request.oldVersionClauses,
            new_version_clauses=request.newVersionClauses,
            old_version_number=request.oldVersionNumber,
            new_version_number=request.newVersionNumber,
        )
        
        return {"success": True, "data": result}
    except Exception as e:
        logger.error("Clause evolution tracking error", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/build-dependency-graph")
async def build_dependency_graph(request: BuildDependencyGraphRequest):
    """Build obligation dependency graph"""
    try:
        graph_builder = ObligationDependencyGraph()
        result = await graph_builder.build_graph(
            contract_ids=request.contractIds,
            lease_ids=request.leaseIds,
            obligations=request.obligations,
        )
        
        return {"success": True, "data": result}
    except Exception as e:
        logger.error("Dependency graph error", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/find-cascading-obligations")
async def find_cascading_obligations(obligationId: str):
    """Find obligations that cascade from a given obligation"""
    try:
        graph_builder = ObligationDependencyGraph()
        result = await graph_builder.find_cascading_obligations(obligationId)
        
        return {"success": True, "data": result}
    except Exception as e:
        logger.error("Cascade analysis error", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))
```

---

## AI INPUTS, TRAINING DATA, AND OUTPUTS

### AI Inputs: What Users Provide

#### Phase 1: Lease Abstraction Inputs

**User Inputs**:

1. **Lease Document Upload**
   - **Format**: PDF, DOCX, or TXT files
   - **Size Limit**: Up to 50MB per document
   - **Required Metadata**:
     - Lease Number (unique identifier)
     - Tenant Name
     - Property Address
     - Start Date (ISO 8601 format)
     - End Date (ISO 8601 format)
   - **Optional Metadata**:
     - Landlord Name
     - Property Type (Office, Retail, Industrial, etc.)
     - Square Footage
     - Tags (for organization)
     - Notes (user notes)

2. **Lease Version Upload** (for version comparison)
   - New document version (PDF/DOCX)
   - Optional version number (auto-incremented if not provided)
   - Optional notes about changes

**Example API Request**:
```typescript
POST /api/v1/leases/upload
Content-Type: multipart/form-data

Form Data:
- file: [lease_document.pdf]
- leaseNumber: "LEASE-2024-001"
- tenantName: "Acme Corporation"
- propertyAddress: "123 Main St, New York, NY 10001"
- startDate: "2024-01-01T00:00:00Z"
- endDate: "2026-12-31T23:59:59Z"
- propertyType: "OFFICE"
- squareFootage: "5000"
```

#### Phase 2: Contract Intelligence Inputs

**User Inputs**:

1. **Contract Document Upload**
   - **Format**: PDF, DOCX, or TXT files
   - **Size Limit**: Up to 50MB per document
   - **Required Metadata**:
     - Contract Number (unique identifier)
     - Contract Name
     - Party A (first party name)
     - Party B (second party name)
   - **Optional Metadata**:
     - Contract Type (Service, Supply, MSA, NDA, License, etc.)
     - Jurisdiction
     - Tags
     - Notes

2. **Contract Version Upload** (for clause evolution tracking)
   - New document version
   - Optional version number
   - Change description

3. **Obligation Dependency Analysis Request**
   - Contract IDs to analyze
   - Lease IDs to analyze (optional, for cross-document dependencies)
   - Specific obligation IDs (optional, for targeted analysis)

**Example API Request**:
```typescript
POST /api/v1/contracts/upload
Content-Type: multipart/form-data

Form Data:
- file: [service_agreement.pdf]
- contractNumber: "CONTRACT-2024-001"
- contractName: "Master Services Agreement"
- partyA: "Acme Corporation"
- partyB: "Tech Services Inc"
- contractType: "SERVICE"
- jurisdiction: "New York, USA"
```

---

### Training Data: What We Train On

#### Phase 1: Lease Abstraction Training

**Training Data Sources**:

1. **Public Lease Datasets**
   - SEC filings (10-K, 10-Q) containing lease abstracts
   - Public real estate databases
   - Commercial lease templates from legal databases
   - **Target**: 10,000+ lease documents

2. **Synthetic Lease Generation**
   - Generate synthetic leases using templates
   - Vary terms, clauses, and structures
   - **Target**: 5,000+ synthetic leases

3. **Customer Data (Anonymized)**
   - After customer onboarding, use anonymized leases for fine-tuning
   - Remove PII (names, addresses, financial amounts)
   - **Target**: Continuous improvement from production data

4. **RAG Knowledge Base**
   - Index lease examples in Milvus
   - Use for few-shot learning and context retrieval
   - **Target**: 1,000+ high-quality lease examples

**Training Pipeline** (Helox):

**File**: `deepiri-platform/diri-helox/pipelines/lease_abstraction_training_pipeline.py`

```python
"""
Lease Abstraction Model Training Pipeline
Trains LoRA adapters for lease-specific extraction
"""
from typing import List, Dict, Any
import json
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
from peft import LoraConfig, get_peft_model, TaskType
from datasets import Dataset

class LeaseAbstractionTrainingPipeline:
    """
    Train LoRA adapters for lease abstraction
    
    Training Data Format:
    {
        "input": "Lease document text...",
        "output": {
            "financialTerms": {...},
            "keyDates": {...},
            "obligations": [...],
            ...
        }
    }
    """
    
    def __init__(self, base_model: str = "meta-llama/Llama-2-7b-hf"):
        self.base_model = base_model
        self.tokenizer = AutoTokenizer.from_pretrained(base_model)
        self.model = AutoModelForCausalLM.from_pretrained(base_model)
        
        # LoRA configuration
        self.lora_config = LoraConfig(
            task_type=TaskType.CAUSAL_LM,
            r=16,  # Rank
            lora_alpha=32,
            lora_dropout=0.1,
            target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
        )
        
        self.model = get_peft_model(self.model, self.lora_config)
    
    def prepare_training_data(
        self,
        lease_documents: List[str],
        ground_truth_abstracts: List[Dict[str, Any]]
    ) -> Dataset:
        """
        Prepare training data from lease documents and ground truth
        
        Args:
            lease_documents: List of lease document texts
            ground_truth_abstracts: List of structured abstracts (JSON)
        """
        training_examples = []
        
        for doc_text, abstract in zip(lease_documents, ground_truth_abstracts):
            # Format as instruction-following prompt
            prompt = f"""Extract structured data from this lease document:

{doc_text[:4000]}

Return JSON with financial terms, key dates, obligations, and clauses."""
            
            output = json.dumps(abstract, indent=2)
            
            training_examples.append({
                "input": prompt,
                "output": output,
            })
        
        return Dataset.from_list(training_examples)
    
    def train(
        self,
        training_dataset: Dataset,
        validation_dataset: Dataset,
        output_dir: str = "./models/lease_abstraction_lora"
    ):
        """Train LoRA adapter"""
        training_args = TrainingArguments(
            output_dir=output_dir,
            num_train_epochs=3,
            per_device_train_batch_size=4,
            per_device_eval_batch_size=4,
            gradient_accumulation_steps=4,
            learning_rate=2e-4,
            warmup_steps=100,
            logging_steps=10,
            eval_steps=100,
            save_steps=500,
            evaluation_strategy="steps",
            save_strategy="steps",
            load_best_model_at_end=True,
            metric_for_best_model="eval_loss",
        )
        
        trainer = Trainer(
            model=self.model,
            args=training_args,
            train_dataset=training_dataset,
            eval_dataset=validation_dataset,
            tokenizer=self.tokenizer,
        )
        
        trainer.train()
        trainer.save_model()
        
        return output_dir
```

**Training Data Collection Strategy**:

1. **Initial Training Set** (Months 1-2):
   - Collect 5,000 public leases from SEC filings
   - Manually annotate 500 high-quality examples
   - Generate 2,000 synthetic leases
   - **Total**: 7,500 training examples

2. **Fine-Tuning Set** (Months 3-6):
   - Use production data (anonymized)
   - Customer feedback corrections
   - Edge cases and error corrections
   - **Target**: 10,000+ examples by end of Phase 1

3. **Continuous Learning** (Ongoing):
   - Track extraction accuracy
   - Collect low-confidence extractions for review
   - Retrain monthly with new data

#### Phase 2: Contract Intelligence Training

**Training Data Sources**:

1. **Public Contract Datasets**
   - SEC filings (contract exhibits)
   - Public procurement contracts
   - Legal contract databases
   - **Target**: 15,000+ contract documents

2. **Clause Evolution Training Data**
   - Contract version pairs with known changes
   - Manually annotated clause changes
   - **Target**: 2,000+ version pairs

3. **Obligation Dependency Training Data**
   - Contracts with known obligation dependencies
   - Manually mapped dependency graphs
   - **Target**: 1,000+ dependency graphs

4. **Synthetic Contract Generation**
   - Generate contracts with known structures
   - Create dependency relationships
   - **Target**: 5,000+ synthetic contracts

**Training Pipeline** (Helox):

**File**: `deepiri-platform/diri-helox/pipelines/contract_intelligence_training_pipeline.py`

```python
"""
Contract Intelligence Training Pipeline
Trains models for:
1. Contract clause extraction
2. Clause evolution tracking
3. Obligation dependency detection
"""
from typing import List, Dict, Any
import json
from transformers import AutoModelForSequenceClassification, AutoTokenizer
from datasets import Dataset

class ContractIntelligenceTrainingPipeline:
    """
    Train models for contract intelligence tasks
    """
    
    def train_clause_extractor(
        self,
        contracts: List[str],
        clause_labels: List[List[Dict[str, Any]]]
    ):
        """
        Train clause extraction model
        
        Training Format:
        {
            "text": "Contract section text...",
            "labels": [
                {"clauseType": "TERMINATION", "start": 0, "end": 100},
                {"clauseType": "PAYMENT", "start": 101, "end": 200},
            ]
        }
        """
        # Token classification model for clause extraction
        pass
    
    def train_clause_evolution_tracker(
        self,
        clause_pairs: List[Dict[str, Any]]
    ):
        """
        Train model to detect clause changes
        
        Training Format:
        {
            "old_clause": "Clause text v1...",
            "new_clause": "Clause text v2...",
            "change_type": "MODIFIED|ADDED|DELETED|UNCHANGED",
            "changes": {...}
        }
        """
        # Sequence-to-sequence or classification model
        pass
    
    def train_dependency_detector(
        self,
        obligation_pairs: List[Dict[str, Any]],
        dependency_labels: List[Dict[str, Any]]
    ):
        """
        Train model to detect obligation dependencies
        
        Training Format:
        {
            "obligation_a": "Description of obligation A...",
            "obligation_b": "Description of obligation B...",
            "has_dependency": true,
            "dependency_type": "TRIGGERS|BLOCKS|MODIFIES|REQUIRES",
            "confidence": 0.95
        }
        """
        # Binary classification + multi-class classification
        pass
```

---

### AI Outputs: What the AI Produces

#### Phase 1: Lease Abstraction Outputs

**Primary Output**: Structured Lease Abstraction

**Output Format** (JSON):

```json
{
  "success": true,
  "leaseId": "uuid",
  "abstractedTerms": {
    "financialTerms": {
      "baseRent": {
        "amount": 50000,
        "currency": "USD",
        "frequency": "monthly"
      },
      "securityDeposit": {
        "amount": 150000,
        "currency": "USD"
      },
      "escalations": [
        {
          "type": "CPI",
          "percentage": 3.5,
          "effectiveDate": "2025-01-01"
        }
      ],
      "additionalCharges": [
        {
          "type": "CAM",
          "description": "Common Area Maintenance",
          "amount": 5000,
          "frequency": "monthly"
        }
      ]
    },
    "keyDates": {
      "leaseStartDate": "2024-01-01",
      "leaseEndDate": "2026-12-31",
      "renewalOptions": [
        {
          "optionNumber": 1,
          "termMonths": 12,
          "noticeDays": 90,
          "rentAdjustment": "Market rate"
        }
      ]
    },
    "propertyDetails": {
      "squareFootage": 5000,
      "propertyType": "OFFICE",
      "address": "123 Main St, New York, NY 10001",
      "suiteNumber": "Suite 500"
    },
    "parties": {
      "tenant": {
        "name": "Acme Corporation",
        "entityType": "CORPORATION",
        "contactInfo": {
          "email": "legal@acme.com",
          "phone": "+1-555-0100"
        }
      },
      "landlord": {
        "name": "Property Management LLC",
        "entityType": "LLC",
        "contactInfo": {
          "email": "info@pmllc.com",
          "phone": "+1-555-0200"
        }
      }
    },
    "keyClauses": [
      {
        "clauseType": "TERMINATION",
        "title": "Early Termination",
        "summary": "Tenant may terminate with 90 days notice and payment of termination fee",
        "fullText": "Tenant may terminate this lease...",
        "appliesTo": "TENANT"
      },
      {
        "clauseType": "ASSIGNMENT",
        "title": "Assignment and Subletting",
        "summary": "Assignment requires landlord consent, not to be unreasonably withheld",
        "fullText": "Tenant may not assign...",
        "appliesTo": "TENANT"
      }
    ],
    "obligations": [
      {
        "description": "Pay monthly rent of $50,000 on the first of each month",
        "obligationType": "PAYMENT",
        "party": "TENANT",
        "deadline": "2024-02-01",
        "frequency": "MONTHLY",
        "amount": 50000,
        "currency": "USD",
        "sourceClause": "Section 3.1 - Rent Payment",
        "confidence": 0.95
      },
      {
        "description": "Provide proof of general liability insurance within 30 days",
        "obligationType": "INSURANCE",
        "party": "TENANT",
        "deadline": "2024-01-31",
        "frequency": "ONE_TIME",
        "sourceClause": "Section 8.1 - Insurance Requirements",
        "confidence": 0.92
      },
      {
        "description": "Maintain property in good condition and repair",
        "obligationType": "MAINTENANCE",
        "party": "TENANT",
        "frequency": "ONGOING",
        "sourceClause": "Section 7.1 - Maintenance",
        "confidence": 0.88
      }
    ],
    "insuranceRequirements": [
      {
        "type": "GENERAL_LIABILITY",
        "minimumCoverage": 2000000,
        "requiredBy": "TENANT",
        "evidenceRequired": true
      }
    ],
    "maintenanceResponsibilities": {
      "tenant": [
        "Interior maintenance",
        "HVAC system maintenance",
        "Plumbing repairs"
      ],
      "landlord": [
        "Structural repairs",
        "Roof maintenance",
        "Exterior maintenance"
      ],
      "shared": [
        "Common area cleaning"
      ]
    },
    "assignmentAndSubletting": {
      "assignmentAllowed": true,
      "sublettingAllowed": true,
      "conditions": "Requires landlord written consent",
      "landlordConsentRequired": true
    },
    "terminationTerms": {
      "earlyTerminationAllowed": true,
      "terminationPenalty": "3 months rent + unamortized costs",
      "noticeRequired": 90,
      "noticeUnit": "DAYS"
    }
  },
  "confidence": 0.94,
  "processingTimeMs": 45000,
  "extractionMetadata": {
    "pagesProcessed": 25,
    "clausesExtracted": 12,
    "obligationsExtracted": 8,
    "extractionMethod": "LLM_GPT4",
    "modelVersion": "gpt-4-turbo-preview"
  }
}
```

**Secondary Outputs**:

1. **Obligations List** (separate endpoint):
```json
{
  "success": true,
  "leaseId": "uuid",
  "obligations": [
    {
      "id": "obligation-uuid",
      "description": "Pay monthly rent...",
      "obligationType": "PAYMENT",
      "party": "TENANT",
      "deadline": "2024-02-01T00:00:00Z",
      "amount": 50000,
      "currency": "USD",
      "status": "PENDING",
      "sourceClause": "Section 3.1"
    }
  ],
  "count": 8
}
```

2. **Version Comparison Output**:
```json
{
  "success": true,
  "fromVersion": {
    "id": "version-uuid-1",
    "versionNumber": 1,
    "processedAt": "2024-01-15T10:00:00Z"
  },
  "toVersion": {
    "id": "version-uuid-2",
    "versionNumber": 2,
    "processedAt": "2024-06-15T10:00:00Z"
  },
  "changes": {
    "summary": "Lease amended to extend term by 12 months and increase rent by 5%",
    "financialChanges": {
      "rentChanged": true,
      "oldRent": 50000,
      "newRent": 52500,
      "depositChanged": false,
      "escalationsChanged": true
    },
    "dateChanges": {
      "endDateChanged": true,
      "oldEndDate": "2026-12-31",
      "newEndDate": "2027-12-31",
      "renewalOptionsChanged": false
    },
    "clauseChanges": [
      {
        "type": "MODIFIED",
        "clause": "Rent Payment",
        "oldValue": "$50,000/month",
        "newValue": "$52,500/month",
        "impact": "HIGH"
      }
    ],
    "obligationChanges": [
      {
        "type": "ADDED",
        "description": "New maintenance obligation for HVAC system",
        "impact": "MEDIUM"
      }
    ]
  },
  "significantChanges": true
}
```

#### Phase 2: Contract Intelligence Outputs

**Primary Output**: Structured Contract Abstraction

**Output Format** (JSON):

```json
{
  "success": true,
  "contractId": "uuid",
  "abstractedTerms": {
    "parties": {
      "partyA": {
        "name": "Acme Corporation",
        "entityType": "CORPORATION",
        "contactInfo": {
          "email": "legal@acme.com",
          "phone": "+1-555-0100"
        }
      },
      "partyB": {
        "name": "Tech Services Inc",
        "entityType": "CORPORATION",
        "contactInfo": {
          "email": "contracts@techservices.com",
          "phone": "+1-555-0200"
        }
      }
    },
    "contractDetails": {
      "contractType": "SERVICE",
      "jurisdiction": "New York, USA",
      "governingLaw": "New York State Law",
      "effectiveDate": "2024-01-01",
      "expirationDate": "2026-12-31",
      "autoRenewal": true,
      "renewalTerms": "Automatic renewal for 1-year terms unless terminated with 60 days notice"
    },
    "financialTerms": {
      "paymentTerms": "Net 30",
      "paymentSchedule": [
        {
          "amount": 100000,
          "currency": "USD",
          "dueDate": "2024-02-01",
          "milestone": "Monthly retainer"
        }
      ],
      "lateFees": "1.5% per month on overdue amounts",
      "terminationFees": "Early termination fee of 3 months retainer"
    },
    "clauses": [
      {
        "clauseNumber": "5.1",
        "clauseType": "TERMINATION",
        "clauseTitle": "Termination for Convenience",
        "clauseText": "Either party may terminate this agreement...",
        "appliesTo": "BOTH",
        "section": "Section 5",
        "pageNumber": 3
      },
      {
        "clauseNumber": "6.2",
        "clauseType": "LIABILITY",
        "clauseTitle": "Limitation of Liability",
        "clauseText": "In no event shall either party...",
        "appliesTo": "BOTH",
        "section": "Section 6",
        "pageNumber": 4
      }
    ],
    "obligations": [
      {
        "description": "Deliver monthly service reports by the 5th of each month",
        "obligationType": "DELIVERY",
        "party": "PARTY_B",
        "deadline": "2024-02-05",
        "frequency": "MONTHLY",
        "conditions": "Must include performance metrics",
        "triggers": ["Service delivery completion"],
        "dependencies": ["Service performance obligation"]
      },
      {
        "description": "Pay monthly retainer of $100,000 within 30 days of invoice",
        "obligationType": "PAYMENT",
        "party": "PARTY_A",
        "deadline": "2024-02-01",
        "frequency": "MONTHLY",
        "amount": 100000,
        "currency": "USD"
      }
    ]
  },
  "clauses": [
    {
      "id": "clause-uuid",
      "clauseNumber": "5.1",
      "clauseType": "TERMINATION",
      "clauseTitle": "Termination for Convenience",
      "clauseText": "Either party may terminate...",
      "versionNumber": 1,
      "confidence": 0.96
    }
  ],
  "obligations": [
    {
      "id": "obligation-uuid",
      "description": "Deliver monthly service reports...",
      "obligationType": "DELIVERY",
      "party": "PARTY_B",
      "deadline": "2024-02-05",
      "confidence": 0.93
    }
  ],
  "confidence": 0.95,
  "processingTimeMs": 52000
}
```

**Clause Evolution Output**:

```json
{
  "success": true,
  "contract_id": "uuid",
  "old_version": 1,
  "new_version": 2,
  "new_clauses": [
    {
      "clauseNumber": "8.5",
      "clauseType": "DATA_PROTECTION",
      "clauseTitle": "GDPR Compliance",
      "clauseText": "Party B agrees to comply with GDPR...",
      "change_type": "ADDED"
    }
  ],
  "modified_clauses": [
    {
      "clause": {
        "clauseNumber": "6.2",
        "clauseType": "LIABILITY",
        "clauseText": "In no event shall either party be liable for more than $500,000..."
      },
      "old_clause": {
        "clauseNumber": "6.2",
        "clauseType": "LIABILITY",
        "clauseText": "In no event shall either party be liable for more than $250,000..."
      },
      "changes": {
        "has_changes": true,
        "text_changed": true,
        "change_type": "SIGNIFICANT_MODIFICATION",
        "text_diff": "@@ -1,1 +1,1 @@\n-In no event...$250,000\n+In no event...$500,000"
      }
    }
  ],
  "deleted_clauses": [
    {
      "clauseNumber": "7.3",
      "clauseType": "NON_COMPETE",
      "clauseTitle": "Non-Compete Restriction",
      "change_type": "DELETED"
    }
  ],
  "summary": "Contract version 2 adds GDPR compliance clause, increases liability cap from $250K to $500K, and removes non-compete restriction.",
  "statistics": {
    "total_old_clauses": 15,
    "total_new_clauses": 15,
    "new_count": 1,
    "modified_count": 1,
    "deleted_count": 1,
    "unchanged_count": 13
  }
}
```

**Obligation Dependency Graph Output**:

```json
{
  "success": true,
  "graph": {
    "nodes": 12,
    "edges": 8
  },
  "dependencies": [
    {
      "source_obligation_id": "obligation-uuid-1",
      "target_obligation_id": "obligation-uuid-2",
      "dependency_type": "TRIGGERS",
      "description": "Service delivery completion triggers payment obligation",
      "confidence": 0.92,
      "strength": "STRONG",
      "sourceContractId": "contract-uuid",
      "targetContractId": "contract-uuid"
    },
    {
      "source_obligation_id": "obligation-uuid-3",
      "target_obligation_id": "obligation-uuid-4",
      "dependency_type": "BLOCKS",
      "description": "Non-payment blocks service delivery",
      "confidence": 0.88,
      "strength": "STRONG"
    }
  ],
  "analysis": {
    "root_nodes": ["obligation-uuid-1"],
    "leaf_nodes": ["obligation-uuid-5", "obligation-uuid-6"],
    "hub_nodes": ["obligation-uuid-2"],
    "max_in_degree": 3,
    "max_out_degree": 4,
    "is_acyclic": true
  },
  "critical_paths": [
    [
      "obligation-uuid-1",
      "obligation-uuid-2",
      "obligation-uuid-5"
    ]
  ],
  "cascade_risks": [
    {
      "obligation_id": "obligation-uuid-2",
      "cascade_count": 5,
      "max_depth": 3,
      "risk_level": "HIGH",
      "description": "Payment obligation failure would cascade to 5 other obligations"
    }
  ],
  "statistics": {
    "total_obligations": 12,
    "total_dependencies": 8,
    "max_cascade_depth": 3
  }
}
```

**Cascading Obligations Output**:

```json
{
  "success": true,
  "obligation_id": "obligation-uuid-2",
  "cascading_obligations": [
    {
      "obligation_id": "obligation-uuid-5",
      "dependency_path": ["obligation-uuid-2", "obligation-uuid-5"],
      "dependency_type": "TRIGGERS",
      "depth": 1,
      "description": "Service delivery obligation"
    },
    {
      "obligation_id": "obligation-uuid-6",
      "dependency_path": ["obligation-uuid-2", "obligation-uuid-5", "obligation-uuid-6"],
      "dependency_type": "REQUIRES",
      "depth": 2,
      "description": "Quality assurance obligation"
    }
  ],
  "total_cascade_count": 5,
  "max_depth": 3,
  "risk_assessment": {
    "risk_level": "HIGH",
    "impact": "Payment failure would prevent service delivery and quality assurance, affecting 5 downstream obligations"
  }
}
```

---

### UAT Testing Experiences

#### Phase 1: Lease Abstraction UAT Scenarios

**UAT Test Case 1: Basic Lease Upload and Abstraction**

**User Story**: As a Real Estate Manager, I want to upload a lease document and get structured data extracted automatically.

**Test Steps**:
1. Navigate to "Leases" section
2. Click "Upload New Lease"
3. Fill in required fields:
   - Lease Number: "TEST-LEASE-001"
   - Tenant Name: "Test Corporation"
   - Property Address: "123 Test St, Test City, ST 12345"
   - Start Date: "2024-01-01"
   - End Date: "2026-12-31"
4. Upload lease document (PDF, 15 pages)
5. Click "Upload and Process"
6. Wait for processing (expected: 30-60 seconds)
7. View abstracted lease data

**Expected Results**:
- ✅ Lease status changes from "PENDING" → "PROCESSING" → "COMPLETED"
- ✅ Financial terms extracted (base rent, deposit, escalations)
- ✅ Key dates extracted (start, end, renewal options)
- ✅ At least 5 obligations extracted
- ✅ Key clauses identified (termination, assignment, maintenance)
- ✅ Confidence score > 0.85
- ✅ Processing time < 2 minutes

**Acceptance Criteria**:
- All required fields populated
- No errors in processing
- Data matches source document
- User can view and edit extracted data

---

**UAT Test Case 2: Lease Version Comparison**

**User Story**: As a Real Estate Manager, I want to compare two versions of a lease to see what changed.

**Test Steps**:
1. Open existing lease (from Test Case 1)
2. Navigate to "Versions" tab
3. Click "Upload New Version"
4. Upload amended lease document (same lease, modified terms)
5. Wait for processing
6. Click "Compare Versions"
7. Review change summary

**Expected Results**:
- ✅ New version created (version 2)
- ✅ Changes identified:
  - Financial changes (rent increase detected)
  - Date changes (end date extended)
  - Clause modifications
- ✅ Change summary generated
- ✅ Significant changes flagged
- ✅ Diff view shows exact text changes

**Acceptance Criteria**:
- All changes accurately identified
- Change summary is readable and actionable
- User can drill down into specific changes
- No false positives (unchanged items marked as changed)

---

**UAT Test Case 3: Obligation Tracking and Alerts**

**User Story**: As a Real Estate Manager, I want to see all obligations from my leases and get alerts for upcoming deadlines.

**Test Steps**:
1. Navigate to "Obligations" section
2. View list of all obligations
3. Filter by:
   - Status (Pending, Overdue)
   - Type (Payment, Maintenance, etc.)
   - Lease
4. Sort by deadline
5. Click on overdue obligation
6. Mark obligation as completed

**Expected Results**:
- ✅ All obligations from all leases displayed
- ✅ Overdue obligations highlighted in red
- ✅ Upcoming deadlines (next 30 days) highlighted in yellow
- ✅ Filtering works correctly
- ✅ Obligation details show:
  - Description
  - Deadline
  - Amount (if applicable)
  - Source clause
  - Status
- ✅ Status update persists

**Acceptance Criteria**:
- Obligations accurately extracted from leases
- Deadlines correctly parsed
- Alerts trigger for overdue items
- Status updates work correctly

---

**UAT Test Case 4: Error Handling - Invalid Document**

**User Story**: As a Real Estate Manager, I want clear error messages when something goes wrong.

**Test Steps**:
1. Upload corrupted PDF file
2. Upload non-lease document (e.g., invoice)
3. Upload lease with missing required fields
4. Upload lease exceeding size limit (50MB+)

**Expected Results**:
- ✅ Clear error message for corrupted file: "Unable to extract text from document. Please ensure the file is not corrupted."
- ✅ Warning for non-lease document: "Document may not be a lease. Processing may be inaccurate."
- ✅ Validation error for missing fields: "Lease number is required"
- ✅ Size limit error: "File size exceeds 50MB limit. Please compress or split the document."

**Acceptance Criteria**:
- All errors are user-friendly
- Errors include actionable guidance
- System doesn't crash on errors
- Error state is recoverable

---

**UAT Test Case 5: Bulk Lease Upload**

**User Story**: As a Real Estate Manager, I want to upload multiple leases at once.

**Test Steps**:
1. Navigate to "Leases" section
2. Click "Bulk Upload"
3. Select 10 lease PDF files
4. Upload all at once
5. Monitor processing status
6. Review results

**Expected Results**:
- ✅ All 10 leases uploaded successfully
- ✅ Processing queue shows progress
- ✅ Each lease processes independently
- ✅ Results available as they complete
- ✅ Failed leases show error messages
- ✅ Success rate > 90%

**Acceptance Criteria**:
- Bulk upload works for 10+ files
- Processing doesn't block UI
- Individual lease failures don't affect others
- Progress tracking is accurate

---

#### Phase 2: Contract Intelligence UAT Scenarios

**UAT Test Case 6: Contract Upload and Clause Extraction**

**User Story**: As a General Counsel, I want to upload a contract and extract all clauses automatically.

**Test Steps**:
1. Navigate to "Contracts" section
2. Click "Upload New Contract"
3. Fill in required fields:
   - Contract Number: "CONTRACT-2024-001"
   - Contract Name: "Master Services Agreement"
   - Party A: "Acme Corp"
   - Party B: "Tech Services Inc"
4. Upload contract document (PDF, 20 pages)
5. Wait for processing
6. View extracted clauses

**Expected Results**:
- ✅ Contract status: "COMPLETED"
- ✅ At least 10 clauses extracted
- ✅ Clause types correctly identified:
  - Termination clauses
  - Payment clauses
  - Liability clauses
  - Indemnification clauses
- ✅ Clauses linked to source sections
- ✅ Confidence score > 0.90

**Acceptance Criteria**:
- All major clauses extracted
- Clause types accurate
- Source references correct
- User can navigate to clause in original document

---

**UAT Test Case 7: Clause Evolution Tracking**

**User Story**: As a General Counsel, I want to see how contract clauses changed between versions.

**Test Steps**:
1. Open contract from Test Case 6
2. Upload version 2 of contract (amended)
3. Navigate to "Clause Evolution" tab
4. Compare version 1 vs version 2
5. Review change summary
6. Click on modified clause to see diff

**Expected Results**:
- ✅ New clauses identified
- ✅ Modified clauses highlighted
- ✅ Deleted clauses listed
- ✅ Change summary explains:
  - What changed
  - Why it matters
  - Impact assessment
- ✅ Diff view shows:
  - Old text (red)
  - New text (green)
  - Unchanged text (gray)
- ✅ Significant changes flagged

**Acceptance Criteria**:
- All changes accurately detected
- No false positives
- Change summary is actionable
- Diff view is readable

---

**UAT Test Case 8: Obligation Dependency Graph Visualization**

**User Story**: As a General Counsel, I want to see how obligations cascade across contracts.

**Test Steps**:
1. Upload 3 related contracts (MSA, SOW, NDA)
2. Process all contracts
3. Navigate to "Dependency Graph" view
4. View obligation dependency graph
5. Click on obligation node
6. View cascading obligations
7. Filter by dependency type

**Expected Results**:
- ✅ Graph visualization shows:
  - Obligations as nodes
  - Dependencies as edges
  - Dependency types color-coded
- ✅ Clicking obligation shows:
  - All dependent obligations
  - Dependency path
  - Cascade depth
  - Risk level
- ✅ Filtering works:
  - By contract
  - By dependency type
  - By risk level
- ✅ Graph is interactive:
  - Zoom in/out
  - Pan
  - Node details on hover

**Acceptance Criteria**:
- Graph accurately represents dependencies
- Visualization is clear and navigable
- Cascade analysis is correct
- Performance is acceptable (< 2 seconds to render)

---

**UAT Test Case 9: Cross-Document Dependency Detection**

**User Story**: As a General Counsel, I want to see how obligations in one contract affect obligations in another.

**Test Steps**:
1. Upload Master Services Agreement (MSA)
2. Upload Statement of Work (SOW) that references MSA
3. Process both contracts
4. Navigate to "Cross-Document Dependencies"
5. View dependencies between MSA and SOW
6. Click on dependency to see details

**Expected Results**:
- ✅ Dependencies detected across contracts:
  - MSA payment obligation → SOW delivery obligation
  - MSA termination clause → SOW termination clause
- ✅ Dependency graph shows cross-contract edges
- ✅ Dependency details show:
  - Source contract and obligation
  - Target contract and obligation
  - Dependency type
  - Confidence score
- ✅ Cascade analysis includes cross-contract paths

**Acceptance Criteria**:
- Cross-contract dependencies accurately detected
- Graph visualization shows inter-contract relationships
- User can trace dependency chains across contracts
- Performance acceptable for 10+ contracts

---

**UAT Test Case 10: Compliance Risk Assessment**

**User Story**: As a CCO, I want to see which obligations have high cascade risk.

**Test Steps**:
1. Upload portfolio of 20 contracts
2. Process all contracts
3. Navigate to "Risk Assessment" dashboard
4. View high-risk obligations
5. Click on high-risk obligation
6. View cascade impact analysis

**Expected Results**:
- ✅ Risk dashboard shows:
  - High-risk obligations (cascade count > 5)
  - Medium-risk obligations (cascade count 2-5)
  - Low-risk obligations (cascade count 0-1)
- ✅ Risk metrics:
  - Total obligations: 150
  - High-risk: 12
  - Medium-risk: 35
  - Low-risk: 103
- ✅ Clicking high-risk obligation shows:
  - All dependent obligations
  - Cascade depth
  - Impact assessment
  - Recommended actions
- ✅ Export risk report (PDF/CSV)

**Acceptance Criteria**:
- Risk assessment is accurate
- High-risk obligations correctly identified
- Cascade analysis is comprehensive
- Report export works correctly

---

### UAT Testing Checklist

#### Phase 1 Testing Checklist

**Functional Testing**:
- [ ] Lease upload (single file)
- [ ] Lease upload (bulk)
- [ ] Lease abstraction accuracy (> 95%)
- [ ] Obligation extraction (> 90% accuracy)
- [ ] Version comparison
- [ ] Obligation tracking
- [ ] Overdue alerts
- [ ] Search and filtering
- [ ] Error handling

**Performance Testing**:
- [ ] Processing time < 2 minutes per lease
- [ ] Bulk upload (10 leases) < 10 minutes
- [ ] API response time < 500ms
- [ ] Concurrent users (10+) supported

**Usability Testing**:
- [ ] UI is intuitive
- [ ] Error messages are clear
- [ ] Data is editable
- [ ] Export functionality works
- [ ] Mobile responsive (if applicable)

#### Phase 2 Testing Checklist

**Functional Testing**:
- [ ] Contract upload and processing
- [ ] Clause extraction (> 95% accuracy)
- [ ] Clause evolution tracking
- [ ] Obligation dependency detection
- [ ] Dependency graph visualization
- [ ] Cross-contract dependencies
- [ ] Cascade risk analysis
- [ ] Critical path identification

**Performance Testing**:
- [ ] Contract processing < 3 minutes
- [ ] Dependency graph build < 5 seconds (100 obligations)
- [ ] Clause comparison < 10 seconds
- [ ] Graph visualization render < 2 seconds

**Integration Testing**:
- [ ] Contract-to-lease dependencies
- [ ] Multi-contract analysis
- [ ] Real-time updates
- [ ] Event publishing

---

### Training Data Quality Metrics

**Data Quality Requirements**:

1. **Coverage**:
   - Lease types: Office (40%), Retail (30%), Industrial (20%), Other (10%)
   - Contract types: Service (35%), Supply (25%), MSA (20%), NDA (10%), Other (10%)
   - Jurisdictions: US Federal (30%), State (40%), International (30%)

2. **Accuracy**:
   - Ground truth annotation accuracy: > 99%
   - Inter-annotator agreement: > 95%
   - Validation set accuracy: > 90%

3. **Diversity**:
   - Document lengths: 5-100 pages
   - Language complexity: Simple to complex legal language
   - Industry sectors: 10+ industries

4. **Freshness**:
   - Training data updated quarterly
   - New regulations incorporated within 30 days
   - Customer feedback integrated monthly

---

This completes the comprehensive plan including AI inputs, training data, outputs, and UAT testing experiences for Phases 1 and 2.

