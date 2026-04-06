# Deepiri Docker Compose Makefile
# Makes rebuilding clean and easy

.PHONY: rebuild clean build up down logs health heal rtg-up rtg-down rtg-logs rtg-health rtg-heal rtg-watchdog rtg-preflight rtg-smoke rtg-grpc-smoke rtg-failure rtg-gate rtg-gate-full

RTG_COMPOSE_FILE := docker-compose.rtg-sidecar.local.yml
SIDECAR_URL ?= http://localhost:8081
SIDECAR_GRPC_ADDR ?= localhost:50051

# Clean rebuild - removes old images first (ONLY use when rebuilding needed)
# Detects WSL and uses docker.exe/docker-compose.exe if needed
rebuild:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		echo "🔍 WSL detected - using docker.exe and docker-compose.exe"; \
		echo "🧹 Cleaning old images..."; \
		docker-compose.exe -f docker-compose.dev.yml down --rmi local; \
		docker.exe builder prune -af; \
		echo "🔨 Rebuilding..."; \
		docker-compose.exe -f docker-compose.dev.yml build --no-cache; \
		echo "✅ Rebuild complete!"; \
	else \
		echo "🧹 Cleaning old images..."; \
		docker compose -f docker-compose.dev.yml down --rmi local; \
		docker builder prune -af; \
		echo "🔨 Rebuilding..."; \
		docker compose -f docker-compose.dev.yml build --no-cache; \
		echo "✅ Rebuild complete!"; \
	fi

# Clean rebuild specific service (ONLY use when rebuilding needed)
rebuild-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make rebuild-service SERVICE=cyrex"; \
		exit 1; \
	fi
	@echo "🧹 Cleaning old image for $(SERVICE)..."
	docker compose -f docker-compose.dev.yml rm -f -s -v $(SERVICE) 2>/dev/null || true
	docker rmi deepiri-dev-$(SERVICE):latest 2>/dev/null || true
	docker builder prune -af
	@echo "🔨 Rebuilding $(SERVICE)..."
	docker compose -f docker-compose.dev.yml build --no-cache $(SERVICE)
	@echo "✅ Rebuild complete!"

# Clean everything (removes containers, images, volumes, cache)
clean:
	@echo "🧹 Cleaning Docker resources..."
	docker compose -f docker-compose.dev.yml down --rmi local -v
	docker builder prune -af
	docker image prune -f
	@echo "✅ Clean complete!"

# Build (normal, with cache) - only rebuilds if needed
build:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f docker-compose.dev.yml build; \
	else \
		docker compose -f docker-compose.dev.yml build; \
	fi

# Up (normal start - uses existing images, NO rebuild)
up:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f docker-compose.dev.yml up -d; \
	else \
		docker compose -f docker-compose.dev.yml up -d; \
	fi

# Down
down:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f docker-compose.dev.yml down; \
	else \
		docker compose -f docker-compose.dev.yml down; \
	fi

# Logs
logs:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f docker-compose.dev.yml logs -f; \
	else \
		docker compose -f docker-compose.dev.yml logs -f; \
	fi

# Show disk usage
df:
	docker system df

# Health check for default dev stack
health:
	@echo "🩺 Checking docker-compose.dev.yml service health..."
	@set -e; \
	services=$$(docker compose -f docker-compose.dev.yml ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No docker-compose.dev.yml services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f docker-compose.dev.yml ps -q $$svc); \
		if [ -z "$$cid" ]; then \
			printf "%-24s state=%-10s health=%s\n" "$$svc" "missing" "n/a"; \
			continue; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null || echo unknown); \
		health=$$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $$cid 2>/dev/null || echo unknown); \
		printf "%-24s state=%-10s health=%s\n" "$$svc" "$$state" "$$health"; \
	done

# Heal default dev stack by restarting non-running or unhealthy services
heal:
	@echo "🛠️ Healing docker-compose.dev.yml services (if needed)..."
	@set -e; \
	actions=0; \
	services=$$(docker compose -f docker-compose.dev.yml ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No docker-compose.dev.yml services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f docker-compose.dev.yml ps -q $$svc); \
		if [ -z "$$cid" ]; then \
			echo "↻ $$svc is missing, recreating..."; \
			docker compose -f docker-compose.dev.yml up -d $$svc; \
			actions=$$((actions+1)); \
			continue; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null || echo unknown); \
		health=$$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $$cid 2>/dev/null || echo unknown); \
		if [ "$$state" != "running" ] || [ "$$health" = "unhealthy" ]; then \
			echo "↻ restarting $$svc (state=$$state health=$$health)"; \
			docker compose -f docker-compose.dev.yml restart $$svc || docker compose -f docker-compose.dev.yml up -d $$svc; \
			actions=$$((actions+1)); \
		fi; \
	done; \
	if [ "$$actions" -eq 0 ]; then echo "✅ No healing actions needed."; else echo "✅ Applied $$actions healing action(s)."; fi

# Sidecar local stack (fast path for sidecar rollout work)
rtg-up:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(RTG_COMPOSE_FILE) up -d; \
	else \
		docker compose -f $(RTG_COMPOSE_FILE) up -d; \
	fi

rtg-down:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(RTG_COMPOSE_FILE) down; \
	else \
		docker compose -f $(RTG_COMPOSE_FILE) down; \
	fi

rtg-logs:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(RTG_COMPOSE_FILE) logs -f --tail=200 $(SERVICE); \
	else \
		docker compose -f $(RTG_COMPOSE_FILE) logs -f --tail=200 $(SERVICE); \
	fi

rtg-health:
	@echo "🩺 Checking $(RTG_COMPOSE_FILE) service health..."
	@set -e; \
	services=$$(docker compose -f $(RTG_COMPOSE_FILE) ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No $(RTG_COMPOSE_FILE) services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f $(RTG_COMPOSE_FILE) ps -q $$svc); \
		if [ -z "$$cid" ]; then \
			printf "%-24s state=%-10s health=%s\n" "$$svc" "missing" "n/a"; \
			continue; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null || echo unknown); \
		health=$$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $$cid 2>/dev/null || echo unknown); \
		printf "%-24s state=%-10s health=%s\n" "$$svc" "$$state" "$$health"; \
	done

rtg-heal:
	@echo "🛠️ Healing $(RTG_COMPOSE_FILE) services (if needed)..."
	@set -e; \
	actions=0; \
	services=$$(docker compose -f $(RTG_COMPOSE_FILE) ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No $(RTG_COMPOSE_FILE) services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f $(RTG_COMPOSE_FILE) ps -q $$svc); \
		if [ -z "$$cid" ]; then \
			echo "↻ $$svc is missing, recreating..."; \
			docker compose -f $(RTG_COMPOSE_FILE) up -d $$svc; \
			actions=$$((actions+1)); \
			continue; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null || echo unknown); \
		health=$$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $$cid 2>/dev/null || echo unknown); \
		if [ "$$state" != "running" ] || [ "$$health" = "unhealthy" ]; then \
			echo "↻ restarting $$svc (state=$$state health=$$health)"; \
			docker compose -f $(RTG_COMPOSE_FILE) restart $$svc || docker compose -f $(RTG_COMPOSE_FILE) up -d $$svc; \
			actions=$$((actions+1)); \
		fi; \
	done; \
	if [ "$$actions" -eq 0 ]; then echo "✅ No healing actions needed."; else echo "✅ Applied $$actions healing action(s)."; fi

rtg-watchdog:
	@./scripts/dev/stack_watchdog.sh --file $(RTG_COMPOSE_FILE) $(WATCHDOG_ARGS)

rtg-preflight:
	@./scripts/dev/preflight.sh --file $(RTG_COMPOSE_FILE) $(PREFLIGHT_ARGS)

rtg-smoke:
	@./scripts/dev/sidecar_smoke_test.sh --url $(SIDECAR_URL) $(SMOKE_ARGS)

rtg-grpc-smoke:
	@./scripts/dev/sidecar_grpc_smoke_test.sh --addr $(SIDECAR_GRPC_ADDR) $(GRPC_SMOKE_ARGS)

rtg-failure:
	@./scripts/dev/sidecar_failure_test.sh --file $(RTG_COMPOSE_FILE) --url $(SIDECAR_URL) $(FAILURE_ARGS)

rtg-gate:
	@set -e; \
	echo "🚀 Running RTG sidecar gate (fast)..."; \
	$(MAKE) rtg-up; \
	$(MAKE) rtg-preflight; \
	$(MAKE) rtg-health; \
	$(MAKE) rtg-smoke; \
	$(MAKE) rtg-grpc-smoke; \
	echo "✅ RTG sidecar gate passed."

rtg-gate-full:
	@set -e; \
	echo "🚀 Running RTG sidecar gate (full)..."; \
	$(MAKE) rtg-gate; \
	$(MAKE) rtg-failure; \
	echo "✅ RTG sidecar full gate passed."
