#!/bin/bash
# Count Lines of Code (LOC) for main repository and all submodules
# Uses cloc (Count Lines of Code) tool

set -e

# Check if cloc is installed
if ! command -v cloc &> /dev/null; then
    echo "❌ Error: cloc is not installed"
    echo "   Install it with:"
    echo "   - macOS: brew install cloc"
    echo "   - Ubuntu/Debian: sudo apt-get install cloc"
    echo "   - Windows: choco install cloc"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Make sure we are in the root directory (one above the repo directory)
root_dir="$PROJECT_ROOT"

# Hardcoded submodule paths (from .gitmodules)
submodules=(
    "deepiri-core-api"
    "diri-cyrex"
    "platform-services/backend/deepiri-api-gateway"
    "deepiri-web-frontend"
    "platform-services/backend/deepiri-external-bridge-service"
    "platform-services/backend/deepiri-auth-service"
)

# Initialize counters
total_files=0
total_lines=0

echo "📊 Counting Lines of Code..."
echo ""

# Count main repository
echo "Counting main repository..."
main_summary=$(cloc --csv "$root_dir" 2>/dev/null | tail -n 1)
main_files=$(echo "$main_summary" | cut -d, -f4)
main_lines=$(echo "$main_summary" | cut -d, -f5)

if [ -n "$main_files" ] && [ -n "$main_lines" ]; then
    total_files=$((total_files + main_files))
    total_lines=$((total_lines + main_lines))
    echo "  Main repo: $main_files files, $main_lines lines"
else
    echo "  ⚠️  Could not count main repository"
fi

echo ""

# Count all submodules
echo "Counting submodules..."
for sub in "${submodules[@]}"; do
    sub_path="$root_dir/$sub"
    if [ -d "$sub_path" ]; then
        echo "  Counting submodule $sub..."
        sub_summary=$(cloc --csv "$sub_path" 2>/dev/null | tail -n 1)
        sub_files=$(echo "$sub_summary" | cut -d, -f4)
        sub_lines=$(echo "$sub_summary" | cut -d, -f5)
        
        if [ -n "$sub_files" ] && [ -n "$sub_lines" ]; then
            total_files=$((total_files + sub_files))
            total_lines=$((total_lines + sub_lines))
            echo "    $sub: $sub_files files, $sub_lines lines"
        else
            echo "    ⚠️  Could not count $sub"
        fi
    else
        echo "  ⚠️  Submodule $sub not found (path: $sub_path)"
    fi
done

echo ""
echo "---------------------------------"
echo "📈 Summary:"
echo "  Total files (main + submodules): $total_files"
echo "  Total lines (main + submodules): $total_lines"
echo "---------------------------------"

