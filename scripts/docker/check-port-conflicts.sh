#!/bin/bash
# Check and resolve port conflicts for Docker services
# Usage: ./check-port-conflicts.sh [--kill]

KILL_PROCESSES=false

if [ "$1" = "--kill" ] || [ "$1" = "-k" ]; then
    KILL_PROCESSES=true
fi

echo "=========================================="
echo "Docker Port Conflict Checker"
echo "=========================================="
echo ""

# Function to check if port is in use
check_port() {
    local port=$1
    local service=$2
    
    if command -v lsof >/dev/null 2>&1; then
        # macOS/Linux with lsof
        local result=$(lsof -i :$port 2>/dev/null)
        if [ -n "$result" ]; then
            local pid=$(echo "$result" | awk 'NR==2 {print $2}')
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "Unknown")
            echo "⚠️  Port $port ($service) is in use"
            echo "    Process: $process (PID: $pid)"
            echo "$port|$service|$pid|$process"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # Linux with netstat
        local result=$(netstat -tuln 2>/dev/null | grep ":$port ")
        if [ -n "$result" ]; then
            local pid=$(ss -tulpn 2>/dev/null | grep ":$port " | awk '{print $6}' | cut -d',' -f2 | cut -d'=' -f2 || echo "Unknown")
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "Unknown")
            echo "⚠️  Port $port ($service) is in use"
            echo "    Process: $process (PID: $pid)"
            echo "$port|$service|$pid|$process"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        # Linux with ss
        local result=$(ss -tuln 2>/dev/null | grep ":$port ")
        if [ -n "$result" ]; then
            local pid=$(ss -tulpn 2>/dev/null | grep ":$port " | awk '{print $6}' | cut -d',' -f2 | cut -d'=' -f2 || echo "Unknown")
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "Unknown")
            echo "⚠️  Port $port ($service) is in use"
            echo "    Process: $process (PID: $pid)"
            echo "$port|$service|$pid|$process"
            return 1
        fi
    fi
    
    echo "✅ Port $port ($service) is available"
    return 0
}

# Common ports used by Deepiri services
declare -A ports=(
    ["11434"]="Ollama (Local LLM)"
    ["5432"]="PostgreSQL"
    ["6379"]="Redis"
    ["6380"]="Redis (dev)"
    ["8000"]="Cyrex API"
    ["8080"]="Adminer"
    ["8086"]="InfluxDB"
    ["5100"]="API Gateway"
    ["5173"]="Frontend"
    ["5175"]="Cyrex Interface"
    ["19530"]="Milvus"
    ["9000"]="MinIO API"
    ["9001"]="MinIO Console"
    ["5500"]="MLflow"
    ["8888"]="Jupyter"
)

conflicts=()

for port in "${!ports[@]}"; do
    service="${ports[$port]}"
    result=$(check_port "$port" "$service")
    if echo "$result" | grep -q "⚠️"; then
        conflict_info=$(echo "$result" | grep "|")
        conflicts+=("$conflict_info")
    fi
    echo ""
done

if [ ${#conflicts[@]} -eq 0 ]; then
    echo "No port conflicts detected!"
    exit 0
fi

echo "Found ${#conflicts[@]} port conflict(s)"
echo ""

if [ "$KILL_PROCESSES" = true ]; then
    echo "Killing processes using conflicting ports..."
    killed_count=0
    for conflict in "${conflicts[@]}"; do
        IFS='|' read -r port service pid process <<< "$conflict"
        if [ -n "$pid" ] && [ "$pid" != "Unknown" ]; then
            echo "  Killing $process (PID: $pid) on port $port..."
            if kill -9 "$pid" 2>/dev/null; then
                echo "    [OK] Process killed"
                killed_count=$((killed_count + 1))
            else
                echo "    [ERROR] Could not kill process"
            fi
        fi
    done
    echo ""
    if [ $killed_count -eq ${#conflicts[@]} ]; then
        echo "Port conflicts resolved. You can now start Docker services."
        exit 0
    else
        echo "Some conflicts could not be resolved automatically."
        exit 1
    fi
else
    echo "To automatically kill conflicting processes, run:"
    echo "  ./check-port-conflicts.sh --kill"
    echo ""
    echo "Or manually kill processes:"
    for conflict in "${conflicts[@]}"; do
        IFS='|' read -r port service pid process <<< "$conflict"
        if [ -n "$pid" ] && [ "$pid" != "Unknown" ]; then
            echo "  kill -9 $pid  # $service on port $port"
        fi
    done
    exit 1
fi

