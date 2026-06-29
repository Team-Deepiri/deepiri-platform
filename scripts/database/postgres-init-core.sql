-- ===========================
-- DEEPIRI CORE POSTGRESQL SETUP
-- ===========================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For indexing

-- Create schemas for logical separation
CREATE SCHEMA IF NOT EXISTS public;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- Set search path
SET search_path TO public, analytics, audit;

-- ===========================
-- TRIGGER FUNCTIONS
-- ===========================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create audit log entry
CREATE OR REPLACE FUNCTION create_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.activity_logs (
        entity_type,
        entity_id,
        action,
        old_data,
        new_data,
        user_id
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END,
        COALESCE(NEW.updated_by, OLD.updated_by, current_setting('app.current_user_id', true)::UUID)
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ language 'plpgsql';

-- ===========================
-- PUBLIC SCHEMA: CORE TABLES
-- ===========================

-- Seasons table
CREATE TABLE IF NOT EXISTS public.seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT FALSE,
    theme JSONB DEFAULT '{}',
    rewards JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seasons_is_active ON public.seasons(is_active);
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON public.seasons(start_date, end_date);

DROP TRIGGER IF EXISTS update_seasons_updated_at ON public.seasons;
CREATE TRIGGER update_seasons_updated_at BEFORE UPDATE ON public.seasons 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Projects table
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed', 'paused', 'cancelled')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    completed_at TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID
);

CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON public.projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON public.projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_priority ON public.projects(priority);
CREATE INDEX IF NOT EXISTS idx_projects_metadata ON public.projects USING GIN (metadata);

DROP TRIGGER IF EXISTS update_projects_updated_at ON public.projects;
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS projects_audit_log ON public.projects;
CREATE TRIGGER projects_audit_log AFTER INSERT OR UPDATE OR DELETE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Project Milestones table
CREATE TABLE IF NOT EXISTS public.project_milestones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date TIMESTAMP,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    momentum_reward INT DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_project_milestones_project_id ON public.project_milestones(project_id);
CREATE INDEX IF NOT EXISTS idx_project_milestones_completed ON public.project_milestones(completed);

DROP TRIGGER IF EXISTS update_project_milestones_updated_at ON public.project_milestones;
CREATE TRIGGER update_project_milestones_updated_at BEFORE UPDATE ON public.project_milestones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Quests table (Odysseys)
CREATE TABLE IF NOT EXISTS public.quests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    season_id UUID REFERENCES public.seasons(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    scale VARCHAR(50) DEFAULT 'week' CHECK (scale IN ('hours', 'day', 'week', 'month', 'custom')),
    status VARCHAR(50) DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed', 'paused', 'cancelled')),
    objectives_completed INT DEFAULT 0,
    total_objectives INT DEFAULT 0,
    progress_percentage FLOAT DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    current_stage VARCHAR(100) DEFAULT 'start',
    ai_summary TEXT,
    ai_animation VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID
);

CREATE INDEX IF NOT EXISTS idx_quests_user_id ON public.quests(user_id);
CREATE INDEX IF NOT EXISTS idx_quests_season_id ON public.quests(season_id);
CREATE INDEX IF NOT EXISTS idx_quests_status ON public.quests(status);
CREATE INDEX IF NOT EXISTS idx_quests_metadata ON public.quests USING GIN (metadata);

DROP TRIGGER IF EXISTS update_quests_updated_at ON public.quests;
CREATE TRIGGER update_quests_updated_at BEFORE UPDATE ON public.quests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS quests_audit_log ON public.quests;
CREATE TRIGGER quests_audit_log AFTER INSERT OR UPDATE OR DELETE ON public.quests
    FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    project_id UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    quest_id UUID REFERENCES public.quests(id) ON DELETE SET NULL,
    parent_task_id UUID REFERENCES public.tasks(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'blocked', 'review', 'done', 'cancelled')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    difficulty VARCHAR(50) DEFAULT 'medium' CHECK (difficulty IN ('trivial', 'easy', 'medium', 'hard', 'epic')),
    momentum_reward INT DEFAULT 0,
    estimated_minutes INT,
    actual_minutes INT,
    due_date TIMESTAMP,
    completed_at TIMESTAMP,
    ai_suggestions JSONB DEFAULT '[]',
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    version INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID
);

CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_quest_id ON public.tasks(quest_id);
CREATE INDEX IF NOT EXISTS idx_tasks_parent_task_id ON public.tasks(parent_task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON public.tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_tags ON public.tasks USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_tasks_ai_suggestions ON public.tasks USING GIN (ai_suggestions);
CREATE INDEX IF NOT EXISTS idx_tasks_metadata ON public.tasks USING GIN (metadata);
CREATE INDEX IF NOT EXISTS idx_tasks_title_search ON public.tasks USING GIN (to_tsvector('english', title));

DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS tasks_audit_log ON public.tasks;
CREATE TRIGGER tasks_audit_log AFTER INSERT OR UPDATE OR DELETE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Subtasks table
CREATE TABLE IF NOT EXISTS public.subtasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    momentum_reward INT DEFAULT 0,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_subtasks_task_id ON public.subtasks(task_id);
CREATE INDEX IF NOT EXISTS idx_subtasks_completed ON public.subtasks(completed);
CREATE INDEX IF NOT EXISTS idx_subtasks_sort_order ON public.subtasks(task_id, sort_order);

DROP TRIGGER IF EXISTS update_subtasks_updated_at ON public.subtasks;
CREATE TRIGGER update_subtasks_updated_at BEFORE UPDATE ON public.subtasks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Task Dependencies table
CREATE TABLE IF NOT EXISTS public.task_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    depends_on_task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) DEFAULT 'blocks' CHECK (dependency_type IN ('blocks', 'related', 'duplicate')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_id, depends_on_task_id)
);

CREATE INDEX IF NOT EXISTS idx_task_dependencies_task_id ON public.task_dependencies(task_id);
CREATE INDEX IF NOT EXISTS idx_task_dependencies_depends_on ON public.task_dependencies(depends_on_task_id);

-- Task Versions table (for version history)
CREATE TABLE IF NOT EXISTS public.task_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    version INT NOT NULL,
    title VARCHAR(500),
    description TEXT,
    status VARCHAR(50),
    priority VARCHAR(50),
    changes_summary TEXT,
    changed_by UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_id, version)
);

CREATE INDEX IF NOT EXISTS idx_task_versions_task_id ON public.task_versions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_versions_version ON public.task_versions(version);

-- Season Boosts table
CREATE TABLE IF NOT EXISTS public.season_boosts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    boost_type VARCHAR(100) NOT NULL,
    boost_multiplier FLOAT DEFAULT 1.0,
    duration_minutes INT,
    cost_credits INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_season_boosts_season_id ON public.season_boosts(season_id);
CREATE INDEX IF NOT EXISTS idx_season_boosts_boost_type ON public.season_boosts(boost_type);
CREATE INDEX IF NOT EXISTS idx_season_boosts_is_active ON public.season_boosts(is_active);

DROP TRIGGER IF EXISTS update_season_boosts_updated_at ON public.season_boosts;
CREATE TRIGGER update_season_boosts_updated_at BEFORE UPDATE ON public.season_boosts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Quest Milestones table
CREATE TABLE IF NOT EXISTS public.quest_milestones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quest_id UUID NOT NULL REFERENCES public.quests(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP,
    momentum_reward INT DEFAULT 0,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_quest_milestones_quest_id ON public.quest_milestones(quest_id);
CREATE INDEX IF NOT EXISTS idx_quest_milestones_completed ON public.quest_milestones(completed);
CREATE INDEX IF NOT EXISTS idx_quest_milestones_sort_order ON public.quest_milestones(quest_id, sort_order);

DROP TRIGGER IF EXISTS update_quest_milestones_updated_at ON public.quest_milestones;
CREATE TRIGGER update_quest_milestones_updated_at BEFORE UPDATE ON public.quest_milestones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Rewards table
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    reward_type VARCHAR(50) NOT NULL CHECK (reward_type IN ('boost_credits', 'momentum_bonus', 'skip_day', 'break_time', 'custom')),
    amount INT NOT NULL,
    source VARCHAR(50) NOT NULL CHECK (source IN ('streak', 'momentum', 'season', 'achievement', 'manual')),
    source_id UUID,
    description TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'claimed', 'expired')),
    claimed_at TIMESTAMP,
    expires_at TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rewards_user_id ON public.rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_rewards_status ON public.rewards(status);
CREATE INDEX IF NOT EXISTS idx_rewards_expires_at ON public.rewards(expires_at);
CREATE INDEX IF NOT EXISTS idx_rewards_reward_type ON public.rewards(reward_type);

DROP TRIGGER IF EXISTS update_rewards_updated_at ON public.rewards;
CREATE TRIGGER update_rewards_updated_at BEFORE UPDATE ON public.rewards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================
-- ANALYTICS SCHEMA: GAMIFICATION
-- ===========================

-- Momentum table
CREATE TABLE IF NOT EXISTS analytics.momentum (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    total_momentum INT DEFAULT 0 CHECK (total_momentum >= 0),
    current_level INT DEFAULT 1 CHECK (current_level >= 1),
    momentum_to_next_level INT DEFAULT 100,
    
    -- Skill mastery counters
    commits INT DEFAULT 0,
    docs INT DEFAULT 0,
    tasks INT DEFAULT 0,
    reviews INT DEFAULT 0,
    comments INT DEFAULT 0,
    attendance INT DEFAULT 0,
    features_shipped INT DEFAULT 0,
    design_edits INT DEFAULT 0,
    
    -- Public profile settings
    display_momentum BOOLEAN DEFAULT TRUE,
    showcase_achievements UUID[] DEFAULT '{}',
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_momentum_user_id ON analytics.momentum(user_id);
CREATE INDEX IF NOT EXISTS idx_momentum_total_momentum ON analytics.momentum(total_momentum DESC);
CREATE INDEX IF NOT EXISTS idx_momentum_current_level ON analytics.momentum(current_level DESC);

DROP TRIGGER IF EXISTS update_momentum_updated_at ON analytics.momentum;
CREATE TRIGGER update_momentum_updated_at BEFORE UPDATE ON analytics.momentum 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Level Progress table (history)
CREATE TABLE IF NOT EXISTS analytics.level_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    momentum_id UUID NOT NULL REFERENCES analytics.momentum(id) ON DELETE CASCADE,
    level INT NOT NULL,
    reached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_momentum_at_time INT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_level_progress_momentum_id ON analytics.level_progress(momentum_id);
CREATE INDEX IF NOT EXISTS idx_level_progress_reached_at ON analytics.level_progress(reached_at DESC);

-- Achievements table
CREATE TABLE IF NOT EXISTS analytics.achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    momentum_id UUID NOT NULL REFERENCES analytics.momentum(id) ON DELETE CASCADE,
    achievement_id VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon_url TEXT,
    rarity VARCHAR(50) DEFAULT 'common' CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    showcaseable BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_achievements_momentum_id ON analytics.achievements(momentum_id);
CREATE INDEX IF NOT EXISTS idx_achievements_achievement_id ON analytics.achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_achievements_rarity ON analytics.achievements(rarity);

-- Streaks table
CREATE TABLE IF NOT EXISTS analytics.streaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    
    -- Daily streak
    daily_current INT DEFAULT 0,
    daily_longest INT DEFAULT 0,
    daily_last_date DATE,
    daily_can_cash_in BOOLEAN DEFAULT FALSE,
    
    -- Weekly streak
    weekly_current INT DEFAULT 0,
    weekly_longest INT DEFAULT 0,
    weekly_last_week INT,
    weekly_can_cash_in BOOLEAN DEFAULT FALSE,
    
    -- Project streak
    project_current INT DEFAULT 0,
    project_longest INT DEFAULT 0,
    project_id UUID REFERENCES public.projects(id),
    project_last_date DATE,
    project_can_cash_in BOOLEAN DEFAULT FALSE,
    
    -- PR/Review streak
    pr_current INT DEFAULT 0,
    pr_longest INT DEFAULT 0,
    pr_last_date DATE,
    pr_can_cash_in BOOLEAN DEFAULT FALSE,
    
    -- Healthy/Sustainable streak
    healthy_current INT DEFAULT 0,
    healthy_longest INT DEFAULT 0,
    healthy_last_date DATE,
    healthy_can_cash_in BOOLEAN DEFAULT FALSE,
    healthy_consecutive_days_without_burnout INT DEFAULT 0,
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_streaks_user_id ON analytics.streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_streaks_daily_current ON analytics.streaks(daily_current DESC);

DROP TRIGGER IF EXISTS update_streaks_updated_at ON analytics.streaks;
CREATE TRIGGER update_streaks_updated_at BEFORE UPDATE ON analytics.streaks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Cashed In Streaks table (history)
CREATE TABLE IF NOT EXISTS analytics.cashed_in_streaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    streak_id UUID NOT NULL REFERENCES analytics.streaks(id) ON DELETE CASCADE,
    streak_type VARCHAR(50) NOT NULL,
    streak_value INT NOT NULL,
    boost_credits_earned INT DEFAULT 0,
    cashed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cashed_in_streaks_streak_id ON analytics.cashed_in_streaks(streak_id);
CREATE INDEX IF NOT EXISTS idx_cashed_in_streaks_cashed_at ON analytics.cashed_in_streaks(cashed_at DESC);

-- Boosts table
CREATE TABLE IF NOT EXISTS analytics.boosts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    boost_credits INT DEFAULT 0 CHECK (boost_credits >= 0),
    
    -- Settings
    max_concurrent_boosts INT DEFAULT 3,
    max_autopilot_time_per_day INT DEFAULT 0,
    autopilot_time_used_today INT DEFAULT 0,
    last_autopilot_reset DATE DEFAULT CURRENT_DATE,
    
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_boosts_user_id ON analytics.boosts(user_id);

DROP TRIGGER IF EXISTS update_boosts_updated_at ON analytics.boosts;
CREATE TRIGGER update_boosts_updated_at BEFORE UPDATE ON analytics.boosts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Active Boosts table
CREATE TABLE IF NOT EXISTS analytics.active_boosts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    boost_id UUID NOT NULL REFERENCES analytics.boosts(id) ON DELETE CASCADE,
    boost_type VARCHAR(100) NOT NULL,
    activated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    duration_minutes INT NOT NULL,
    multiplier FLOAT DEFAULT 1.0,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_active_boosts_boost_id ON analytics.active_boosts(boost_id);
CREATE INDEX IF NOT EXISTS idx_active_boosts_expires_at ON analytics.active_boosts(expires_at);
CREATE INDEX IF NOT EXISTS idx_active_boosts_boost_type ON analytics.active_boosts(boost_type);

-- Boost History table
CREATE TABLE IF NOT EXISTS analytics.boost_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    boost_id UUID NOT NULL REFERENCES analytics.boosts(id) ON DELETE CASCADE,
    boost_type VARCHAR(100) NOT NULL,
    activated_at TIMESTAMP NOT NULL,
    expired_at TIMESTAMP,
    duration_minutes INT NOT NULL,
    credits_used INT DEFAULT 0,
    source VARCHAR(100),
    effectiveness_score FLOAT,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_boost_history_boost_id ON analytics.boost_history(boost_id);
CREATE INDEX IF NOT EXISTS idx_boost_history_activated_at ON analytics.boost_history(activated_at DESC);

-- ===========================
-- AUDIT SCHEMA: ACTIVITY & LOGS
-- ===========================

-- Activity Logs table (auto-populated by triggers)
CREATE TABLE IF NOT EXISTS audit.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    user_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON audit.activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON audit.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON audit.activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON audit.activity_logs(created_at DESC);

-- Task Completions table (specific tracking)
CREATE TABLE IF NOT EXISTS audit.task_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    momentum_earned INT DEFAULT 0,
    time_taken_minutes INT,
    quality_rating INT CHECK (quality_rating >= 1 AND quality_rating <= 5),
    auto_detected BOOLEAN DEFAULT FALSE,
    completion_method VARCHAR(100),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_task_completions_task_id ON audit.task_completions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_user_id ON audit.task_completions(user_id);
CREATE INDEX IF NOT EXISTS idx_task_completions_completed_at ON audit.task_completions(completed_at DESC);

-- User Activity Summary (for quick lookups)
CREATE TABLE IF NOT EXISTS audit.user_activity_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    last_active_at TIMESTAMP,
    total_tasks_completed INT DEFAULT 0,
    total_momentum_earned INT DEFAULT 0,
    total_time_spent_minutes INT DEFAULT 0,
    active_days_count INT DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_activity_summary_user_id ON audit.user_activity_summary(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_summary_last_active ON audit.user_activity_summary(last_active_at DESC);

DROP TRIGGER IF EXISTS update_user_activity_summary_updated_at ON audit.user_activity_summary;
CREATE TRIGGER update_user_activity_summary_updated_at BEFORE UPDATE ON audit.user_activity_summary 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================
-- INITIAL SEED DATA
-- ===========================

-- Default season
INSERT INTO public.seasons (name, description, start_date, end_date, is_active, theme, rewards)
VALUES (
    'Season 1 - Foundation',
    'The inaugural season of Deepiri - Building momentum together',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP + INTERVAL '90 days',
    TRUE,
    '{"primary_color": "#6366f1", "secondary_color": "#8b5cf6", "icon": "rocket"}',
    '{"momentum_multiplier": 1.5, "special_badges": ["early_adopter", "founder"]}'
) ON CONFLICT DO NOTHING;

-- Seed projects
INSERT INTO public.projects (id, owner_id, name, description, status, priority, metadata) VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Deepiri Platform Launch', 'Complete platform development and launch', 'active', 'urgent', '{"category": "product", "team_size": 5}'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'API Optimization', 'Improve API performance and scalability', 'active', 'high', '{"category": "engineering", "expected_improvement": "50%"}'),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 'Design System v2', 'Create comprehensive design system', 'planning', 'medium', '{"category": "design", "components": 50}')
ON CONFLICT (id) DO UPDATE SET
    owner_id = EXCLUDED.owner_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    status = EXCLUDED.status,
    priority = EXCLUDED.priority,
    metadata = EXCLUDED.metadata;

-- Project milestones
INSERT INTO public.project_milestones (project_id, title, description, due_date, momentum_reward)
SELECT *
FROM (
    VALUES
        ('10000000-0000-0000-0000-000000000001'::UUID, 'Beta Launch', 'Launch beta version to 100 users', CURRENT_TIMESTAMP + INTERVAL '30 days', 500),
        ('10000000-0000-0000-0000-000000000001'::UUID, 'Public Launch', 'Full public launch', CURRENT_TIMESTAMP + INTERVAL '90 days', 1000),
        ('10000000-0000-0000-0000-000000000002'::UUID, 'Performance Baseline', 'Establish performance metrics', CURRENT_TIMESTAMP + INTERVAL '7 days', 200),
        ('10000000-0000-0000-0000-000000000002'::UUID, 'Optimization Complete', 'Achieve 50% improvement', CURRENT_TIMESTAMP + INTERVAL '45 days', 400)
) AS v(project_id, title, description, due_date, momentum_reward)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.project_milestones pm
    WHERE pm.project_id = v.project_id AND pm.title = v.title
);

-- Seed quests
INSERT INTO public.quests (id, user_id, season_id, title, description, status, total_objectives, metadata) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', (SELECT id FROM public.seasons WHERE is_active = true ORDER BY created_at DESC LIMIT 1), 'Ship First Feature', 'Ship the first major feature of Season 1', 'active', 5, '{"difficulty": "medium", "estimated_hours": 40}'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', (SELECT id FROM public.seasons WHERE is_active = true ORDER BY created_at DESC LIMIT 1), 'Code Review Master', 'Complete 50 code reviews with quality feedback', 'active', 50, '{"difficulty": "hard", "focus": "quality"}'),
    ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', (SELECT id FROM public.seasons WHERE is_active = true ORDER BY created_at DESC LIMIT 1), 'Design Sprint', 'Complete comprehensive design sprint', 'planning', 10, '{"difficulty": "medium", "deliverables": ["wireframes", "mockups", "prototypes"]}')
ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    season_id = EXCLUDED.season_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    status = EXCLUDED.status,
    total_objectives = EXCLUDED.total_objectives,
    metadata = EXCLUDED.metadata;

-- Seed tasks
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
    user_id = EXCLUDED.user_id,
    project_id = EXCLUDED.project_id,
    quest_id = EXCLUDED.quest_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    status = EXCLUDED.status,
    priority = EXCLUDED.priority,
    difficulty = EXCLUDED.difficulty,
    momentum_reward = EXCLUDED.momentum_reward,
    ai_suggestions = EXCLUDED.ai_suggestions,
    tags = EXCLUDED.tags,
    metadata = EXCLUDED.metadata;

-- Subtasks
INSERT INTO public.subtasks (task_id, title, completed, momentum_reward, sort_order)
SELECT *
FROM (
    VALUES
        ('30000000-0000-0000-0000-000000000001'::UUID, 'Create migration scripts', true, 30, 1),
        ('30000000-0000-0000-0000-000000000001'::UUID, 'Update docker-compose files', true, 30, 2),
        ('30000000-0000-0000-0000-000000000001'::UUID, 'Update environment variables', true, 30, 3),
        ('30000000-0000-0000-0000-000000000001'::UUID, 'Test migration', false, 30, 4),
        ('30000000-0000-0000-0000-000000000002'::UUID, 'Design auth schema', true, 20, 1),
        ('30000000-0000-0000-0000-000000000002'::UUID, 'Implement JWT generation', false, 30, 2),
        ('30000000-0000-0000-0000-000000000002'::UUID, 'Add refresh token logic', false, 30, 3)
) AS v(task_id, title, completed, momentum_reward, sort_order)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.subtasks st
    WHERE st.task_id = v.task_id AND st.title = v.title
);

-- Seed analytics: momentum, streaks, boosts
INSERT INTO analytics.momentum (user_id, total_momentum, current_level, commits, docs, tasks, features_shipped)
VALUES
    ('00000000-0000-0000-0000-000000000001', 850, 5, 22, 9, 44, 6),
    ('00000000-0000-0000-0000-000000000002', 620, 4, 16, 10, 31, 4),
    ('00000000-0000-0000-0000-000000000003', 700, 4, 28, 7, 40, 5),
    ('00000000-0000-0000-0000-000000000004', 510, 3, 9, 14, 26, 3),
    ('00000000-0000-0000-0000-000000000005', 580, 4, 18, 8, 34, 4)
ON CONFLICT (user_id) DO UPDATE SET
    total_momentum = EXCLUDED.total_momentum,
    current_level = EXCLUDED.current_level,
    commits = EXCLUDED.commits,
    docs = EXCLUDED.docs,
    tasks = EXCLUDED.tasks,
    features_shipped = EXCLUDED.features_shipped;

INSERT INTO analytics.streaks (user_id, daily_current, daily_longest, daily_last_date, weekly_current, weekly_longest)
VALUES
    ('00000000-0000-0000-0000-000000000001', 5, 19, CURRENT_DATE, 2, 7),
    ('00000000-0000-0000-0000-000000000002', 3, 11, CURRENT_DATE, 1, 5),
    ('00000000-0000-0000-0000-000000000003', 6, 21, CURRENT_DATE, 3, 8),
    ('00000000-0000-0000-0000-000000000004', 2, 9, CURRENT_DATE, 1, 4),
    ('00000000-0000-0000-0000-000000000005', 4, 14, CURRENT_DATE, 2, 6)
ON CONFLICT (user_id) DO UPDATE SET
    daily_current = EXCLUDED.daily_current,
    daily_longest = EXCLUDED.daily_longest,
    daily_last_date = EXCLUDED.daily_last_date,
    weekly_current = EXCLUDED.weekly_current,
    weekly_longest = EXCLUDED.weekly_longest;

INSERT INTO analytics.boosts (user_id, boost_credits)
VALUES
    ('00000000-0000-0000-0000-000000000001', 90),
    ('00000000-0000-0000-0000-000000000002', 40),
    ('00000000-0000-0000-0000-000000000003', 65),
    ('00000000-0000-0000-0000-000000000004', 30),
    ('00000000-0000-0000-0000-000000000005', 55)
ON CONFLICT (user_id) DO UPDATE SET
    boost_credits = EXCLUDED.boost_credits;

INSERT INTO analytics.achievements (momentum_id, achievement_id, name, description, rarity, showcaseable)
SELECT m.id, 'early_adopter', 'Early Adopter', 'One of the first users of Deepiri', 'legendary', true
FROM analytics.momentum m
WHERE m.user_id = '00000000-0000-0000-0000-000000000001'::UUID
AND NOT EXISTS (
    SELECT 1 FROM analytics.achievements a
    WHERE a.momentum_id = m.id AND a.achievement_id = 'early_adopter'
);

INSERT INTO analytics.achievements (momentum_id, achievement_id, name, description, rarity, showcaseable)
SELECT m.id, 'first_task', 'Getting Started', 'Completed your first task', 'common', false
FROM analytics.momentum m
WHERE m.user_id IN ('00000000-0000-0000-0000-000000000002'::UUID, '00000000-0000-0000-0000-000000000003'::UUID)
AND NOT EXISTS (
    SELECT 1 FROM analytics.achievements a
    WHERE a.momentum_id = m.id AND a.achievement_id = 'first_task'
);

-- Seed audit summary and completions
INSERT INTO audit.user_activity_summary (user_id, last_active_at, total_tasks_completed, total_momentum_earned, active_days_count)
VALUES
    ('00000000-0000-0000-0000-000000000001', CURRENT_TIMESTAMP, 14, 820, 20),
    ('00000000-0000-0000-0000-000000000002', CURRENT_TIMESTAMP, 11, 600, 16),
    ('00000000-0000-0000-0000-000000000003', CURRENT_TIMESTAMP, 13, 680, 18),
    ('00000000-0000-0000-0000-000000000004', CURRENT_TIMESTAMP, 8, 500, 12),
    ('00000000-0000-0000-0000-000000000005', CURRENT_TIMESTAMP, 10, 560, 15)
ON CONFLICT (user_id) DO UPDATE SET
    last_active_at = EXCLUDED.last_active_at,
    total_tasks_completed = EXCLUDED.total_tasks_completed,
    total_momentum_earned = EXCLUDED.total_momentum_earned,
    active_days_count = EXCLUDED.active_days_count;

INSERT INTO audit.task_completions (task_id, user_id, momentum_earned, time_taken_minutes, quality_rating, auto_detected)
SELECT '30000000-0000-0000-0000-000000000001'::UUID, '00000000-0000-0000-0000-000000000002'::UUID, 150, 240, 5, false
WHERE NOT EXISTS (
    SELECT 1 FROM audit.task_completions tc
    WHERE tc.task_id = '30000000-0000-0000-0000-000000000001'::UUID
    AND tc.user_id = '00000000-0000-0000-0000-000000000002'::UUID
);

-- Seed season boosts
INSERT INTO public.season_boosts (season_id, name, description, boost_type, boost_multiplier, duration_minutes, cost_credits)
SELECT id, 'Focus Mode', 'Double momentum for 1 hour of focused work', 'focus', 2.0, 60, 50
FROM public.seasons
WHERE is_active = true
AND NOT EXISTS (
    SELECT 1 FROM public.season_boosts sb WHERE sb.season_id = public.seasons.id AND sb.boost_type = 'focus'
)
UNION ALL
SELECT id, 'Sprint Boost', '1.5x momentum for rapid task completion', 'sprint', 1.5, 30, 30
FROM public.seasons
WHERE is_active = true
AND NOT EXISTS (
    SELECT 1 FROM public.season_boosts sb WHERE sb.season_id = public.seasons.id AND sb.boost_type = 'sprint'
)
UNION ALL
SELECT id, 'Learning Boost', '2.5x momentum for documentation and learning tasks', 'learning', 2.5, 90, 75
FROM public.seasons
WHERE is_active = true
AND NOT EXISTS (
    SELECT 1 FROM public.season_boosts sb WHERE sb.season_id = public.seasons.id AND sb.boost_type = 'learning'
);

-- ===========================
-- COMMENTS
-- ===========================

COMMENT ON SCHEMA public IS 'Core application data: tasks, projects, quests, seasons';
COMMENT ON SCHEMA analytics IS 'Gamification and engagement data: momentum, streaks, boosts';
COMMENT ON SCHEMA audit IS 'Audit logs and activity tracking';

COMMENT ON TABLE public.tasks IS 'User tasks with AI suggestions in JSONB format';
COMMENT ON TABLE public.quests IS 'User odysseys/quests with metadata in JSONB';
COMMENT ON TABLE analytics.momentum IS 'User momentum and gamification progress';
COMMENT ON TABLE analytics.streaks IS 'User streak tracking for daily, weekly, project activities';
COMMENT ON TABLE audit.activity_logs IS 'Comprehensive audit log for all entity changes';
COMMENT ON TABLE audit.task_completions IS 'Detailed task completion tracking';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Deepiri Core database initialized successfully!';
    RAISE NOTICE '📊 Schemas: public (core), analytics (gamification), audit (logs)';
END $$;
