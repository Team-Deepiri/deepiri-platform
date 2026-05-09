-- Composite indexes for messaging read-heavy query paths.
-- 1. Message timeline queries filter by chat_room_id + is_deleted and sort by created_at DESC.
-- 2. User room membership queries filter active participants by user_id and join back via chat_room_id.

CREATE INDEX "chat_participants_user_id_is_active_chat_room_id_idx"
ON "messaging"."chat_participants" ("user_id", "is_active", "chat_room_id");

CREATE INDEX "messages_chat_room_id_is_deleted_created_at_idx"
ON "messaging"."messages" ("chat_room_id", "is_deleted", "created_at" DESC);
