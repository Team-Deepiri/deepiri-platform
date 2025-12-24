-- ===========================
-- DEEPIRI POSTGRESQL DATABASE SETUP
-- Complete Production-Ready Schema
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

-- Users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'deleted')),
    email_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID
);

CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_status ON public.users(status);
CREATE INDEX idx_users_created_at ON public.users(created_at DESC);
CREATE INDEX idx_users_metadata ON public.users USING GIN (metadata);

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER users_audit_log AFTER INSERT OR UPDATE OR DELETE ON public.users
    FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Roles table
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_roles_name ON public.roles(name);

CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON public.roles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Role Abilities table
CREATE TABLE IF NOT EXISTS public.role_abilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    ability VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    conditions JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, ability, resource)
);

CREATE INDEX idx_role_abilities_role_id ON public.role_abilities(role_id);
CREATE INDEX idx_role_abilities_ability ON public.role_abilities(ability);

-- User Roles table (many-to-many)
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    granted_by UUID REFERENCES public.users(id),
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE(user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX idx_user_roles_expires_at ON public.user_roles(expires_at);

-- Sessions table
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX idx_sessions_token ON public.sessions(token);
CREATE INDEX idx_sessions_expires_at ON public.sessions(expires_at);

-- ===========================
-- TASKS, QUESTS, PROJECTS
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

CREATE INDEX idx_seasons_is_active ON public.seasons(is_active);
CREATE INDEX idx_seasons_dates ON public.seasons(start_date, end_date);

CREATE TRIGGER update_seasons_updated_at BEFORE UPDATE ON public.seasons 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Projects table
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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
    updated_by UUID REFERENCES public.users(id)
);

CREATE INDEX idx_projects_owner_id ON public.projects(owner_id);
CREATE INDEX idx_projects_status ON public.projects(status);
CREATE INDEX idx_projects_priority ON public.projects(priority);
CREATE INDEX idx_projects_metadata ON public.projects USING GIN (metadata);

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
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

CREATE INDEX idx_project_milestones_project_id ON public.project_milestones(project_id);
CREATE INDEX idx_project_milestones_completed ON public.project_milestones(completed);

CREATE TRIGGER update_project_milestones_updated_at BEFORE UPDATE ON public.project_milestones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Quests table (Odysseys)
CREATE TABLE IF NOT EXISTS public.quests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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
    updated_by UUID REFERENCES public.users(id)
);

CREATE INDEX idx_quests_user_id ON public.quests(user_id);
CREATE INDEX idx_quests_season_id ON public.quests(season_id);
CREATE INDEX idx_quests_status ON public.quests(status);
CREATE INDEX idx_quests_metadata ON public.quests USING GIN (metadata);

CREATE TRIGGER update_quests_updated_at BEFORE UPDATE ON public.quests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER quests_audit_log AFTER INSERT OR UPDATE OR DELETE ON public.quests
    FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- Tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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
    updated_by UUID REFERENCES public.users(id)
);

CREATE INDEX idx_tasks_user_id ON public.tasks(user_id);
CREATE INDEX idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX idx_tasks_quest_id ON public.tasks(quest_id);
CREATE INDEX idx_tasks_parent_task_id ON public.tasks(parent_task_id);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_tasks_priority ON public.tasks(priority);
CREATE INDEX idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX idx_tasks_tags ON public.tasks USING GIN (tags);
CREATE INDEX idx_tasks_ai_suggestions ON public.tasks USING GIN (ai_suggestions);
CREATE INDEX idx_tasks_metadata ON public.tasks USING GIN (metadata);
CREATE INDEX idx_tasks_title_search ON public.tasks USING GIN (to_tsvector('english', title));

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
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

CREATE INDEX idx_subtasks_task_id ON public.subtasks(task_id);
CREATE INDEX idx_subtasks_completed ON public.subtasks(completed);
CREATE INDEX idx_subtasks_sort_order ON public.subtasks(task_id, sort_order);

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

CREATE INDEX idx_task_dependencies_task_id ON public.task_dependencies(task_id);
CREATE INDEX idx_task_dependencies_depends_on ON public.task_dependencies(depends_on_task_id);

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
    changed_by UUID REFERENCES public.users(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_id, version)
);

CREATE INDEX idx_task_versions_task_id ON public.task_versions(task_id);
CREATE INDEX idx_task_versions_version ON public.task_versions(version);

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

CREATE INDEX idx_season_boosts_season_id ON public.season_boosts(season_id);
CREATE INDEX idx_season_boosts_boost_type ON public.season_boosts(boost_type);
CREATE INDEX idx_season_boosts_is_active ON public.season_boosts(is_active);

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

CREATE INDEX idx_quest_milestones_quest_id ON public.quest_milestones(quest_id);
CREATE INDEX idx_quest_milestones_completed ON public.quest_milestones(completed);
CREATE INDEX idx_quest_milestones_sort_order ON public.quest_milestones(quest_id, sort_order);

CREATE TRIGGER update_quest_milestones_updated_at BEFORE UPDATE ON public.quest_milestones 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Rewards table
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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

CREATE INDEX idx_rewards_user_id ON public.rewards(user_id);
CREATE INDEX idx_rewards_status ON public.rewards(status);
CREATE INDEX idx_rewards_expires_at ON public.rewards(expires_at);
CREATE INDEX idx_rewards_reward_type ON public.rewards(reward_type);

CREATE TRIGGER update_rewards_updated_at BEFORE UPDATE ON public.rewards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================
-- ANALYTICS SCHEMA: GAMIFICATION
-- ===========================

-- Momentum table
CREATE TABLE IF NOT EXISTS analytics.momentum (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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

CREATE INDEX idx_momentum_user_id ON analytics.momentum(user_id);
CREATE INDEX idx_momentum_total_momentum ON analytics.momentum(total_momentum DESC);
CREATE INDEX idx_momentum_current_level ON analytics.momentum(current_level DESC);

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

CREATE INDEX idx_level_progress_momentum_id ON analytics.level_progress(momentum_id);
CREATE INDEX idx_level_progress_reached_at ON analytics.level_progress(reached_at DESC);

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

CREATE INDEX idx_achievements_momentum_id ON analytics.achievements(momentum_id);
CREATE INDEX idx_achievements_achievement_id ON analytics.achievements(achievement_id);
CREATE INDEX idx_achievements_rarity ON analytics.achievements(rarity);

-- Streaks table
CREATE TABLE IF NOT EXISTS analytics.streaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
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

CREATE INDEX idx_streaks_user_id ON analytics.streaks(user_id);
CREATE INDEX idx_streaks_daily_current ON analytics.streaks(daily_current DESC);

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

CREATE INDEX idx_cashed_in_streaks_streak_id ON analytics.cashed_in_streaks(streak_id);
CREATE INDEX idx_cashed_in_streaks_cashed_at ON analytics.cashed_in_streaks(cashed_at DESC);

-- Boosts table
CREATE TABLE IF NOT EXISTS analytics.boosts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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

CREATE INDEX idx_boosts_user_id ON analytics.boosts(user_id);

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

CREATE INDEX idx_active_boosts_boost_id ON analytics.active_boosts(boost_id);
CREATE INDEX idx_active_boosts_expires_at ON analytics.active_boosts(expires_at);
CREATE INDEX idx_active_boosts_boost_type ON analytics.active_boosts(boost_type);

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

CREATE INDEX idx_boost_history_boost_id ON analytics.boost_history(boost_id);
CREATE INDEX idx_boost_history_activated_at ON analytics.boost_history(activated_at DESC);

-- ===========================
-- AUDIT SCHEMA: ACTIVITY & LOGS
-- ===========================

-- Activity Logs table (auto-populated by triggers)
CREATE TABLE IF NOT EXISTS audit.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    user_id UUID REFERENCES public.users(id),
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_activity_logs_entity ON audit.activity_logs(entity_type, entity_id);
CREATE INDEX idx_activity_logs_user_id ON audit.activity_logs(user_id);
CREATE INDEX idx_activity_logs_action ON audit.activity_logs(action);
CREATE INDEX idx_activity_logs_created_at ON audit.activity_logs(created_at DESC);

-- Task Completions table (specific tracking)
CREATE TABLE IF NOT EXISTS audit.task_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    momentum_earned INT DEFAULT 0,
    time_taken_minutes INT,
    quality_rating INT CHECK (quality_rating >= 1 AND quality_rating <= 5),
    auto_detected BOOLEAN DEFAULT FALSE,
    completion_method VARCHAR(100),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_task_completions_task_id ON audit.task_completions(task_id);
CREATE INDEX idx_task_completions_user_id ON audit.task_completions(user_id);
CREATE INDEX idx_task_completions_completed_at ON audit.task_completions(completed_at DESC);

-- User Activity Summary (for quick lookups)
CREATE TABLE IF NOT EXISTS audit.user_activity_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    last_active_at TIMESTAMP,
    total_tasks_completed INT DEFAULT 0,
    total_momentum_earned INT DEFAULT 0,
    total_time_spent_minutes INT DEFAULT 0,
    active_days_count INT DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_activity_summary_user_id ON audit.user_activity_summary(user_id);
CREATE INDEX idx_user_activity_summary_last_active ON audit.user_activity_summary(last_active_at DESC);

CREATE TRIGGER update_user_activity_summary_updated_at BEFORE UPDATE ON audit.user_activity_summary 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================
-- INITIAL SEED DATA
-- ===========================

-- Default roles
INSERT INTO public.roles (name, description, is_system) VALUES
    ('admin', 'Full system administrator', true),
    ('user', 'Standard user', true),
    ('moderator', 'Content moderator', true),
    ('developer', 'Development team member', true)
ON CONFLICT (name) DO NOTHING;

-- Default role abilities
INSERT INTO public.role_abilities (role_id, ability, resource)
SELECT r.id, ability, resource FROM public.roles r
CROSS JOIN (VALUES
    ('admin', 'manage', 'all'),
    ('admin', 'read', 'all'),
    ('admin', 'write', 'all'),
    ('admin', 'delete', 'all'),
    ('user', 'read', 'own_data'),
    ('user', 'write', 'own_data'),
    ('moderator', 'read', 'all'),
    ('moderator', 'moderate', 'content'),
    ('developer', 'read', 'all'),
    ('developer', 'write', 'code')
) AS abilities(ability, resource)
WHERE r.name IN ('admin', 'user', 'moderator', 'developer')
ON CONFLICT (role_id, ability, resource) DO NOTHING;

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

-- Comments on tables for documentation
COMMENT ON SCHEMA public IS 'Core application data: users, tasks, projects, quests';
COMMENT ON SCHEMA analytics IS 'Gamification and engagement data: momentum, streaks, boosts';
COMMENT ON SCHEMA audit IS 'Audit logs and activity tracking';

COMMENT ON TABLE public.users IS 'User accounts and authentication';
COMMENT ON TABLE public.tasks IS 'User tasks with AI suggestions in JSONB format';
COMMENT ON TABLE public.quests IS 'User odysseys/quests with metadata in JSONB';
COMMENT ON TABLE analytics.momentum IS 'User momentum and gamification progress';
COMMENT ON TABLE analytics.streaks IS 'User streak tracking for daily, weekly, project activities';
COMMENT ON TABLE audit.activity_logs IS 'Comprehensive audit log for all entity changes';
COMMENT ON TABLE audit.task_completions IS 'Detailed task completion tracking';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Deepiri PostgreSQL database initialized successfully!';
    RAISE NOTICE '📊 Schemas: public (core), analytics (gamification), audit (logs)';
    RAISE NOTICE '🎯 Ready for production use!';
END $$;
