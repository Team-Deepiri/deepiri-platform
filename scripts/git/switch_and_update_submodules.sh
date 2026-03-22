#!/bin/bash
# switch_and_update_submodules.sh
# Interactive script to switch branches and pull updates for selected submodules
# Always handles deepiri-platform (main repo) last with separate prompt

# Don't use set -e here because we want to continue processing other submodules even if one fails

# Get the root of the main repository
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { echo "Error: Could not change to repository root."; exit 1; }

echo "🌿 Switch and Update Submodules"
echo "================================"
echo ""

# Check if .gitmodules exists
if [ ! -f ".gitmodules" ]; then
    echo "❌ No .gitmodules file found. This doesn't appear to be a repository with submodules."
    exit 1
fi

# Extract submodule paths from .gitmodules (excluding main repo)
SUBMODULES=()
while IFS= read -r submodule_path; do
    [ -z "$submodule_path" ] && continue
    # Check if submodule directory exists
    if [ -d "$submodule_path" ] && ([ -d "$submodule_path/.git" ] || [ -f "$submodule_path/.git" ]); then
        SUBMODULES+=("$submodule_path")
    fi
done < <(grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//')

if [ ${#SUBMODULES[@]} -eq 0 ]; then
    echo "❌ No valid submodules found."
    exit 1
fi

echo "📦 Found ${#SUBMODULES[@]} submodule(s):"
for i in "${!SUBMODULES[@]}"; do
    echo "   $((i+1)). ${SUBMODULES[$i]}"
done
echo ""
echo "ℹ️  Note: deepiri-platform (main repository) will be handled separately at the end"
echo ""

# Prompt user to select submodules
while true; do
    echo "Select submodules to switch branches and update (comma-separated numbers, e.g., 1,2,3 or 'all' for all):"
    read -r selection
    
    if [ -z "$selection" ]; then
        echo "⚠️  Please enter a selection"
        continue
    fi
    
    # If not empty, break out of loop
    break
done

SELECTED_SUBMODULES=()
SELECTED_INDICES=()

if [ "$selection" = "all" ] || [ "$selection" = "ALL" ] || [ "$selection" = "All" ]; then
    SELECTED_SUBMODULES=("${SUBMODULES[@]}")
    for i in "${!SUBMODULES[@]}"; do
        SELECTED_INDICES+=("$((i+1))")
    done
    echo "✅ Selected all ${#SUBMODULES[@]} submodule(s)"
else
    # Parse comma-separated selection
    IFS=',' read -ra SELECTED_NUMS <<< "$selection"
    for idx in "${SELECTED_NUMS[@]}"; do
        # Trim whitespace
        idx_trimmed=$(echo "$idx" | xargs)
        
        # Check if it's a number
        if [[ "$idx_trimmed" =~ ^[0-9]+$ ]]; then
            idx_num=$((idx_trimmed))
            # Check if it's a valid submodule index
            if [ "$idx_num" -ge 1 ] && [ "$idx_num" -le ${#SUBMODULES[@]} ]; then
                array_idx=$((idx_num - 1))
                SELECTED_SUBMODULES+=("${SUBMODULES[$array_idx]}")
                SELECTED_INDICES+=("$idx_num")
            else
                echo "⚠️  Invalid selection: $idx_trimmed (skipping)"
            fi
        else
            echo "⚠️  Invalid selection: $idx_trimmed (skipping - use number or 'all')"
        fi
    done
fi

if [ ${#SELECTED_SUBMODULES[@]} -eq 0 ]; then
    echo "❌ No valid submodules selected."
    exit 1
fi

echo ""
echo "📝 Selected submodules:"
for i in "${!SELECTED_SUBMODULES[@]}"; do
    echo "   ${SELECTED_INDICES[$i]}. ${SELECTED_SUBMODULES[$i]}"
done
echo ""

# Branch strategy selection
echo "Branch strategy:"
echo "   1. Same branch name for all selected submodules"
echo "   2. Different branch name for each submodule"
echo "   3. Group some submodules together (share branch names)"
echo "Enter choice (1, 2, or 3, default: 1):"
read -r branch_strategy

if [ -z "$branch_strategy" ]; then
    branch_strategy="1"
fi

# Declare associative array for branch names
declare -A SUBMODULE_BRANCHES

if [ "$branch_strategy" = "1" ]; then
    # Same branch for all
    echo ""
    echo "Enter branch name for all selected submodules:"
    read -r branch_name
    
    if [ -z "$branch_name" ]; then
        echo "⚠️  No branch name provided. Exiting."
        exit 1
    fi
    
    echo "✅ Will switch all selected submodules to branch: $branch_name"
    for submodule in "${SELECTED_SUBMODULES[@]}"; do
        SUBMODULE_BRANCHES["$submodule"]="$branch_name"
    done
    
elif [ "$branch_strategy" = "2" ]; then
    # Different branch for each
    echo ""
    echo "Enter branch name for each submodule:"
    for i in "${!SELECTED_SUBMODULES[@]}"; do
        submodule="${SELECTED_SUBMODULES[$i]}"
        idx="${SELECTED_INDICES[$i]}"
        echo "   [$idx] $submodule:"
        read -r branch_name
        
        if [ -z "$branch_name" ]; then
            echo "   ⚠️  No branch name provided, skipping this submodule"
            continue
        fi
        
        SUBMODULE_BRANCHES["$submodule"]="$branch_name"
        echo "   ✅ Will switch to branch: $branch_name"
    done
    
elif [ "$branch_strategy" = "3" ]; then
    # Group some together
    echo ""
    echo "You can group submodules to share the same branch name."
    echo "Enter groups as comma-separated numbers, e.g., '1,2,3' for submodules 1, 2, and 3"
    echo "Enter 'done' when finished grouping"
    echo ""
    
    # Track which submodules have been assigned
    declare -A ASSIGNED_SUBMODULES
    
    while true; do
        echo "Enter submodule numbers to group together (comma-separated, or 'done'):"
        read -r group_input
        
        if [ "$group_input" = "done" ] || [ "$group_input" = "DONE" ] || [ "$group_input" = "Done" ]; then
            break
        fi
        
        if [ -z "$group_input" ]; then
            continue
        fi
        
        # Parse the group
        IFS=',' read -ra GROUP_NUMS <<< "$group_input"
        group_submodules=()
        group_indices=()
        
        for num in "${GROUP_NUMS[@]}"; do
            num_trimmed=$(echo "$num" | xargs)
            if [[ "$num_trimmed" =~ ^[0-9]+$ ]]; then
                idx_num=$((num_trimmed))
                # Check if this index is in our selected submodules
                found=false
                for i in "${!SELECTED_INDICES[@]}"; do
                    if [ "${SELECTED_INDICES[$i]}" -eq "$idx_num" ]; then
                        submodule="${SELECTED_SUBMODULES[$i]}"
                        # Check if already assigned
                        if [ -n "${ASSIGNED_SUBMODULES[$submodule]}" ]; then
                            echo "   ⚠️  Submodule $idx_num ($submodule) already assigned to a group"
                        else
                            group_submodules+=("$submodule")
                            group_indices+=("$idx_num")
                            ASSIGNED_SUBMODULES["$submodule"]="assigned"
                        fi
                        found=true
                        break
                    fi
                done
                if [ "$found" = false ]; then
                    echo "   ⚠️  Submodule number $idx_num not in selected list"
                fi
            else
                echo "   ⚠️  Invalid number: $num_trimmed"
            fi
        done
        
        if [ ${#group_submodules[@]} -eq 0 ]; then
            echo "   ⚠️  No valid submodules in this group"
            continue
        fi
        
        # Prompt for branch name for this group
        echo "   Enter branch name for this group (submodules: ${group_indices[*]}):"
        read -r group_branch_name
        
        if [ -z "$group_branch_name" ]; then
            echo "   ⚠️  No branch name provided, skipping this group"
            continue
        fi
        
        # Assign branch to all submodules in group
        for submodule in "${group_submodules[@]}"; do
            SUBMODULE_BRANCHES["$submodule"]="$group_branch_name"
        done
        
        echo "   ✅ Group assigned to branch: $group_branch_name"
        echo ""
    done
    
    # Check if any submodules weren't assigned
    unassigned=()
    for submodule in "${SELECTED_SUBMODULES[@]}"; do
        if [ -z "${SUBMODULE_BRANCHES[$submodule]}" ]; then
            unassigned+=("$submodule")
        fi
    done
    
    if [ ${#unassigned[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Some submodules were not assigned to a group:"
        for submodule in "${unassigned[@]}"; do
            # Find index
            for i in "${!SELECTED_SUBMODULES[@]}"; do
                if [ "${SELECTED_SUBMODULES[$i]}" = "$submodule" ]; then
                    echo "   ${SELECTED_INDICES[$i]}. $submodule"
                    break
                fi
            done
        done
        echo ""
        echo "Enter branch name for unassigned submodules (or press Enter to skip them):"
        read -r unassigned_branch
        
        if [ -n "$unassigned_branch" ]; then
            for submodule in "${unassigned[@]}"; do
                SUBMODULE_BRANCHES["$submodule"]="$unassigned_branch"
            done
        fi
    fi
else
    echo "⚠️  Invalid choice. Exiting."
    exit 1
fi

# Verify we have at least one branch assignment
if [ ${#SUBMODULE_BRANCHES[@]} -eq 0 ]; then
    echo "❌ No branch assignments made. Exiting."
    exit 1
fi

echo ""
echo "📋 Branch assignments:"
for i in "${!SELECTED_SUBMODULES[@]}"; do
    submodule="${SELECTED_SUBMODULES[$i]}"
    idx="${SELECTED_INDICES[$i]}"
    branch="${SUBMODULE_BRANCHES[$submodule]}"
    if [ -n "$branch" ]; then
        echo "   [$idx] $submodule → $branch"
    else
        echo "   [$idx] $submodule → (skipped)"
    fi
done
echo ""

# Ask about pulling/updating
echo "Pull/update from remote after switching branches? (y/n, default: y):"
read -r pull_choice

PULL_AFTER_SWITCH=true
if [ "$pull_choice" = "n" ] || [ "$pull_choice" = "N" ] || [ "$pull_choice" = "no" ] || [ "$pull_choice" = "NO" ]; then
    PULL_AFTER_SWITCH=false
    echo "ℹ️  Will switch branches but NOT pull/update"
else
    echo "✅ Will pull/update after switching branches"
fi
echo ""

# Track success/failure
SUCCESS_COUNT=0
FAILED_SUBMODULES=()

echo "🚀 Starting branch switches and updates..."
echo ""

# Process each selected submodule (excluding main repo)
for i in "${!SELECTED_SUBMODULES[@]}"; do
    submodule_path="${SELECTED_SUBMODULES[$i]}"
    idx="${SELECTED_INDICES[$i]}"
    branch_name="${SUBMODULE_BRANCHES[$submodule_path]}"
    
    if [ -z "$branch_name" ]; then
        echo "📦 [$idx] $submodule_path: Skipped (no branch assigned)"
        echo ""
        continue
    fi
    
    echo "📦 [$idx] Processing: $submodule_path"
    
    if [ ! -d "$submodule_path" ]; then
        echo "   ⚠️  Directory not found, skipping"
        FAILED_SUBMODULES+=("$submodule_path (not found)")
        echo ""
        continue
    fi
    
    cd "$submodule_path" || {
        echo "   ❌ Failed to change to $submodule_path"
        FAILED_SUBMODULES+=("$submodule_path (cd failed)")
        cd "$REPO_ROOT"
        echo ""
        continue
    }
    
    # Show current branch
    current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
    if [ -z "$current_branch" ]; then
        echo "   Current: (detached HEAD)"
    else
        echo "   Current branch: $current_branch"
    fi
    
    # Switch to target branch
    echo "   🌿 Switching to branch: $branch_name"
    
    # Check if branch exists locally
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        # Branch exists locally, checkout
        if git checkout "$branch_name" 2>/dev/null; then
            echo "   ✅ Switched to existing branch: $branch_name"
        else
            echo "   ❌ Failed to switch to branch"
            FAILED_SUBMODULES+=("$submodule_path (checkout failed)")
            cd "$REPO_ROOT"
            echo ""
            continue
        fi
    else
        # Branch doesn't exist locally, try to fetch and checkout from remote
        echo "   ℹ️  Branch doesn't exist locally, checking remote..."
        
        # Fetch first
        git fetch origin 2>/dev/null
        
        # Check if branch exists on remote
        if git rev-parse --verify "origin/$branch_name" >/dev/null 2>&1; then
            # Create and checkout tracking branch
            if git checkout -b "$branch_name" "origin/$branch_name" 2>/dev/null; then
                echo "   ✅ Created and switched to tracking branch: $branch_name"
            else
                echo "   ❌ Failed to create tracking branch"
                FAILED_SUBMODULES+=("$submodule_path (create tracking branch failed)")
                cd "$REPO_ROOT"
                echo ""
                continue
            fi
        else
            # Branch doesn't exist on remote either, create new branch
            echo "   ℹ️  Branch doesn't exist on remote, creating new branch..."
            if git checkout -b "$branch_name" 2>/dev/null; then
                echo "   ✅ Created and switched to new branch: $branch_name"
            else
                echo "   ❌ Failed to create new branch"
                FAILED_SUBMODULES+=("$submodule_path (create branch failed)")
                cd "$REPO_ROOT"
                echo ""
                continue
            fi
        fi
    fi
    
    # Pull/update if requested
    if [ "$PULL_AFTER_SWITCH" = true ]; then
        echo "   📥 Pulling latest changes..."
        
        # Get current branch (might have changed)
        current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
        
        if [ -z "$current_branch" ]; then
            echo "   ⚠️  Cannot pull from detached HEAD"
        else
            # Check if upstream is set
            upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
            
            if [ -n "$upstream" ]; then
                # Upstream is set, pull
                if git pull 2>/dev/null; then
                    echo "   ✅ Pulled successfully"
                else
                    echo "   ⚠️  Pull had issues (may have conflicts or be up to date)"
                fi
            else
                # No upstream, try to set it and pull
                echo "   ℹ️  No upstream set, setting upstream to origin/$current_branch..."
                if git branch --set-upstream-to="origin/$current_branch" "$current_branch" 2>/dev/null; then
                    if git pull 2>/dev/null; then
                        echo "   ✅ Upstream set and pulled successfully"
                    else
                        echo "   ⚠️  Upstream set but pull had issues"
                    fi
                else
                    echo "   ⚠️  Could not set upstream (branch may not exist on remote yet)"
                fi
            fi
        fi
    fi
    
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    cd "$REPO_ROOT" || exit 1
    echo ""
done

# Now handle deepiri-platform (main repository) separately at the end
echo "=========================================="
echo "🏠 Processing deepiri-platform (main repository)"
echo "=========================================="
echo ""

cd "$REPO_ROOT" || {
    echo "❌ Failed to change to repository root"
    FAILED_SUBMODULES+=("[Main repository] (cd failed)")
    exit 1
}

# Show current branch
current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
if [ -z "$current_branch" ]; then
    echo "Current: (detached HEAD)"
else
    echo "Current branch: $current_branch"
fi
echo ""

# Prompt if user wants to switch branch
echo "Switch branch for deepiri-platform? (y/n, default: n):"
read -r switch_main

if [ "$switch_main" = "y" ] || [ "$switch_main" = "Y" ] || [ "$switch_main" = "yes" ] || [ "$switch_main" = "YES" ]; then
    echo "Enter branch name for deepiri-platform:"
    read -r main_branch_name
    
    if [ -z "$main_branch_name" ]; then
        echo "⚠️  No branch name provided, staying on current branch"
    else
        echo "🌿 Switching to branch: $main_branch_name"
        
        # Check if branch exists locally
        if git rev-parse --verify "$main_branch_name" >/dev/null 2>&1; then
            # Branch exists locally, checkout
            if git checkout "$main_branch_name" 2>/dev/null; then
                echo "✅ Switched to existing branch: $main_branch_name"
            else
                echo "❌ Failed to switch to branch"
                FAILED_SUBMODULES+=("[Main repository] (checkout failed)")
            fi
        else
            # Branch doesn't exist locally, try to fetch and checkout from remote
            echo "ℹ️  Branch doesn't exist locally, checking remote..."
            
            # Fetch first
            git fetch origin 2>/dev/null
            
            # Check if branch exists on remote
            if git rev-parse --verify "origin/$main_branch_name" >/dev/null 2>&1; then
                # Create and checkout tracking branch
                if git checkout -b "$main_branch_name" "origin/$main_branch_name" 2>/dev/null; then
                    echo "✅ Created and switched to tracking branch: $main_branch_name"
                else
                    echo "❌ Failed to create tracking branch"
                    FAILED_SUBMODULES+=("[Main repository] (create tracking branch failed)")
                fi
            else
                # Branch doesn't exist on remote either, create new branch
                echo "ℹ️  Branch doesn't exist on remote, creating new branch..."
                if git checkout -b "$main_branch_name" 2>/dev/null; then
                    echo "✅ Created and switched to new branch: $main_branch_name"
                else
                    echo "❌ Failed to create new branch"
                    FAILED_SUBMODULES+=("[Main repository] (create branch failed)")
                fi
            fi
        fi
        
        # Ask about pulling for main repo
        if [ -z "$(git symbolic-ref -q HEAD)" ]; then
            echo "⚠️  Cannot pull from detached HEAD"
        else
            current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
            echo ""
            echo "Pull/update deepiri-platform from remote? (y/n, default: y):"
            read -r pull_main
            
            if [ "$pull_main" != "n" ] && [ "$pull_main" != "N" ] && [ "$pull_main" != "no" ] && [ "$pull_main" != "NO" ]; then
                echo "📥 Pulling latest changes..."
                
                # Check if upstream is set
                upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
                
                if [ -n "$upstream" ]; then
                    # Upstream is set, pull
                    if git pull 2>/dev/null; then
                        echo "✅ Pulled successfully"
                    else
                        echo "⚠️  Pull had issues (may have conflicts or be up to date)"
                    fi
                else
                    # No upstream, try to set it and pull
                    echo "ℹ️  No upstream set, setting upstream to origin/$current_branch..."
                    if git branch --set-upstream-to="origin/$current_branch" "$current_branch" 2>/dev/null; then
                        if git pull 2>/dev/null; then
                            echo "✅ Upstream set and pulled successfully"
                        else
                            echo "⚠️  Upstream set but pull had issues"
                        fi
                    else
                        echo "⚠️  Could not set upstream (branch may not exist on remote yet)"
                    fi
                fi
            else
                echo "ℹ️  Skipping pull for main repository"
            fi
        fi
    fi
else
    echo "ℹ️  Staying on current branch: ${current_branch:-"(detached HEAD)"}"
fi

echo ""

# Summary
echo "=========================================="
echo "📊 Summary"
echo "=========================================="

echo "✅ Successfully processed: $SUCCESS_COUNT submodule(s)"
if [ ${#FAILED_SUBMODULES[@]} -gt 0 ]; then
    echo "❌ Failed:"
    for failed in "${FAILED_SUBMODULES[@]}"; do
        echo "   - $failed"
    done
fi
echo ""

if [ ${#FAILED_SUBMODULES[@]} -eq 0 ]; then
    echo "🎉 All selected repositories processed successfully!"
    exit 0
else
    echo "⚠️  Some repositories had issues. See summary above."
    exit 1
fi

