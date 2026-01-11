# AI Team API Gateway Access

## Recommendation: Give AI Team Read-Only Gateway Access

### Why?

1. **Simpler Architecture**
   - One way to access services (through gateway)
   - No need for direct port access
   - Consistent with frontend team pattern

2. **Better Security**
   - Gateway handles authentication
   - No exposed ports needed
   - Centralized access control

3. **Easier Integration**
   - AI team can test services through gateway
   - Same pattern as production
   - No special dev-only endpoints

### Access Level

**Read-Only Access:**
- ✅ Can view gateway code (understand routes)
- ✅ Can use gateway endpoints (test services)
- ❌ Cannot modify auth logic
- ❌ Cannot change routing patterns

**Same as Frontend Team:**
- Frontend team has read-only gateway access
- They use it to understand API endpoints
- AI team should have the same

### What AI Team DOESN'T Need

**They DON'T need service code:**
- ❌ `deepiri-language-intelligence-service` submodule - **NOT NEEDED**
- ❌ Service implementation code
- ❌ Database schemas
- ❌ Internal service logic

**They DO need:**
- ✅ API Gateway access (read-only)
- ✅ API documentation (endpoints, request/response formats)
- ✅ Understanding of routes (from gateway code)

**Why?**
- They're using services as a **client** (calling APIs)
- Like frontend team - they use APIs without backend code
- Gateway code shows them what endpoints exist
- API docs show them how to use endpoints

### IP Protection

**Concern:** Gateway contains proprietary routing/auth patterns (HIGH IP)

**Solution:** Read-only access
- AI team can use gateway (read)
- Cannot modify proprietary logic (write protected)
- Same protection as frontend team

### Implementation

1. **Give AI team read access to API Gateway submodule**
   - Same level as frontend team
   - Can clone, can't push to main branch

2. **Remove language-intelligence-service from AI team submodules**
   - They don't need the code
   - They just use it through gateway
   - Update `team_submodule_commands/ai-team/pull_submodules.sh`

3. **Update IP protection docs**
   - AI Team: `api-gateway` (read-only)
   - AI Team: ~~`language-intelligence-service`~~ (not needed)
   - Backend Team: `api-gateway` (full access)

4. **Update architecture**
   - AI team uses gateway (port 5100)
   - No direct port access needed
   - No service code needed
   - Simpler, more secure

### Benefits

- ✅ Simpler: One access pattern
- ✅ Secure: Gateway handles auth
- ✅ Consistent: Same as frontend
- ✅ Production-ready: Same pattern as prod
- ✅ Less code: Don't need service submodules

