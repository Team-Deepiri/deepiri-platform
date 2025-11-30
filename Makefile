# Deepiri Docker Compose Makefile
# Makes rebuilding clean and easy

.PHONY: rebuild clean build up down logs

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

