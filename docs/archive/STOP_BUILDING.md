# Stop Docker Compose from Building

## 🛑 Quick Fix

If Docker Compose is still building when you run `docker compose -f docker-compose.dev.yml up -d`, here's how to stop it:

### Option 1: Use `--no-build` Flag (Temporary Fix)

```bash
# Point Docker to Minikube
eval $(minikube docker-env)

# Run Docker Compose WITHOUT building
docker compose -f docker-compose.dev.yml up -d --no-build
```

This forces Docker Compose to **only use existing images** and won't build anything.

### Option 2: Build Images First (Proper Fix)

The real issue is that the images don't exist with the right names. Build them first:

```bash
# 1. Point Docker to Minikube
eval $(minikube docker-env)

# 2. Build with Skaffold using dev-compose profile
skaffold build -f skaffold-local.yaml -p dev-compose

# 3. Verify images exist
docker images | grep "deepiri-dev-"

# 4. Now Docker Compose will use them (no building!)
docker compose -f docker-compose.dev.yml up -d
```

### Option 3: Check What's Missing

```bash
# Run the check script
chmod +x scripts/check-images.sh
./scripts/check-images.sh
```

## 🔍 Why It's Still Building

Docker Compose builds when:
1. **Image doesn't exist locally** - Even with `pull_policy: build`, if the image name doesn't match exactly, it builds
2. **Image name mismatch** - Skaffold built `deepiri-api-gateway` but Docker Compose expects `deepiri-dev-api-gateway:latest`
3. **Docker daemon mismatch** - Images are in Minikube's Docker, but you're using host Docker

## ✅ Verify Everything is Set Up

```bash
# 1. Check Docker is pointing to Minikube
eval $(minikube docker-env)
docker info | grep "Docker Root Dir"  # Should show minikube path

# 2. Check images exist
docker images | grep "deepiri-dev-"

# 3. If missing, build them
skaffold build -f skaffold-local.yaml -p dev-compose

# 4. Run Docker Compose (should use images, not build)
docker compose -f docker-compose.dev.yml up -d
```

## 🚀 One-Command Solution

Use the hybrid script (it handles everything):

```bash
./scripts/build-with-skaffold-run-with-docker.sh
```

This script:
1. Points Docker to Minikube
2. Builds with `dev-compose` profile (correct names)
3. Verifies images exist
4. Runs Docker Compose (uses images, doesn't build)

