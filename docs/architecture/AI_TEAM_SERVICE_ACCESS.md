# AI Team Service Access - Simplified

## What AI Team Needs

### ✅ API Gateway (Read-Only)
- **Why**: To call services through gateway
- **Access**: Read-only (can view routes, can't modify auth)
- **Use**: `localhost:5100/api/leases`, etc.

### ✅ API Documentation
- **Why**: To know what endpoints exist
- **Access**: README files, API docs
- **Use**: Understand request/response formats

### ❌ Service Code (NOT NEEDED)
- **Why NOT**: They're using services as a **client**
- **Example**: Like frontend team - they use APIs without backend code
- **What they don't need**:
  - `deepiri-language-intelligence-service` submodule
  - Service implementation code
  - Database schemas
  - Internal service logic

## Why This Works

**AI Team Role:**
- They're **consuming** services (calling APIs)
- Not **building** services (writing service code)
- Gateway shows them what endpoints exist
- API docs show them how to use endpoints

**Same Pattern as Frontend:**
- Frontend team uses APIs without backend code
- They just need API Gateway + docs
- AI team should be the same

## Updated Submodule List for AI Team

**Required:**
- ✅ `diri-cyrex` - Their main work
- ✅ `deepiri-api-gateway` - To call services (read-only)

**Optional:**
- `deepiri-core-api` - Legacy integration points

**Remove:**
- ❌ `deepiri-language-intelligence-service` - Not needed (use through gateway)
- ❌ `deepiri-external-bridge-service` - Not needed (unless they integrate)

## Benefits

- ✅ Less code to clone
- ✅ Simpler setup
- ✅ Clear separation (client vs service)
- ✅ Same pattern as frontend team

