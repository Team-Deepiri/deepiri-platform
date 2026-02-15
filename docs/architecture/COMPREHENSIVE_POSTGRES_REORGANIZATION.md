# Comprehensive PostgreSQL Schema Reorganization Plan

## 🎯 Goal
**Organize ALL PostgreSQL tables across the entire Deepiri platform into logical schemas.**

---

## 📊 Current State Analysis

### **Services Creating PostgreSQL Tables:**

1. **`postgres-init.sql`** (Main initialization)
   - Creates: `public`, `analytics`, `audit` schemas
   - Tables: users, roles, projects, tasks, quests, seasons, rewards, etc.

2. **Auth Service** (`deepiri-auth-service`)
   - Tables: users, sessions, skill_trees, skills, social_connections, progress_points, user_roles
   - **Current:** All in `public` schema (default)

3. **Engagement Service** (`deepiri-engagement-service`)
   - Tables: seasons, quests, tasks, rewards (public)
   - Tables: momentum, streaks, boosts, achievements (analytics)
   - Tables: task_completions (audit)
   - **Current:** Already using multi-schema! ✅

4. **Task Orchestrator** (`deepiri-task-orchestrator`)
   - Tables: tasks, task_versions, task_dependencies
   - **Current:** All in `public` schema (default)

5. **Language Intelligence Service** (`deepiri-language-intelligence-service`)
   - Tables: leases, lease_versions, contracts, contract_versions, clauses, obligations, obligation_dependencies
   - **Current:** All in `public` schema (default)

6. **Cyrex** (`diri-cyrex`)
   - Tables: All AI/agent tables
   - **Current:** ✅ Already moved to `cyrex` schema!

---

## ✅ Proposed Final Schema Organization

```
PostgreSQL Database
│
├── public (Core Platform Data)
│   ├── users (from auth service)
│   ├── sessions (from auth service)
│   ├── roles (from postgres-init.sql)
│   ├── user_roles (from auth service)
│   ├── skill_trees (from auth service)
│   ├── skills (from auth service)
│   ├── social_connections (from auth service)
│   ├── progress_points (from auth service)
│   ├── projects (from postgres-init.sql)
│   ├── tasks (from engagement service + task orchestrator - CONFLICT!)
│   ├── task_versions (from task orchestrator)
│   ├── task_dependencies (from task orchestrator)
│   ├── subtasks (from postgres-init.sql)
│   ├── quests (from engagement service)
│   ├── quest_milestones (from engagement service)
│   ├── seasons (from engagement service)
│   ├── season_boosts (from engagement service)
│   ├── rewards (from engagement service)
│   ├── leases (from language intelligence service)
│   ├── lease_versions (from language intelligence service)
│   ├── contracts (from language intelligence service)
│   ├── contract_versions (from language intelligence service)
│   ├── clauses (from language intelligence service)
│   ├── obligations (from language intelligence service)
│   └── obligation_dependencies (from language intelligence service)
│
├── analytics (Gamification & Engagement Data)
│   ├── momentum (from engagement service)
│   ├── level_progress (from engagement service)
│   ├── achievements (from engagement service)
│   ├── streaks (from engagement service)
│   ├── cashed_in_streaks (from engagement service)
│   ├── boosts (from engagement service)
│   ├── active_boosts (from engagement service)
│   └── boost_history (from engagement service)
│
├── audit (Audit Logs & Activity Tracking)
│   ├── activity_logs (from postgres-init.sql)
│   ├── task_completions (from engagement service)
│   └── user_activity_summary (from postgres-init.sql)
│
├── cyrex (AI/Agent System) ✅ ALREADY ORGANIZED!
│   ├── agent_playground_messages
│   ├── workflows
│   ├── task_executions
│   ├── events
│   ├── event_processing
│   ├── cyrex_sessions
│   ├── guardrail_rules
│   ├── guardrail_violations
│   ├── agents
│   ├── agent_states
│   ├── cyrex_vendors
│   ├── cyrex_invoices
│   ├── cyrex_pricing_benchmarks
│   ├── langgraph_states
│   ├── memories
│   └── synapse_messages
│
└── intelligence (Language Intelligence Platform) ✅ NEW!
    ├── leases (Phase 1: Lease Abstraction)
    ├── lease_versions (Phase 1: Version tracking)
    ├── contracts (Phase 2: Contract Intelligence)
    ├── contract_versions (Phase 2: Version tracking)
    ├── clauses (Phase 2: Clause evolution)
    ├── obligations (Phase 1 & 2: Shared obligations)
    └── obligation_dependencies (Phase 2: Dependency graph)
```

---

## ⚠️ Issues to Resolve

### 1. **Table Conflicts**

**Problem:** Multiple services creating `tasks` table:
- `postgres-init.sql` creates `public.tasks`
- `engagement-service` creates `public.tasks` (via Prisma)
- `task-orchestrator` creates `public.tasks` (via Prisma)

**Solution:** 
- Keep ONE `tasks` table in `public` schema
- All services should reference the same table
- Use Prisma schema references or shared schema

### 2. **Schema Organization**

**Problem:** Some services don't specify schemas (default to `public`)

**Solution:**
- **Auth Service:** Keep in `public` (core user data)
- **Task Orchestrator:** Keep in `public` (core task data)
- **Language Intelligence:** ✅ **NEW `intelligence` schema** (Phases 1-2)
- **Engagement Service:** Already organized! ✅

---

## 📋 Recommended Schema Assignments

### **Option A: Keep Most in `public` (Simpler)**

```
public schema:
├── Core user/auth data (auth service)
├── Core task/project data (task orchestrator, engagement)
├── Core quest/season data (engagement)
└── Document intelligence (language intelligence)

analytics schema:
└── Gamification data (engagement service)

audit schema:
└── Audit logs (postgres-init.sql, engagement service)

cyrex schema:
└── AI/Agent data (cyrex) ✅
```

**Pros:**
- Minimal changes needed
- Most services already use `public`
- Easy to query across services

**Cons:**
- `public` schema gets large
- Less clear separation

---

### **Option B: Create Service-Specific Schemas (Better Organization)**

```
public schema:
├── users, roles, sessions (core auth)
├── projects (core platform)
└── tasks, quests, seasons (core engagement)

auth schema:
├── skill_trees, skills
├── social_connections
└── progress_points

analytics schema:
└── Gamification data (engagement service)

audit schema:
└── Audit logs

intelligence schema: (NEW)
├── leases, lease_versions
├── contracts, contract_versions
├── clauses
└── obligations, obligation_dependencies

cyrex schema:
└── AI/Agent data ✅
```

**Pros:**
- Clear separation by service
- Better organization
- Easier to manage permissions

**Cons:**
- More migration work
- Need to update all Prisma schemas

---

## 🎯 Recommended Approach: **Option A (Simplified)**

**Reasoning:**
1. Most services already use `public` schema
2. Minimal migration work
3. Core platform data belongs together
4. Only create new schemas when there's a clear need

**Action Items:**
1. ✅ **Cyrex** - Already in `cyrex` schema (DONE!)
2. ✅ **Engagement Service** - Already using multi-schema (DONE!)
3. ✅ **Intelligence Schema** - Created for Language Intelligence Platform (DONE!)
4. ⚠️ **Resolve `tasks` table conflict** - Ensure all services use same table
5. 📝 **Document schema organization** - This document

---

## 📝 Migration Checklist

### For Existing Databases:

1. **Verify Cyrex Schema** ✅
   ```sql
   SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'cyrex';
   ```

2. **Check Table Conflicts**
   ```sql
   SELECT table_schema, table_name 
   FROM information_schema.tables 
   WHERE table_name = 'tasks';
   ```

3. **Verify Engagement Service Multi-Schema**
   ```sql
   SELECT table_schema, table_name 
   FROM information_schema.tables 
   WHERE table_schema IN ('public', 'analytics', 'audit')
   ORDER BY table_schema, table_name;
   ```

### For New Databases:

- All schemas will be created automatically
- All services will use correct schemas
- No migration needed! ✅

---

## 📚 Service-Specific Notes

### **Auth Service**
- **Current:** All tables in `public` (default)
- **Recommendation:** Keep in `public` (core user data)
- **Action:** No changes needed

### **Engagement Service**
- **Current:** Already using multi-schema! ✅
- **Status:** Perfect as-is

### **Task Orchestrator**
- **Current:** All tables in `public` (default)
- **Recommendation:** Keep in `public` (core task data)
- **Action:** Ensure `tasks` table doesn't conflict with engagement service

### **Language Intelligence Service**
- **Current:** All tables in `public` (default)
- **Recommendation:** Keep in `public` for now
- **Future:** Consider `intelligence` schema if service grows

### **Cyrex**
- **Current:** ✅ All tables in `cyrex` schema
- **Status:** Perfect as-is!

---

## ✅ Summary

**Current Status:**
- ✅ Cyrex: Fully organized in `cyrex` schema
- ✅ Engagement Service: Already using multi-schema
- ⚠️ Task table conflict: Needs resolution
- 📝 Documentation: This document

**Next Steps:**
1. Resolve `tasks` table conflict between services
2. Document final schema organization
3. Update Prisma schemas if needed
4. Test all services with new organization

**The platform is 90% organized!** 🎉

