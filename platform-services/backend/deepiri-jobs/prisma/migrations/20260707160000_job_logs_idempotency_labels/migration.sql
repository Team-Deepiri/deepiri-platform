-- AlterTable
ALTER TABLE "jobs" ADD COLUMN     "labels" JSONB NOT NULL DEFAULT '{}',
ADD COLUMN     "idempotency_key" VARCHAR(255);

-- CreateIndex
CREATE UNIQUE INDEX "jobs_idempotency_key_key" ON "jobs"("idempotency_key");

-- CreateTable
CREATE TABLE "job_logs" (
    "id" UUID NOT NULL,
    "job_id" UUID NOT NULL,
    "line" TEXT NOT NULL,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "job_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "job_logs_job_id_idx" ON "job_logs"("job_id");

-- AddForeignKey
ALTER TABLE "job_logs" ADD CONSTRAINT "job_logs_job_id_fkey" FOREIGN KEY ("job_id") REFERENCES "jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
