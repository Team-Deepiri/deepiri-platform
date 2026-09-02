-- Cyrex migration 141: scene identity spawn pressure (Elkedel eyes).

-- No new tables — SceneIdentitySpawn uses cyrex.pressure_events.event_type
-- ``scene_identity_spawn``. Documented for migration ledger completeness.

COMMENT ON SCHEMA cyrex IS 'AI/Agent + Artifact Engine (documents, artifacts, pressure, elkedel memory)';
