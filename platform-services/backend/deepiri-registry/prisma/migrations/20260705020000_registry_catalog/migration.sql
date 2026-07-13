CREATE SCHEMA IF NOT EXISTS "registry";

DROP TABLE IF EXISTS "public"."task_completions" CASCADE;
DROP TABLE IF EXISTS "public"."boost_history" CASCADE;
DROP TABLE IF EXISTS "public"."active_boosts" CASCADE;
DROP TABLE IF EXISTS "public"."boosts" CASCADE;
DROP TABLE IF EXISTS "public"."cashed_in_streaks" CASCADE;
DROP TABLE IF EXISTS "public"."streaks" CASCADE;
DROP TABLE IF EXISTS "public"."achievements" CASCADE;
DROP TABLE IF EXISTS "public"."level_progress" CASCADE;
DROP TABLE IF EXISTS "public"."momentum" CASCADE;
DROP TABLE IF EXISTS "public"."rewards" CASCADE;
DROP TABLE IF EXISTS "public"."subtasks" CASCADE;
DROP TABLE IF EXISTS "public"."tasks" CASCADE;
DROP TABLE IF EXISTS "public"."quest_milestones" CASCADE;
DROP TABLE IF EXISTS "public"."quests" CASCADE;
DROP TABLE IF EXISTS "public"."season_boosts" CASCADE;
DROP TABLE IF EXISTS "public"."seasons" CASCADE;

CREATE TABLE "registry"."repos" (
    "id" UUID NOT NULL,
    "org" VARCHAR(128) NOT NULL DEFAULT 'Team-Deepiri',
    "name" VARCHAR(255) NOT NULL,
    "display_name" VARCHAR(255),
    "github_url" TEXT,
    "tier" INTEGER NOT NULL DEFAULT 1,
    "description" TEXT,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP NOT NULL,
    CONSTRAINT "repos_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "repos_org_name_key" ON "registry"."repos"("org", "name");
CREATE INDEX "repos_tier_idx" ON "registry"."repos"("tier");

CREATE TABLE "registry"."repo_health_checks" (
    "id" UUID NOT NULL,
    "repo_id" UUID NOT NULL,
    "status" VARCHAR(32) NOT NULL,
    "detail" TEXT,
    "checked_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "repo_health_checks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "repo_health_checks_repo_id_fkey" FOREIGN KEY ("repo_id") REFERENCES "registry"."repos"("id") ON DELETE CASCADE
);

CREATE INDEX "repo_health_checks_repo_id_idx" ON "registry"."repo_health_checks"("repo_id");
CREATE INDEX "repo_health_checks_checked_at_idx" ON "registry"."repo_health_checks"("checked_at");

CREATE TABLE "registry"."tool_registrations" (
    "id" UUID NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "kind" VARCHAR(64) NOT NULL,
    "description" TEXT,
    "endpoint" TEXT,
    "metadata" JSONB DEFAULT '{}',
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP NOT NULL,
    CONSTRAINT "tool_registrations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "tool_registrations_name_key" ON "registry"."tool_registrations"("name");

CREATE TABLE "registry"."registered_services" (
    "id" UUID NOT NULL,
    "name" VARCHAR(128) NOT NULL,
    "repo" VARCHAR(255),
    "health_url" TEXT,
    "tier" INTEGER NOT NULL DEFAULT 1,
    "status" VARCHAR(32) NOT NULL DEFAULT 'unknown',
    "last_seen" TIMESTAMP,
    "metadata" JSONB DEFAULT '{}',
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP NOT NULL,
    CONSTRAINT "registered_services_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "registered_services_name_key" ON "registry"."registered_services"("name");
CREATE INDEX "registered_services_status_idx" ON "registry"."registered_services"("status");
