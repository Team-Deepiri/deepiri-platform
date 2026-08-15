-- 031_pipeline_memo_index.sql
--
-- Stage memoization asks "has <stage_name> already run with <input_hash>, in
-- ANY run?" so it can reuse the artifacts instead of re-paying for the work.
--
-- The PK shipped in 030 is (run_id, stage_name, input_ref), which cannot serve
-- that predicate: run_id is the leading column and the lookup does not know it.
-- Without this index the memo lookup degrades to a sequential scan over every
-- stage input ever recorded, so the feature gets slower exactly as the corpus
-- that makes it valuable grows.
--
-- 030 has shipped, so per scripts/database/cyrex/README.md rule 1 this is a new
-- numbered file rather than an edit.

CREATE INDEX IF NOT EXISTS idx_pipeline_stage_inputs_memo
    ON cyrex.pipeline_stage_inputs (stage_name, input_hash);

-- The memo join filters outputs down to completed stages, so support that side
-- of the join too.
CREATE INDEX IF NOT EXISTS idx_pipeline_run_stages_completed
    ON cyrex.pipeline_run_stages (stage_name, status, completed_at DESC);
