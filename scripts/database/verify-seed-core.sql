-- Verify seed data for Core database (deepiri)
-- Usage:
--   psql -U deepiri -d deepiri -f scripts/database/verify-seed-core.sql

WITH checks AS (
    SELECT 'projects_seeded'::text AS check_name, 3::bigint AS expected, (SELECT COUNT(*) FROM public.projects WHERE id::text LIKE '10000000-%')::bigint AS actual, '='::text AS op
    UNION ALL
    SELECT 'project_milestones_seeded', 4, (
        SELECT COUNT(*)
        FROM public.project_milestones
        WHERE project_id::text IN (
            '10000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000002'
        )
    ), '>='
    UNION ALL
    SELECT 'quests_seeded', 3, (SELECT COUNT(*) FROM public.quests WHERE id::text LIKE '20000000-%'), '='
    UNION ALL
    SELECT 'tasks_seeded', 5, (SELECT COUNT(*) FROM public.tasks WHERE id::text LIKE '30000000-%'), '='
    UNION ALL
    SELECT 'subtasks_seeded', 7, (
        SELECT COUNT(*)
        FROM public.subtasks
        WHERE task_id::text IN (
            '30000000-0000-0000-0000-000000000001',
            '30000000-0000-0000-0000-000000000002'
        )
    ), '>='
    UNION ALL
    SELECT 'analytics_momentum_seeded', 5, (SELECT COUNT(*) FROM analytics.momentum WHERE user_id::text LIKE '00000000-%'), '='
    UNION ALL
    SELECT 'analytics_streaks_seeded', 5, (SELECT COUNT(*) FROM analytics.streaks WHERE user_id::text LIKE '00000000-%'), '='
    UNION ALL
    SELECT 'analytics_boosts_seeded', 5, (SELECT COUNT(*) FROM analytics.boosts WHERE user_id::text LIKE '00000000-%'), '='
    UNION ALL
    SELECT 'analytics_achievements_seeded', 3, (
        SELECT COUNT(*)
        FROM analytics.achievements
        WHERE achievement_id IN ('early_adopter', 'first_task')
    ), '>='
    UNION ALL
    SELECT 'audit_user_activity_summary_seeded', 5, (SELECT COUNT(*) FROM audit.user_activity_summary WHERE user_id::text LIKE '00000000-%'), '='
    UNION ALL
    SELECT 'audit_task_completions_seeded', 1, (
        SELECT COUNT(*)
        FROM audit.task_completions
        WHERE task_id = '30000000-0000-0000-0000-000000000001'::UUID
          AND user_id = '00000000-0000-0000-0000-000000000002'::UUID
    ), '>='
    UNION ALL
    SELECT 'season_boosts_seeded', 3, (
        SELECT COUNT(*)
        FROM public.season_boosts
        WHERE boost_type IN ('focus', 'sprint', 'learning')
    ), '>='
),
results AS (
    SELECT
        check_name,
        op,
        expected,
        actual,
        CASE
            WHEN op = '=' AND actual = expected THEN 'PASS'
            WHEN op = '>=' AND actual >= expected THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM checks
)
SELECT * FROM results ORDER BY check_name;

