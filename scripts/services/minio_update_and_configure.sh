#!/bin/bash
# MinIO Update and Configuration Script
# This script updates MinIO to the latest version and configures proper parity settings
# to prevent data loss

set -e

echo "🔒 MinIO Security Update and Configuration Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MINIO_CONTAINER_NAME="${MINIO_CONTAINER_NAME:-deepiri-minio-dev}"
MINIO_ALIAS="${MINIO_ALIAS:-myminio}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"

# Check if running in Docker
if command -v docker &> /dev/null; then
    USE_DOCKER=true
else
    USE_DOCKER=false
fi

echo "📋 Configuration:"
echo "   Container: $MINIO_CONTAINER_NAME"
echo "   Endpoint: $MINIO_ENDPOINT"
echo "   Alias: $MINIO_ALIAS"
echo ""

# Step 1: Backup existing data
echo "📦 Step 1: Creating backup..."
if [ "$USE_DOCKER" = true ]; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${MINIO_CONTAINER_NAME}$"; then
        echo -e "${YELLOW}⚠️  Creating backup of MinIO data...${NC}"
        BACKUP_DIR="./minio_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Get volume name
        VOLUME_NAME=$(docker inspect ${MINIO_CONTAINER_NAME} --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || echo "")
        
        if [ -n "$VOLUME_NAME" ]; then
            echo "   Backing up volume: $VOLUME_NAME"
            docker run --rm -v "$VOLUME_NAME":/data -v "$(pwd)/$BACKUP_DIR":/backup \
                alpine tar czf /backup/minio_data_backup.tar.gz -C /data .
            echo -e "${GREEN}✅ Backup created at: $BACKUP_DIR/minio_data_backup.tar.gz${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not determine volume name. Please backup manually.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Container not found. Skipping backup.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker not available. Please backup MinIO data manually.${NC}"
fi

echo ""

# Step 2: Check current MinIO version
echo "🔍 Step 2: Checking current MinIO version..."
if [ "$USE_DOCKER" = true ]; then
    if docker ps --format '{{.Names}}' | grep -q "^${MINIO_CONTAINER_NAME}$"; then
        CURRENT_VERSION=$(docker exec ${MINIO_CONTAINER_NAME} minio --version 2>/dev/null | head -1 || echo "Unknown")
        echo "   Current version: $CURRENT_VERSION"
    else
        echo -e "${YELLOW}⚠️  MinIO container is not running.${NC}"
    fi
fi

echo ""

# Step 3: Update MinIO
echo "🔄 Step 3: Updating MinIO to latest version..."
if [ "$USE_DOCKER" = true ]; then
    echo "   Pulling latest MinIO image..."
    docker pull minio/minio:latest
    
    echo "   Stopping current container..."
    docker stop ${MINIO_CONTAINER_NAME} 2>/dev/null || true
    
    echo "   Starting updated container..."
    # Note: The container will be started by docker-compose, but we can verify
    echo -e "${GREEN}✅ MinIO image updated. Restart with: docker compose up -d minio${NC}"
else
    echo -e "${YELLOW}⚠️  Docker not available. Please update MinIO manually.${NC}"
fi

echo ""

# Step 4: Wait for MinIO to be ready
echo "⏳ Step 4: Waiting for MinIO to be ready..."
if [ "$USE_DOCKER" = true ]; then
    MAX_WAIT=60
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if docker exec ${MINIO_CONTAINER_NAME} curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; then
            echo -e "${GREEN}✅ MinIO is ready!${NC}"
            break
        fi
        echo -n "."
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo -e "${RED}❌ MinIO did not become ready within $MAX_WAIT seconds${NC}"
        exit 1
    fi
fi

echo ""

# Step 5: Configure MinIO client
echo "🔧 Step 5: Configuring MinIO client..."
if ! command -v mc &> /dev/null; then
    echo -e "${YELLOW}⚠️  MinIO client (mc) not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /tmp/mc
        chmod +x /tmp/mc
        MC_CMD="/tmp/mc"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install minio/stable/mc
            MC_CMD="mc"
        else
            echo -e "${RED}❌ Please install MinIO client manually: https://min.io/docs/minio/linux/reference/minio-mc.html${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Please install MinIO client manually: https://min.io/docs/minio/linux/reference/minio-mc.html${NC}"
        exit 1
    fi
else
    MC_CMD="mc"
fi

# Configure alias
echo "   Configuring MinIO alias..."
$MC_CMD alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} 2>/dev/null || \
    $MC_CMD alias remove ${MINIO_ALIAS} 2>/dev/null; \
    $MC_CMD alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}

echo ""

# Step 6: Check current parity settings
echo "🔍 Step 6: Checking current parity settings..."
CURRENT_PARITY=$($MC_CMD admin config get ${MINIO_ALIAS} storage_class 2>/dev/null | grep -oP 'standard=EC:\K\d+' || echo "0")
echo "   Current parity: $CURRENT_PARITY"

if [ "$CURRENT_PARITY" = "0" ]; then
    echo -e "${RED}❌ CRITICAL: Parity is set to 0 - NO DATA REDUNDANCY!${NC}"
    echo ""
    
    # Step 7: Set proper parity
    echo "🔒 Step 7: Setting proper parity for data protection..."
    echo "   Setting parity to EC:2 (can survive 2 disk failures)..."
    
    # For single-node MinIO, we need to use erasure coding with multiple drives
    # Since we're using /data as a single mount, we'll configure it for erasure coding
    # Note: For production, you should use multiple drives/disks
    
    $MC_CMD admin config set ${MINIO_ALIAS} storage_class standard=EC:2 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Could not set parity via config. This may require multiple drives.${NC}"
        echo "   For single-drive setups, consider:"
        echo "   1. Using multiple volumes/drives"
        echo "   2. Setting up MinIO in distributed mode"
        echo "   3. Implementing external backups"
    }
    
    echo ""
    echo "   Restarting MinIO to apply changes..."
    if [ "$USE_DOCKER" = true ]; then
        docker restart ${MINIO_CONTAINER_NAME} 2>/dev/null || true
        sleep 5
    fi
    
    # Verify parity was set
    NEW_PARITY=$($MC_CMD admin config get ${MINIO_ALIAS} storage_class 2>/dev/null | grep -oP 'standard=EC:\K\d+' || echo "0")
    if [ "$NEW_PARITY" != "0" ]; then
        echo -e "${GREEN}✅ Parity updated to: EC:$NEW_PARITY${NC}"
    else
        echo -e "${YELLOW}⚠️  Parity may require multiple drives. Current setup may not support EC.${NC}"
    fi
else
    echo -e "${GREEN}✅ Parity is already configured: EC:$CURRENT_PARITY${NC}"
fi

echo ""

# Step 8: Health check
echo "🏥 Step 8: Running health check..."
if [ "$USE_DOCKER" = true ]; then
    if docker exec ${MINIO_CONTAINER_NAME} curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MinIO health check passed${NC}"
    else
        echo -e "${RED}❌ MinIO health check failed${NC}"
    fi
fi

# Get MinIO info
echo ""
echo "📊 MinIO Information:"
$MC_CMD admin info ${MINIO_ALIAS} 2>/dev/null || echo "   Could not retrieve info"

echo ""
echo "=================================================="
echo -e "${GREEN}✅ MinIO update and configuration complete!${NC}"
echo ""
echo "📋 Next Steps:"
echo "   1. Verify your data is accessible"
echo "   2. Test MinIO operations"
echo "   3. Set up regular backups"
echo "   4. Monitor MinIO logs: docker logs ${MINIO_CONTAINER_NAME}"
echo ""
echo "🔒 Security Recommendations:"
echo "   1. Change default credentials (MINIO_ACCESS_KEY, MINIO_SECRET_KEY)"
echo "   2. Enable TLS/SSL for production"
echo "   3. Set up access policies"
echo "   4. Enable audit logging"
echo ""
echo "📚 Documentation: https://min.io/docs"
echo ""

