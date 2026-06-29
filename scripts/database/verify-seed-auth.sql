-- Verify seed data for Auth database (auth_db)
-- Usage:
--   psql -U deepiri_auth -d auth_db -f scripts/database/verify-seed-auth.sql

WITH checks AS (
    SELECT 'seed_users_@deepiri.com'::text AS check_name, 5::bigint AS expected, (SELECT COUNT(*) FROM users WHERE email LIKE '%@deepiri.com')::bigint AS actual, '='::text AS op
    UNION ALL
    SELECT 'roles_total', 4, (SELECT COUNT(*) FROM roles), '='
    UNION ALL
    SELECT 'admin_role_assignments', 1, (
        SELECT COUNT(*)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE r.name = 'admin'
    ), '='
    UNION ALL
    SELECT 'user_role_assignments', 4, (
        SELECT COUNT(*)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE r.name = 'user'
    ), '='
    UNION ALL
    SELECT 'developer_role_assignments', 2, (
        SELECT COUNT(*)
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE r.name = 'developer'
    ), '='
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
