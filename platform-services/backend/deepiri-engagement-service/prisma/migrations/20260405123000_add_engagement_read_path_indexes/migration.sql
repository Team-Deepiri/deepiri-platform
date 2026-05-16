-- Composite indexes for engagement-service read-heavy query paths.
-- 1. Reward list queries filter by user_id, may add status, and sort by created_at DESC.
-- 2. Pending reward count queries filter by user_id + status and inspect expires_at.

CREATE INDEX "rewards_user_id_status_created_at_idx"
ON "public"."rewards" ("user_id", "status", "created_at" DESC);

CREATE INDEX "rewards_user_id_status_expires_at_idx"
ON "public"."rewards" ("user_id", "status", "expires_at");
