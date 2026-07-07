-- CreateTable
CREATE TABLE "jobs" (
    "id" UUID NOT NULL,
    "type" VARCHAR(128) NOT NULL,
    "status" VARCHAR(32) NOT NULL DEFAULT 'queued',
    "payload" JSONB NOT NULL DEFAULT '{}',
    "result" JSONB,
    "error" TEXT,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP NOT NULL,

    CONSTRAINT "jobs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "jobs_status_idx" ON "jobs"("status");

-- CreateIndex
CREATE INDEX "jobs_type_idx" ON "jobs"("type");
