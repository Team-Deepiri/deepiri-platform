-- ===========================
-- DEEPIRI SEED DATA
-- Development & Testing Data
-- ===========================

-- Clear existing seed data (be careful in production!)
-- This is safe because we're using ON DELETE CASCADE

DO $$
DECLARE
    seed_user_count INT;
BEGIN
    SELECT COUNT(*) INTO seed_user_count FROM public.users WHERE email LIKE '%@deepiri.com';
    IF seed_user_count > 0 THEN
        DELETE FROM public.users WHERE email LIKE '%@deepiri.com';
        RAISE NOTICE 'Cleared % existing seed users', seed_user_count;
    END IF;
END $$;

-- ===========================
-- SEED USERS
-- ===========================

-- Password for all seed users: "password123" (bcrypt hashed)
-- CHANGE THIS IN PRODUCTION!
INSERT INTO public.users (id, email, password, name, bio, status, email_verified) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Admin User', 'System administrator', 'active', true),
    ('00000000-0000-0000-0000-000000000002', 'alice@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Alice Johnson', 'Product manager who loves shipping features', 'active', true),
    ('00000000-0000-0000-0000-000000000003', 'bob@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Bob Smith', 'Senior developer and code review champion', 'active', true),
    ('00000000-0000-0000-0000-000000000004', 'carol@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Carol Davis', 'UX designer focused on user experience', 'active', true),
    ('00000000-0000-0000-0000-000000000005', 'dave@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Dave Wilson', 'DevOps engineer keeping things running', 'active', true)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    bio = EXCLUDED.bio;

-- Assign roles to users
INSERT INTO public.user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM public.users u
CROSS JOIN public.roles r
WHERE u.email = 'admin@deepiri.com' AND r.name = 'admin'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM public.users u
CROSS JOIN public.roles r
WHERE u.email IN ('alice@deepiri.com', 'bob@deepiri.com', 'carol@deepiri.com', 'dave@deepiri.com')
AND r.name = 'user'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM public.users u
CROSS JOIN public.roles r
WHERE u.email IN ('bob@deepiri.com', 'dave@deepiri.com') AND r.name = 'developer'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- ===========================
-- SEED PROJECTS
-- ===========================

INSERT INTO public.projects (id, owner_id, name, description, status, priority, metadata) VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Deepiri Platform Launch', 'Complete platform development and launch', 'active', 'urgent', '{"category": "product", "team_size": 5}'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'API Optimization', 'Improve API performance and scalability', 'active', 'high', '{"category": "engineering", "expected_improvement": "50%"}'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 'Design System v2', 'Create comprehensive design system', 'planning', 'medium', '{"category": "design", "components": 50}')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

-- Project milestones
INSERT INTO public.project_milestones (project_id, title, description, due_date, momentum_reward) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Beta Launch', 'Launch beta version to 100 users', CURRENT_TIMESTAMP + INTERVAL '30 days', 500),
    ('10000000-0000-0000-0000-000000000001', 'Public Launch', 'Full public launch', CURRENT_TIMESTAMP + INTERVAL '90 days', 1000),
    ('10000000-0000-0000-0000-000000000002', 'Performance Baseline', 'Establish performance metrics', CURRENT_TIMESTAMP + INTERVAL '7 days', 200),
    ('10000000-0000-0000-0000-000000000002', 'Optimization Complete', 'Achieve 50% improvement', CURRENT_TIMESTAMP + INTERVAL '45 days', 400);

-- ===========================
-- SEED QUESTS
-- ===========================

INSERT INTO public.quests (id, user_id, season_id, title, description, status, total_objectives, metadata) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', (SELECT id FROM public.seasons WHERE is_active = true LIMIT 1), 'Ship First Feature', 'Ship the first major feature of Season 1', 'active', 5, '{"difficulty": "medium", "estimated_hours": 40}'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', (SELECT id FROM public.seasons WHERE is_active = true LIMIT 1), 'Code Review Master', 'Complete 50 code reviews with quality feedback', 'active', 50, '{"difficulty": "hard", "focus": "quality"}'),
    ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', (SELECT id FROM public.seasons WHERE is_active = true LIMIT 1), 'Design Sprint', 'Complete comprehensive design sprint', 'planning', 10, '{"difficulty": "medium", "deliverables": ["wireframes", "mockups", "prototypes"]}')
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description;

-- ===========================
-- SEED TASKS
-- ===========================

INSERT INTO public.tasks (id, user_id, project_id, quest_id, title, description, status, priority, difficulty, momentum_reward, ai_suggestions, tags, metadata) VALUES
    ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Setup PostgreSQL migration', 'Migrate from MongoDB to PostgreSQL', 'done', 'urgent', 'hard', 150, 
     '[{"suggestion": "Create comprehensive migration scripts", "type": "task_breakdown", "confidence": 0.9}]'::jsonb,
     ARRAY['database', 'migration', 'postgresql'],
     '{"estimated_complexity": "high", "requires_review": true}'),
    
    ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Implement user authentication', 'JWT-based auth system', 'in_progress', 'high', 'medium', 100,
     '[{"suggestion": "Use industry-standard JWT library", "type": "optimization", "confidence": 0.95}, {"suggestion": "Add refresh token mechanism", "type": "resource", "confidence": 0.85}]'::jsonb,
     ARRAY['auth', 'security', 'backend'],
     '{"requires_security_review": true}'),
    
    ('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', null, 'Optimize database queries', 'Add indexes and optimize slow queries', 'todo', 'high', 'medium', 120,
     '[{"suggestion": "Start with EXPLAIN ANALYZE on slow queries", "type": "task_breakdown", "confidence": 0.9}, {"suggestion": "Consider query result caching", "type": "optimization", "confidence": 0.8}]'::jsonb,
     ARRAY['performance', 'database', 'optimization'],
     '{"performance_target": "sub_100ms"}'),
    
    ('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'Create component library', 'Build reusable React components', 'in_progress', 'medium', 'medium', 80,
     '[{"suggestion": "Use Storybook for component documentation", "type": "resource", "confidence": 0.92}, {"suggestion": "Implement accessibility standards", "type": "optimization", "confidence": 0.88}]'::jsonb,
     ARRAY['design', 'frontend', 'react'],
     '{"accessibility_required": true, "documentation": "storybook"}'),
    
    ('30000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', null, null, 'Setup CI/CD pipeline', 'Configure GitHub Actions for automated deployment', 'todo', 'high', 'hard', 130,
     '[{"suggestion": "Use Docker for consistent environments", "type": "optimization", "confidence": 0.94}, {"suggestion": "Implement blue-green deployment", "type": "resource", "confidence": 0.75}]'::jsonb,
     ARRAY['devops', 'ci-cd', 'automation'],
     '{"deployment_target": "production", "rollback_strategy": "required"}')
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description;

-- Subtasks
INSERT INTO public.subtasks (task_id, title, completed, momentum_reward, sort_order) VALUES
    ('30000000-0000-0000-0000-000000000001', 'Create migration scripts', true, 30, 1),
    ('30000000-0000-0000-0000-000000000001', 'Update docker-compose files', true, 30, 2),
    ('30000000-0000-0000-0000-000000000001', 'Update environment variables', true, 30, 3),
    ('30000000-0000-0000-0000-000000000001', 'Test migration', false, 30, 4),
    ('30000000-0000-0000-0000-000000000002', 'Design auth schema', true, 20, 1),
    ('30000000-0000-0000-0000-000000000002', 'Implement JWT generation', false, 30, 2),
    ('30000000-0000-0000-0000-000000000002', 'Add refresh token logic', false, 30, 3);

-- ===========================
-- SEED ANALYTICS DATA
-- ===========================

-- Initialize momentum for all users
INSERT INTO analytics.momentum (user_id, total_momentum, current_level, commits, docs, tasks, features_shipped)
SELECT id, 
       (RANDOM() * 1000)::INT, 
       (RANDOM() * 5 + 1)::INT,
       (RANDOM() * 50)::INT,
       (RANDOM() * 20)::INT,
       (RANDOM() * 100)::INT,
       (RANDOM() * 10)::INT
FROM public.users
WHERE email LIKE '%@deepiri.com'
ON CONFLICT (user_id) DO UPDATE SET
    total_momentum = EXCLUDED.total_momentum;

-- Initialize streaks
INSERT INTO analytics.streaks (user_id, daily_current, daily_longest, daily_last_date, weekly_current, weekly_longest)
SELECT id,
       (RANDOM() * 7)::INT,
       (RANDOM() * 30)::INT,
       CURRENT_DATE,
       (RANDOM() * 4)::INT,
       (RANDOM() * 12)::INT
FROM public.users
WHERE email LIKE '%@deepiri.com'
ON CONFLICT (user_id) DO UPDATE SET
    daily_current = EXCLUDED.daily_current;

-- Initialize boosts
INSERT INTO analytics.boosts (user_id, boost_credits)
SELECT id, (RANDOM() * 100)::INT
FROM public.users
WHERE email LIKE '%@deepiri.com'
ON CONFLICT (user_id) DO UPDATE SET
    boost_credits = EXCLUDED.boost_credits;

-- Add some achievements
INSERT INTO analytics.achievements (momentum_id, achievement_id, name, description, rarity, showcaseable)
SELECT m.id,
       'early_adopter',
       'Early Adopter',
       'One of the first users of Deepiri',
       'legendary',
       true
FROM analytics.momentum m
JOIN public.users u ON m.user_id = u.id
WHERE u.email LIKE '%@deepiri.local';

INSERT INTO analytics.achievements (momentum_id, achievement_id, name, description, rarity, showcaseable)
SELECT m.id,
       'first_task',
       'Getting Started',
       'Completed your first task',
       'common',
       false
FROM analytics.momentum m
JOIN public.users u ON m.user_id = u.id
WHERE u.email IN ('alice@deepiri.com', 'bob@deepiri.com');

-- ===========================
-- SEED AUDIT DATA
-- ===========================

-- Initialize user activity summary
INSERT INTO audit.user_activity_summary (user_id, last_active_at, total_tasks_completed, total_momentum_earned, active_days_count)
SELECT id,
       CURRENT_TIMESTAMP,
       (RANDOM() * 50)::INT,
       (RANDOM() * 500)::INT,
       (RANDOM() * 30)::INT
FROM public.users
WHERE email LIKE '%@deepiri.com'
ON CONFLICT (user_id) DO UPDATE SET
    last_active_at = EXCLUDED.last_active_at;

-- Add some task completions
INSERT INTO audit.task_completions (task_id, user_id, momentum_earned, time_taken_minutes, quality_rating, auto_detected)
VALUES
    ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 150, 240, 5, false);

-- ===========================
-- SEASON BOOSTS
-- ===========================

INSERT INTO public.season_boosts (season_id, name, description, boost_type, boost_multiplier, duration_minutes, cost_credits)
SELECT id,
       'Focus Mode',
       'Double momentum for 1 hour of focused work',
       'focus',
       2.0,
       60,
       50
FROM public.seasons WHERE is_active = true
UNION ALL
SELECT id,
       'Sprint Boost',
       '1.5x momentum for rapid task completion',
       'sprint',
       1.5,
       30,
       30
FROM public.seasons WHERE is_active = true
UNION ALL
SELECT id,
       'Learning Boost',
       '2.5x momentum for documentation and learning tasks',
       'learning',
       2.5,
       90,
       75
FROM public.seasons WHERE is_active = true;

-- ===========================
-- SUCCESS MESSAGE
-- ===========================

DO $$
DECLARE
    user_count INT;
    task_count INT;
    project_count INT;
BEGIN
    SELECT COUNT(*) INTO user_count FROM public.users WHERE email LIKE '%@deepiri.com';
    SELECT COUNT(*) INTO task_count FROM public.tasks;
    SELECT COUNT(*) INTO project_count FROM public.projects;
    
    RAISE NOTICE '✅ Seed data created successfully!';
    RAISE NOTICE '👥 Created % users', user_count;
    RAISE NOTICE '📋 Created % tasks', task_count;
    RAISE NOTICE '🎯 Created % projects', project_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Login credentials (all users):';
    RAISE NOTICE '  Password: password123';
    RAISE NOTICE '';
    RAISE NOTICE 'Test users:';
    RAISE NOTICE '  admin@deepiri.com - Admin User';
    RAISE NOTICE '  alice@deepiri.com - Alice Johnson (Product Manager)';
    RAISE NOTICE '  bob@deepiri.com - Bob Smith (Developer)';
    RAISE NOTICE '  carol@deepiri.com - Carol Davis (Designer)';
    RAISE NOTICE '  dave@deepiri.com - Dave Wilson (DevOps)';
END $$;

