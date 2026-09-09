# Deepiri Docker Compose Makefile
# COMPOSE_FILE: cloud portal → docker-compose.yml, control plane → docker-compose.dev.yml

COMPOSE_FILE ?= $(shell if grep -q postgres-platform docker-compose.yml 2>/dev/null; then echo docker-compose.yml; else echo docker-compose.dev.yml; fi)

.PHONY: rebuild clean build up down logs health heal rtg-up rtg-down rtg-up-v3-freeze rtg-rollout-v3-freeze rtg-logs rtg-health rtg-heal rtg-watchdog rtg-preflight rtg-smoke rtg-grpc-smoke rtg-failure rtg-gate rtg-gate-full rtg-sugar-up rtg-sugar-down rtg-sugar-logs rtg-sugar-health rtg-sugar-heal rtg-sugar-watchdog rtg-sugar-preflight rtg-sugar-smoke rtg-sugar-grpc-smoke rtg-sugar-failure rtg-sugar-gate rtg-sugar-gate-full

RTG_SUGAR_COMPOSE_FILE := docker-compose.rtg-sugar-glider.local.yml
RTG_LEGACY_COMPOSE_FILE := docker-compose.rtg-sidecar.local.yml
RTG_COMPOSE_FILE ?= $(if $(wildcard $(RTG_SUGAR_COMPOSE_FILE)),$(RTG_SUGAR_COMPOSE_FILE),$(RTG_LEGACY_COMPOSE_FILE))
RTG_V3_FREEZE_ENV := STREAM_TRANSPORT=sugar-glider-grpc STREAM_SHADOW_MODE=false SIDECAR_PUBLISH_PIPELINE_ENABLED=false SIDECAR_PUBLISH_PIPELINE_ADAPTIVE_ENABLED=false SIDECAR_PUBLISH_PIPELINE_MIN_BATCH=2 SIDECAR_PUBLISH_PIPELINE_MAX_BATCH=64 SIDECAR_PUBLISH_PIPELINE_FLUSH_MS=0 SIDECAR_PUBLISH_PIPELINE_QUEUE_SIZE=8192 SIDECAR_PUBLISH_PIPELINE_MAX_BYTES=1048576
SUGAR_GLIDER_URL ?= http://localhost:8081
SUGAR_GLIDER_GRPC_ADDR ?= localhost:50051
# Legacy env var compatibility
SIDECAR_URL ?= $(SUGAR_GLIDER_URL)
SIDECAR_GRPC_ADDR ?= $(SUGAR_GLIDER_GRPC_ADDR)

# Clean rebuild - removes old images first (ONLY use when rebuilding needed)
# Detects WSL and uses docker.exe/docker-compose.exe if needed
rebuild:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		echo "🔍 WSL detected - using docker.exe and docker-compose.exe"; \
		echo "🧹 Cleaning old images..."; \
		docker-compose.exe -f $(COMPOSE_FILE) down --rmi local; \
		docker.exe builder prune -af; \
		echo "🔨 Rebuilding..."; \
		docker-compose.exe -f $(COMPOSE_FILE) build --no-cache; \
		echo "✅ Rebuild complete!"; \
	else \
		echo "🧹 Cleaning old images..."; \
		docker compose -f $(COMPOSE_FILE) down --rmi local; \
		docker builder prune -af; \
		echo "🔨 Rebuilding..."; \
		docker compose -f $(COMPOSE_FILE) build --no-cache; \
		echo "✅ Rebuild complete!"; \
	fi

# Clean rebuild specific service (ONLY use when rebuilding needed)
rebuild-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make rebuild-service SERVICE=cyrex"; \
		exit 1; \
	fi
	@echo "🧹 Cleaning old image for $(SERVICE)..."
	docker compose -f $(COMPOSE_FILE) rm -f -s -v $(SERVICE) 2>/dev/null || true
	docker rmi deepiri-dev-$(SERVICE):latest 2>/dev/null || true
	docker builder prune -af
	@echo "🔨 Rebuilding $(SERVICE)..."
	docker compose -f $(COMPOSE_FILE) build --no-cache $(SERVICE)
	@echo "✅ Rebuild complete!"

# Clean everything (removes containers, images, volumes, cache)
clean:
	@echo "🧹 Cleaning Docker resources..."
	docker compose -f $(COMPOSE_FILE) down --rmi local -v
	docker builder prune -af
	docker image prune -f
	@echo "✅ Clean complete!"

# Build (normal, with cache) - only rebuilds if needed
build:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(COMPOSE_FILE) build; \
	else \
		docker compose -f $(COMPOSE_FILE) build; \
	fi

# Up (normal start - uses existing images, NO rebuild)
up:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(COMPOSE_FILE) up -d; \
	else \
		docker compose -f $(COMPOSE_FILE) up -d; \
	fi

# Down
down:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(COMPOSE_FILE) down; \
	else \
		docker compose -f $(COMPOSE_FILE) down; \
	fi

# Logs
logs:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(COMPOSE_FILE) logs -f; \
	else \
		docker compose -f $(COMPOSE_FILE) logs -f; \
	fi

# Show disk usage
df:
	docker system df

# Health check for default dev stack
health:
	@echo "🩺 Checking $(COMPOSE_FILE) service health..."
	@set -e; \
	services=$$(docker compose -f $(COMPOSE_FILE) ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No $(COMPOSE_FILE) services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f $(COMPOSE_FILE) ps -q $$svc); \
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
	@echo "🛠️ Healing $(COMPOSE_FILE) services (if needed)..."
	@set -e; \
	actions=0; \
	services=$$(docker compose -f $(COMPOSE_FILE) ps --services 2>/dev/null || true); \
	if [ -z "$$services" ]; then \
		echo "No $(COMPOSE_FILE) services are currently running."; \
		exit 0; \
	fi; \
	for svc in $$services; do \
		cid=$$(docker compose -f $(COMPOSE_FILE) ps -q $$svc); \
		if [ -z "$$cid" ]; then \
			echo "↻ $$svc is missing, recreating..."; \
			docker compose -f $(COMPOSE_FILE) up -d $$svc; \
			actions=$$((actions+1)); \
			continue; \
		fi; \
		state=$$(docker inspect -f '{{.State.Status}}' $$cid 2>/dev/null || echo unknown); \
		health=$$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $$cid 2>/dev/null || echo unknown); \
		if [ "$$state" != "running" ] || [ "$$health" = "unhealthy" ]; then \
			echo "↻ restarting $$svc (state=$$state health=$$health)"; \
			docker compose -f $(COMPOSE_FILE) restart $$svc || docker compose -f $(COMPOSE_FILE) up -d $$svc; \
			actions=$$((actions+1)); \
		fi; \
	done; \
	if [ "$$actions" -eq 0 ]; then echo "✅ No healing actions needed."; else echo "✅ Applied $$actions healing action(s)."; fi

# Sugar Glider local stack (fast path for transport rollout work)
rtg-up:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		docker-compose.exe -f $(RTG_COMPOSE_FILE) up -d; \
	else \
		docker compose -f $(RTG_COMPOSE_FILE) up -d; \
	fi

rtg-up-v3-freeze:
	@$(RTG_V3_FREEZE_ENV) $(MAKE) rtg-up

rtg-rollout-v3-freeze:
	@if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -n "$$WSL_DISTRO_NAME" ]; then \
		$(RTG_V3_FREEZE_ENV) docker-compose.exe -f $(RTG_COMPOSE_FILE) up -d --force-recreate realtime-gateway synapse-sugar-glider; \
	else \
		$(RTG_V3_FREEZE_ENV) docker compose -f $(RTG_COMPOSE_FILE) up -d --force-recreate realtime-gateway synapse-sugar-glider; \
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
	@./scripts/dev/sugarglider/stack_watchdog.sh --file $(RTG_COMPOSE_FILE) $(WATCHDOG_ARGS)

rtg-preflight:
	@./scripts/dev/sugarglider/preflight.sh --file $(RTG_COMPOSE_FILE) $(PREFLIGHT_ARGS)

rtg-smoke:
	@./scripts/dev/sugarglider/sugar_glider_smoke_test.sh --url $(SUGAR_GLIDER_URL) $(SMOKE_ARGS)

rtg-grpc-smoke:
	@./scripts/dev/sugarglider/sugar_glider_grpc_smoke_test.sh --addr $(SUGAR_GLIDER_GRPC_ADDR) $(GRPC_SMOKE_ARGS)

rtg-failure:
	@./scripts/dev/sugarglider/sugar_glider_failure_test.sh --file $(RTG_COMPOSE_FILE) --url $(SUGAR_GLIDER_URL) $(FAILURE_ARGS)

rtg-gate:
	@set -e; \
	echo "🚀 Running RTG Sugar Glider gate (fast)..."; \
	SMOKE_GROUP="sugar-glider-smoke-tail-$$(date +%s)"; \
	GRPC_GROUP="sugar-glider-grpc-smoke-tail-$$(date +%s)"; \
	$(MAKE) rtg-up; \
	$(MAKE) rtg-preflight; \
	$(MAKE) rtg-health; \
	docker compose -f $(RTG_COMPOSE_FILE) exec -T redis redis-cli -a redispassword XGROUP CREATE platform-events "$$SMOKE_GROUP" '$$' MKSTREAM >/dev/null || true; \
	docker compose -f $(RTG_COMPOSE_FILE) exec -T redis redis-cli -a redispassword XGROUP CREATE platform-events "$$GRPC_GROUP" '$$' MKSTREAM >/dev/null || true; \
	$(MAKE) rtg-smoke SMOKE_ARGS="--group $$SMOKE_GROUP"; \
	$(MAKE) rtg-grpc-smoke GRPC_SMOKE_ARGS="--group $$GRPC_GROUP"; \
	echo "✅ RTG Sugar Glider gate passed."

rtg-gate-full:
	@set -e; \
	echo "🚀 Running RTG Sugar Glider gate (full)..."; \
	$(MAKE) rtg-gate; \
	$(MAKE) rtg-failure; \
	echo "✅ RTG Sugar Glider full gate passed."

# Sugar Glider naming aliases (legacy rtg-* targets remain supported)
rtg-sugar-up: rtg-up

rtg-sugar-down: rtg-down

rtg-sugar-logs: rtg-logs

rtg-sugar-health: rtg-health

rtg-sugar-heal: rtg-heal

rtg-sugar-watchdog: rtg-watchdog

rtg-sugar-preflight: rtg-preflight

rtg-sugar-smoke: rtg-smoke

rtg-sugar-grpc-smoke: rtg-grpc-smoke

rtg-sugar-failure: rtg-failure

rtg-sugar-gate: rtg-gate

rtg-sugar-gate-full: rtg-gate-full
