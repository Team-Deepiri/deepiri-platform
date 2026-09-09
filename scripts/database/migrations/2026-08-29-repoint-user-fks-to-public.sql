-- Repoint portal foreign keys from identity.users to public.users.
--
-- WHY
-- Two bootstrap paths populated this database independently: Postgres first-boot
-- ran postgres-init-platform.sh (creating identity/org/portal/... — 33 tables),
-- and auth-service boot ran `prisma migrate deploy`, whose schema declares no
-- @@schema and therefore created its own users/sessions/api_keys/user_roles in
-- `public`. Neither failed, because they wrote to different schemas.
--
-- The result: real users live in public.users, while every portal table's FK
-- points at identity.users, which is empty. Any portal write fails with
--   insert or update ... violates foreign key constraint
--   Key (author_id)=(...) is not present in table "users"
--
-- This migration makes public.users canonical (Option B): auth-service is not
-- touched at all, and the portal tables become writable.
--
-- SAFETY
-- Every affected table is empty (verified 2026-08-29), so dropping and re-adding
-- these constraints cannot fail on existing data. The whole thing runs in one
-- transaction — it either fully applies or fully rolls back.
--
-- The identity.* tables are intentionally LEFT IN PLACE. identity.roles and
-- identity.invites have no public equivalent, and the redundant four
-- (users/sessions/api_keys/user_roles) are empty and harmless. Dropping them is
-- optional cleanup for a later change, not part of this one.
--
-- APPLY
--   docker exec -i deepiri-postgres-platform \
--     psql -U postgres -d platform -v ON_ERROR_STOP=1 \
--     < scripts/database/migrations/2026-08-29-repoint-user-fks-to-public.sql

\set ON_ERROR_STOP on

BEGIN;

-- Guard: refuse to run if the target table isn't there.
DO $guard$
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'public.users does not exist — aborting';
  END IF;
  IF to_regclass('identity.users') IS NULL THEN
    RAISE NOTICE 'identity.users absent; nothing to repoint';
  END IF;
END
$guard$;

-- Repoint every FK outside the identity schema that references identity.users.
-- Constraint definitions are read back from the catalog, so ON DELETE CASCADE /
-- SET NULL behaviour is preserved exactly as each table declared it.
DO $repoint$
DECLARE
  r        RECORD;
  new_def  TEXT;
  n        INT := 0;
BEGIN
  IF to_regclass('identity.users') IS NULL THEN
    RETURN;
  END IF;

  FOR r IN
    SELECT con.conname,
           nsp.nspname AS schema_name,
           rel.relname AS table_name,
           pg_get_constraintdef(con.oid) AS def
      FROM pg_constraint con
      JOIN pg_class     rel ON rel.oid = con.conrelid
      JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
     WHERE con.contype  = 'f'
       AND con.confrelid = 'identity.users'::regclass
       AND nsp.nspname <> 'identity'
     ORDER BY nsp.nspname, rel.relname, con.conname
  LOOP
    new_def := replace(r.def, 'REFERENCES identity.users', 'REFERENCES public.users');

    IF new_def = r.def THEN
      RAISE EXCEPTION 'could not rewrite constraint %.% %: unexpected definition: %',
        r.schema_name, r.table_name, r.conname, r.def;
    END IF;

    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',
                   r.schema_name, r.table_name, r.conname);
    EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I %s',
                   r.schema_name, r.table_name, r.conname, new_def);

    n := n + 1;
    RAISE NOTICE 'repointed %.%.% -> public.users', r.schema_name, r.table_name, r.conname;
  END LOOP;

  RAISE NOTICE 'repointed % constraint(s)', n;

  IF n = 0 THEN
    RAISE NOTICE 'nothing to do — already repointed, or identity.users unreferenced';
  END IF;
END
$repoint$;

-- Verify: no FK outside identity.* may still reference identity.users.
DO $verify$
DECLARE leftover INT;
BEGIN
  IF to_regclass('identity.users') IS NULL THEN
    RETURN;
  END IF;

  SELECT count(*) INTO leftover
    FROM pg_constraint con
    JOIN pg_class     rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
   WHERE con.contype   = 'f'
     AND con.confrelid = 'identity.users'::regclass
     AND nsp.nspname  <> 'identity';

  IF leftover > 0 THEN
    RAISE EXCEPTION 'verification failed: % constraint(s) still reference identity.users', leftover;
  END IF;

  RAISE NOTICE 'verified: no external FK references identity.users';
END
$verify$;

COMMIT;
