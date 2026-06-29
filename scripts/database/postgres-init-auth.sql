-- ===========================
-- DEEPIRI AUTH POSTGRESQL SETUP
-- ===========================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================
-- AUTH TABLES
-- ===========================

CREATE TABLE IF NOT EXISTS users (
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

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS role_abilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    ability VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    conditions JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, ability, resource)
);

CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE(user_id, role_id)
);

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);
CREATE INDEX IF NOT EXISTS idx_role_abilities_role_id ON role_abilities(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);

-- Seed default roles
INSERT INTO roles (name, description, is_system) VALUES
    ('admin', 'Full system administrator', true),
    ('user', 'Standard user', true),
    ('moderator', 'Content moderator', true),
    ('developer', 'Development team member', true)
ON CONFLICT (name) DO NOTHING;

-- Seed users used across segmented databases
-- Password for all seed users: "password123" (bcrypt hashed placeholder)
INSERT INTO users (id, email, password, name, bio, status, email_verified) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Admin User', 'System administrator', 'active', true),
    ('00000000-0000-0000-0000-000000000002', 'alice@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Alice Johnson', 'Product manager who loves shipping features', 'active', true),
    ('00000000-0000-0000-0000-000000000003', 'bob@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Bob Smith', 'Senior developer and code review champion', 'active', true),
    ('00000000-0000-0000-0000-000000000004', 'carol@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Carol Davis', 'UX designer focused on user experience', 'active', true),
    ('00000000-0000-0000-0000-000000000005', 'dave@deepiri.com', '$2a$10$rKJ8qD4EZFQhqvJBqC0VXO1YqQqQqQqQqQqQqQqQqQqQqQqQqQ', 'Dave Wilson', 'DevOps engineer keeping things running', 'active', true)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    bio = EXCLUDED.bio,
    status = EXCLUDED.status,
    email_verified = EXCLUDED.email_verified;

-- Assign roles to seed users
INSERT INTO user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM users u
CROSS JOIN roles r
WHERE u.email = 'admin@deepiri.com' AND r.name = 'admin'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM users u
CROSS JOIN roles r
WHERE u.email IN ('alice@deepiri.com', 'bob@deepiri.com', 'carol@deepiri.com', 'dave@deepiri.com')
AND r.name = 'user'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO user_roles (user_id, role_id, granted_by)
SELECT u.id, r.id, '00000000-0000-0000-0000-000000000001'::UUID
FROM users u
CROSS JOIN roles r
WHERE u.email IN ('bob@deepiri.com', 'dave@deepiri.com') AND r.name = 'developer'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Deepiri Auth database initialized successfully!';
END $$;
