# QA Team Environment Troubleshooting

## Frontend Not Loading on localhost:5173

### Common Issues and Solutions

#### 1. Frontend Image Not Built

**Symptom:** Container shows as "recreated" but page doesn't load.

**Solution:**
```bash
# Build the frontend image first
cd ../..
./team_dev_environments/qa-team/build.sh

# Or build just the frontend
docker compose -f docker-compose.dev.yml build frontend-dev

# Then start
./team_dev_environments/qa-team/start.sh
```

#### 2. Container Not Running

**Check container status:**
```bash
docker ps -a | grep frontend
```

**If container is stopped or exited:**
```bash
# Check logs
docker compose -f docker-compose.dev.yml logs frontend-dev

# Restart the container
docker compose -f docker-compose.dev.yml restart frontend-dev

# Or start it fresh
docker compose -f docker-compose.dev.yml up -d frontend-dev
```

#### 3. Port Already in Use

**Check if port 5173 is already in use:**
```bash
# On Linux/WSL
lsof -i :5173
# or
netstat -tulpn | grep 5173

# Kill the process if needed
kill -9 <PID>
```

#### 4. Dependencies Not Ready

**The frontend depends on `synapse` service. Check if it's running:**
```bash
docker ps | grep synapse

# If not running, start it
docker compose -f docker-compose.dev.yml up -d synapse

# Wait a few seconds, then start frontend
docker compose -f docker-compose.dev.yml up -d frontend-dev
```

#### 5. Node Modules Not Installed

**If the container starts but Vite fails, node_modules might be missing:**
```bash
# Enter the container
docker exec -it deepiri-frontend-dev sh

# Inside container, reinstall dependencies
npm install --legacy-peer-deps

# Exit and restart
exit
docker compose -f docker-compose.dev.yml restart frontend-dev
```

#### 6. Check Container Logs

**View real-time logs:**
```bash
docker compose -f docker-compose.dev.yml logs -f frontend-dev
```

**Look for errors like:**
- "Cannot find module" - dependencies issue
- "Port already in use" - port conflict
- "ECONNREFUSED" - dependency service not ready
- "EADDRINUSE" - port conflict

#### 7. Verify Vite Server is Running

**Check if Vite is listening on port 5173 inside the container:**
```bash
docker exec deepiri-frontend-dev netstat -tulpn | grep 5173
# or
docker exec deepiri-frontend-dev ps aux | grep vite
```

#### 8. Network Issues

**Verify the container is on the correct network:**
```bash
docker inspect deepiri-frontend-dev | grep -A 10 Networks
```

**Should show `deepiri-dev-network`**

#### 9. Volume Mount Issues

**Check if the frontend code is properly mounted:**
```bash
docker exec deepiri-frontend-dev ls -la /app
```

**Should show your frontend files. If empty or missing:**
- Check the volume mount in `docker-compose.dev.yml`
- Verify the path `./deepiri-web-frontend` exists relative to project root

#### 10. Complete Reset

**If nothing works, do a complete reset:**
```bash
# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Remove the frontend image (optional, forces rebuild)
docker rmi deepiri-dev-frontend:latest

# Rebuild
cd team_dev_environments/qa-team
./build.sh

# Start fresh
./start.sh
```

## Quick Diagnostic Commands

```bash
# 1. Check if container exists and is running
docker ps -a | grep frontend

# 2. Check container logs
docker compose -f docker-compose.dev.yml logs --tail=50 frontend-dev

# 3. Check if port is accessible from host
curl http://localhost:5173

# 4. Check if Vite is running inside container
docker exec deepiri-frontend-dev ps aux | grep node

# 5. Check network connectivity
docker exec deepiri-frontend-dev ping -c 2 synapse

# 6. Check environment variables
docker exec deepiri-frontend-dev env | grep VITE
```

## Expected Behavior

When working correctly:
1. Container should show as "Up" in `docker ps`
2. Logs should show: `VITE vX.X.X ready in XXX ms`
3. Logs should show: `➜  Local:   http://localhost:5173/`
4. `curl http://localhost:5173` should return HTML
5. Browser should load the page at `http://localhost:5173`

## Still Not Working?

1. Check the updated `start.sh` script - it now includes:
   - Automatic image building if missing
   - Proper dependency ordering
   - Status checks and log output

2. Run the diagnostic commands above and share the output

3. Check if other services are working (API Gateway, etc.) to isolate the issue

