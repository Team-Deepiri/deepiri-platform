DROP TABLE IF EXISTS "task_dependencies" CASCADE;
DROP TABLE IF EXISTS "task_versions" CASCADE;
DROP TABLE IF EXISTS "tasks" CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;
DROP TABLE IF EXISTS "Project" CASCADE;
DROP TABLE IF EXISTS "Quest" CASCADE;

CREATE TABLE "truss_definitions" (
  "id" UUID NOT NULL,
  "name" VARCHAR(255) NOT NULL,
  "description" TEXT,
  "version" INTEGER NOT NULL DEFAULT 1,
  "steps" JSONB NOT NULL DEFAULT '[]',
  "metadata" JSONB NOT NULL DEFAULT '{}',
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP NOT NULL,

  CONSTRAINT "truss_definitions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "truss_runs" (
  "id" UUID NOT NULL,
  "definition_id" UUID NOT NULL,
  "status" VARCHAR(32) NOT NULL DEFAULT 'queued',
  "input" JSONB NOT NULL DEFAULT '{}',
  "output" JSONB,
  "error" TEXT,
  "current_step" VARCHAR(255),
  "started_at" TIMESTAMP,
  "completed_at" TIMESTAMP,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP NOT NULL,

  CONSTRAINT "truss_runs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "truss_step_runs" (
  "id" UUID NOT NULL,
  "run_id" UUID NOT NULL,
  "step_id" VARCHAR(255) NOT NULL,
  "kind" VARCHAR(64) NOT NULL,
  "status" VARCHAR(32) NOT NULL DEFAULT 'queued',
  "input" JSONB NOT NULL DEFAULT '{}',
  "output" JSONB,
  "error" TEXT,
  "external_ref" VARCHAR(255),
  "started_at" TIMESTAMP,
  "completed_at" TIMESTAMP,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP NOT NULL,

  CONSTRAINT "truss_step_runs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "truss_definitions_name_version_key"
  ON "truss_definitions"("name", "version");

CREATE UNIQUE INDEX "truss_step_runs_run_id_step_id_key"
  ON "truss_step_runs"("run_id", "step_id");

CREATE INDEX "truss_definitions_enabled_idx"
  ON "truss_definitions"("enabled");

CREATE INDEX "truss_definitions_name_idx"
  ON "truss_definitions"("name");

CREATE INDEX "truss_runs_definition_id_idx"
  ON "truss_runs"("definition_id");

CREATE INDEX "truss_runs_status_idx"
  ON "truss_runs"("status");

CREATE INDEX "truss_step_runs_run_id_idx"
  ON "truss_step_runs"("run_id");

CREATE INDEX "truss_step_runs_status_idx"
  ON "truss_step_runs"("status");

CREATE INDEX "truss_step_runs_external_ref_idx"
  ON "truss_step_runs"("external_ref");

ALTER TABLE "truss_runs"
  ADD CONSTRAINT "truss_runs_definition_id_fkey"
  FOREIGN KEY ("definition_id")
  REFERENCES "truss_definitions"("id")
  ON DELETE CASCADE
  ON UPDATE CASCADE;

ALTER TABLE "truss_step_runs"
  ADD CONSTRAINT "truss_step_runs_run_id_fkey"
  FOREIGN KEY ("run_id")
  REFERENCES "truss_runs"("id")
  ON DELETE CASCADE
  ON UPDATE CASCADE;