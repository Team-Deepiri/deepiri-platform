#!/bin/bash

# Script to reset all submodules and platform at head, then pull main into current branch
# Detects changes and asks user before wiping them

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and find platform root (go up from scripts/git/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if deepiri-platform exists
if [ ! -d "$PLATFORM_DIR" ]; then
    echo -e "${RED}Error: deepiri-platform directory not found at $PLATFORM_DIR${NC}"
    exit 1
fi

# Check if deepiri-platform is a git repo
if [ ! -d "$PLATFORM_DIR/.git" ]; then
    echo -e "${RED}Error: $PLATFORM_DIR is not a git repository${NC}"
    exit 1
fi

echo -e "${GREEN}Checking for changes in deepiri-platform and submodules...${NC}"

# Function to check for changes
check_changes() {
    local has_changes=false
    
    # Check main repo
    cd "$PLATFORM_DIR"
    if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}Changes detected in deepiri-platform:${NC}"
        git status --short
        has_changes=true
    fi
    
    # Check all submodules
    if [ -f "$PLATFORM_DIR/.gitmodules" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^\[submodule\ \"(.*)\"\]$ ]]; then
                submodule_name="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                submodule_path="${BASH_REMATCH[1]}"
                if [ -d "$PLATFORM_DIR/$submodule_path" ]; then
                    cd "$PLATFORM_DIR/$submodule_path"
                    if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git status --porcelain)" ]; then
                        echo -e "${YELLOW}Changes detected in submodule $submodule_path:${NC}"
                        git status --short
                        has_changes=true
                    fi
                fi
            fi
        done < "$PLATFORM_DIR/.gitmodules"
    fi
    
    # Also check for any other .gitmodules files recursively
    while IFS= read -r gitmodules_file; do
        if [ "$gitmodules_file" != "$PLATFORM_DIR/.gitmodules" ]; then
            gitmodules_dir="$(dirname "$gitmodules_file")"
            echo -e "${YELLOW}Found additional .gitmodules at: $gitmodules_file${NC}"
            cd "$gitmodules_dir"
            while IFS= read -r sub_line; do
                if [[ $sub_line =~ ^\[submodule\ \"(.*)\"\]$ ]]; then
                    nested_submodule_name="${BASH_REMATCH[1]}"
                elif [[ $sub_line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    nested_submodule_path="${BASH_REMATCH[1]}"
                    if [ -d "$gitmodules_dir/$nested_submodule_path" ]; then
                        cd "$gitmodules_dir/$nested_submodule_path"
                        if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git status --porcelain)" ]; then
                            echo -e "${YELLOW}Changes detected in nested submodule $nested_submodule_path:${NC}"
                            git status --short
                            has_changes=true
                        fi
                    fi
                fi
            done < "$gitmodules_file"
        fi
    done < <(find "$PLATFORM_DIR" -name ".gitmodules" -type f)
    
    echo "$has_changes"
}

# Check for changes
has_changes=$(check_changes)

if [ "$has_changes" = "true" ]; then
    echo ""
    echo -e "${RED}WARNING: Uncommitted changes detected!${NC}"
    echo -e "${YELLOW}This script will wipe out all changes in:${NC}"
    echo "  - deepiri-platform repository"
    echo "  - All submodules"
    echo ""
    read -p "Do you want to continue and wipe out all changes? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}Aborted by user.${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}Proceeding with reset...${NC}"
else
    echo -e "${GREEN}No uncommitted changes detected.${NC}"
fi

# Function to reset submodules recursively
reset_submodules() {
    local base_dir="$1"
    local gitmodules_file="$2"
    
    if [ ! -f "$gitmodules_file" ]; then
        return
    fi
    
    cd "$base_dir"
    
    # Reset all submodules in this .gitmodules
    while IFS= read -r line; do
        if [[ $line =~ ^\[submodule\ \"(.*)\"\]$ ]]; then
            submodule_name="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            submodule_path="${BASH_REMATCH[1]}"
            if [ -d "$base_dir/$submodule_path" ]; then
                echo -e "${GREEN}Resetting submodule: $submodule_path${NC}"
                cd "$base_dir/$submodule_path"
                
                # Reset this submodule
                git reset --hard HEAD 2>/dev/null || true
                git clean -fd 2>/dev/null || true
                
                # Recursively reset nested submodules if they exist
                if [ -f "$base_dir/$submodule_path/.gitmodules" ]; then
                    reset_submodules "$base_dir/$submodule_path" "$base_dir/$submodule_path/.gitmodules"
                fi
            fi
        fi
    done < "$gitmodules_file"
}

# Reset main repository
echo -e "${GREEN}Resetting deepiri-platform to HEAD...${NC}"
cd "$PLATFORM_DIR"
git reset --hard HEAD
git clean -fd

# Reset all submodules (including nested ones)
echo -e "${GREEN}Resetting all submodules...${NC}"

# Find and process all .gitmodules files
while IFS= read -r gitmodules_file; do
    gitmodules_dir="$(dirname "$gitmodules_file")"
    echo -e "${GREEN}Processing .gitmodules at: $gitmodules_file${NC}"
    reset_submodules "$gitmodules_dir" "$gitmodules_file"
done < <(find "$PLATFORM_DIR" -name ".gitmodules" -type f)

# Get current branch
cd "$PLATFORM_DIR"
current_branch=$(git branch --show-current)

if [ -z "$current_branch" ]; then
    echo -e "${RED}Error: Could not determine current branch. Are you in a detached HEAD state?${NC}"
    exit 1
fi

echo -e "${GREEN}Current branch: $current_branch${NC}"

# Fetch latest changes
echo -e "${GREEN}Fetching latest changes...${NC}"
git fetch origin

# Check if main branch exists
if git show-ref --verify --quiet refs/heads/main; then
    main_branch="main"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
    main_branch="main"
elif git show-ref --verify --quiet refs/heads/master; then
    main_branch="master"
elif git show-ref --verify --quiet refs/remotes/origin/master; then
    main_branch="master"
else
    echo -e "${RED}Error: Could not find 'main' or 'master' branch${NC}"
    exit 1
fi

# Pull main into current branch
echo -e "${GREEN}Pulling $main_branch into $current_branch...${NC}"
set +e  # Temporarily disable exit on error for merge
git merge origin/$main_branch --no-edit
merge_exit_code=$?
set -e  # Re-enable exit on error

if [ $merge_exit_code -ne 0 ]; then
    echo -e "${RED}Merge failed! There may be conflicts to resolve manually.${NC}"
    echo -e "${YELLOW}You can resolve conflicts and continue, or abort with: git merge --abort${NC}"
    exit 1
fi

# Update submodules to their registered commits
echo -e "${GREEN}Updating submodules to registered commits...${NC}"
cd "$PLATFORM_DIR"
git submodule update --init --recursive --force

echo -e "${GREEN}Done!${NC}"
echo -e "${GREEN}deepiri-platform and all submodules have been reset and updated.${NC}"

