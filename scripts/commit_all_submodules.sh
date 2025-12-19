#!/bin/bash
# commit_all_submodules.sh
# Interactive script to commit changes in selected submodules with a custom commit message
# Optionally pushes changes after committing

# Don't use set -e here because we want to continue processing other submodules even if one fails

# Get the root of the main repository
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { echo "Error: Could not change to repository root."; exit 1; }

echo "🔧 Commit All Submodules"
echo "========================"
echo ""

# Check if .gitmodules exists
if [ ! -f ".gitmodules" ]; then
    echo "❌ No .gitmodules file found. This doesn't appear to be a repository with submodules."
    exit 1
fi

# Extract submodule paths from .gitmodules
# This automatically includes all submodules listed in .gitmodules:
# - deepiri-core-api
# - diri-cyrex
# - diri-helox
# - deepiri-modelkit
# - platform-services/backend/deepiri-api-gateway
# - platform-services/backend/deepiri-auth-service
# - platform-services/backend/deepiri-external-bridge-service
# - deepiri-web-frontend
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
MAIN_REPO_NUM=$(( ${#SUBMODULES[@]} + 1 ))
echo "   $MAIN_REPO_NUM. [Main repository] (or type 'main'/'platform')"
echo ""

# Prompt user to select submodules
echo "Select submodules/repos to commit (comma-separated numbers, e.g., 1,2,3 or 'all' for all):"
echo "   Note: Type 'main' or 'platform' to select the main repository"
read -r selection

SELECTED_SUBMODULES=()

if [ "$selection" = "all" ] || [ "$selection" = "ALL" ] || [ "$selection" = "All" ]; then
    SELECTED_SUBMODULES=("${SUBMODULES[@]}")
    INCLUDE_MAIN_REPO=true
    echo "✅ Selected all submodules and main repository"
else
    # Parse comma-separated selection
    INCLUDE_MAIN_REPO=false
    IFS=',' read -ra SELECTED_INDICES <<< "$selection"
    for idx in "${SELECTED_INDICES[@]}"; do
        # Trim whitespace and convert to lowercase for keyword matching
        idx_trimmed=$(echo "$idx" | xargs | tr '[:upper:]' '[:lower:]')
        
        # Check for keywords: main, platform
        if [ "$idx_trimmed" = "main" ] || [ "$idx_trimmed" = "platform" ]; then
            INCLUDE_MAIN_REPO=true
            echo "✅ Selected main repository (via keyword: $idx)"
        # Check if it's a number
        elif [[ "$idx" =~ ^[0-9]+$ ]]; then
            # Convert to integer
            idx_num=$((idx))
            # Check if it's the main repo option
            if [ "$idx_num" -eq $MAIN_REPO_NUM ]; then
                INCLUDE_MAIN_REPO=true
                echo "✅ Selected main repository"
            # Check if it's a valid submodule index
            elif [ "$idx_num" -ge 1 ] && [ "$idx_num" -le ${#SUBMODULES[@]} ]; then
                array_idx=$((idx_num - 1))
            SELECTED_SUBMODULES+=("${SUBMODULES[$array_idx]}")
        else
            echo "⚠️  Invalid selection: $idx (skipping)"
            fi
        else
            echo "⚠️  Invalid selection: $idx (skipping - use number, 'main', 'platform', or 'all')"
        fi
    done
fi

if [ ${#SELECTED_SUBMODULES[@]} -eq 0 ] && [ "$INCLUDE_MAIN_REPO" = false ]; then
    echo "❌ No valid repositories selected."
    exit 1
fi

echo ""
echo "📝 Selected repositories:"
for submodule in "${SELECTED_SUBMODULES[@]}"; do
    echo "   - $submodule"
done
if [ "$INCLUDE_MAIN_REPO" = true ]; then
    echo "   - [Main repository]"
fi
echo ""

# Prompt for commit message strategy
echo "Commit message strategy:"
echo "   1. Same message for all submodules (auto-push & auto-upstream for submodules only)"
echo "   2. Individual messages for each repository (manual control)"
echo "Enter choice (1 or 2, default: 1):"
read -r message_strategy

if [ -z "$message_strategy" ]; then
    message_strategy="1"
fi

USE_SAME_MESSAGE=false
if [ "$message_strategy" = "1" ]; then
    USE_SAME_MESSAGE=true
    echo "✅ Using same commit message for all submodules"
    echo "   (Auto-push and auto-upstream enabled for submodules only)"

# Prompt for commit message
    echo ""
echo "Enter commit message (or press Enter to use default 'Save WIP before merging main'):"
read -r commit_message

# Use default if empty
if [ -z "$commit_message" ]; then
    commit_message="Save WIP before merging main"
fi

echo ""
echo "📝 Commit message: $commit_message"
    echo "   (Will be used for all submodules)"
    echo ""
    
    # Auto-enable push and upstream setup for submodules only (same message mode)
    SUBMODULE_AUTO_PUSH=true
    SUBMODULE_AUTO_UPSTREAM=true
    echo "✅ Auto-push enabled for submodules"
    echo "✅ Auto-set upstream enabled for submodules"
    echo ""
    
    # Still prompt for main repository push/upstream (always prompts, never auto)
    MAIN_REPO_PUSH=false
    if [ "$INCLUDE_MAIN_REPO" = true ]; then
        echo "Push changes for main repository after committing? (y/n, default: n):"
        read -r main_push_choice
        
        if [ "$main_push_choice" = "y" ] || [ "$main_push_choice" = "Y" ] || [ "$main_push_choice" = "yes" ] || [ "$main_push_choice" = "YES" ]; then
            MAIN_REPO_PUSH=true
            echo "✅ Will push main repository after committing"
        else
            echo "ℹ️  Will NOT push main repository (commit only)"
        fi
    fi
else
    USE_SAME_MESSAGE=false
    SUBMODULE_AUTO_PUSH=false
    SUBMODULE_AUTO_UPSTREAM=false
    echo "✅ Using individual commit messages (manual control)"
echo ""

    # Prompt for push (applies to all repos/submodules in individual mode)
echo "Push changes after committing? (y/n, default: n):"
read -r push_choice

PUSH_AFTER_COMMIT=false
    MAIN_REPO_PUSH=false
if [ "$push_choice" = "y" ] || [ "$push_choice" = "Y" ] || [ "$push_choice" = "yes" ] || [ "$push_choice" = "YES" ]; then
    PUSH_AFTER_COMMIT=true
        MAIN_REPO_PUSH=true
    echo "✅ Will push after committing"
else
    echo "ℹ️  Will NOT push (commit only)"
    fi
fi

echo ""
echo "🚀 Starting commits..."
echo ""

# Track success/failure
SUCCESS_COUNT=0
FAILED_SUBMODULES=()

# Commit each selected submodule
for submodule_path in "${SELECTED_SUBMODULES[@]}"; do
    echo "📦 Processing: $submodule_path"
    
    if [ ! -d "$submodule_path" ]; then
        echo "   ⚠️  Directory not found, skipping"
        FAILED_SUBMODULES+=("$submodule_path (not found)")
        continue
    fi
    
    cd "$submodule_path" || {
        echo "   ❌ Failed to change to $submodule_path"
        FAILED_SUBMODULES+=("$submodule_path (cd failed)")
        cd "$REPO_ROOT"
        continue
    }
    
    # Check if HEAD is detached
    if [ -z "$(git symbolic-ref -q HEAD)" ]; then
        echo "   ⚠️  HEAD is detached"
        echo "   Would you like to switch to a branch? (y/n, default: n):"
        read -r switch_branch
        
        if [ "$switch_branch" = "y" ] || [ "$switch_branch" = "Y" ] || [ "$switch_branch" = "yes" ] || [ "$switch_branch" = "YES" ]; then
            # List available branches
            echo "   Available branches:"
            branches=$(git branch -a | grep -v HEAD | sed 's/^\*\? *//' | sed 's/^remotes\/origin\///' | sort -u)
            branch_array=()
            i=1
            while IFS= read -r branch; do
                [ -z "$branch" ] && continue
                echo "      $i. $branch"
                branch_array+=("$branch")
                i=$((i + 1))
            done <<< "$branches"
            
            if [ ${#branch_array[@]} -eq 0 ]; then
                echo "   ℹ️  No existing branches found"
            else
                echo "      $((${#branch_array[@]} + 1)). [Create new branch]"
            fi
            
            echo "   Enter branch number, name, or 'new' to create a new branch (default: main):"
            read -r branch_selection
            
            if [ -z "$branch_selection" ]; then
                branch_selection="main"
            fi
            
            # Check if user wants to create a new branch
            if [ "$branch_selection" = "new" ] || [ "$branch_selection" = "NEW" ] || [ "$branch_selection" = "New" ]; then
                echo "   Enter name for new branch:"
                read -r new_branch_name
                
                if [ -z "$new_branch_name" ]; then
                    echo "   ⚠️  No branch name provided, continuing with detached HEAD"
                    selected_branch=""
                else
                    # Create and checkout new branch
                    if git checkout -b "$new_branch_name" 2>/dev/null; then
                        echo "   ✅ Created and switched to new branch: $new_branch_name"
                        selected_branch="$new_branch_name"
                    else
                        echo "   ⚠️  Failed to create branch, continuing with detached HEAD"
                        selected_branch=""
                    fi
                fi
            # Check if it's a number
            elif [[ "$branch_selection" =~ ^[0-9]+$ ]]; then
                idx=$((branch_selection - 1))
                # Check if it's the "create new branch" option
                if [ "$idx" -eq ${#branch_array[@]} ]; then
                    echo "   Enter name for new branch:"
                    read -r new_branch_name
                    
                    if [ -z "$new_branch_name" ]; then
                        echo "   ⚠️  No branch name provided, continuing with detached HEAD"
                        selected_branch=""
                    else
                        # Create and checkout new branch
                        if git checkout -b "$new_branch_name" 2>/dev/null; then
                            echo "   ✅ Created and switched to new branch: $new_branch_name"
                            selected_branch="$new_branch_name"
                        else
                            echo "   ⚠️  Failed to create branch, continuing with detached HEAD"
                            selected_branch=""
                        fi
                    fi
                elif [ "$idx" -ge 0 ] && [ "$idx" -lt ${#branch_array[@]} ]; then
                    selected_branch="${branch_array[$idx]}"
                else
                    echo "   ⚠️  Invalid branch number, continuing with detached HEAD"
                    selected_branch=""
                fi
            else
                # User entered a branch name directly
                selected_branch="$branch_selection"
            fi
            
            if [ -n "$selected_branch" ] && [ "$selected_branch" != "$new_branch_name" ]; then
                # Try to checkout the branch (only if we didn't just create it)
                if git checkout "$selected_branch" 2>/dev/null || git checkout -b "$selected_branch" "origin/$selected_branch" 2>/dev/null || git checkout -b "$selected_branch" 2>/dev/null; then
                    echo "   ✅ Switched to branch: $selected_branch"
                else
                    echo "   ⚠️  Failed to switch to branch, continuing with detached HEAD"
                fi
            fi
        else
            echo "   ℹ️  Continuing with detached HEAD"
        fi
    fi
    
    # Get commit message (individual or shared)
    submodule_commit_message=""
    if [ "$USE_SAME_MESSAGE" = false ]; then
        echo "   Enter commit message for $submodule_path (or press Enter to skip):"
        read -r submodule_commit_message
        
        if [ -z "$submodule_commit_message" ]; then
            echo "   ℹ️  Skipping (no commit message provided)"
            cd "$REPO_ROOT" || exit 1
            continue
        fi
    else
        # Use shared commit message
        submodule_commit_message="$commit_message"
    fi
    
    # Check if there are any changes to commit (staged or unstaged)
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        # There are changes
        echo "   📝 Staging changes..."
        git add . || {
            echo "   ❌ Failed to stage changes"
            FAILED_SUBMODULES+=("$submodule_path (git add failed)")
            cd "$REPO_ROOT"
            continue
        }
        
        echo "   💾 Committing with message: '$submodule_commit_message'"
        if git commit -m "$submodule_commit_message"; then
            echo "   ✅ Committed successfully"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
            # Push logic for submodules
            should_push_submodule=false
            if [ "$SUBMODULE_AUTO_PUSH" = true ]; then
                # Auto-push for submodules (same message mode)
                should_push_submodule=true
            elif [ "$PUSH_AFTER_COMMIT" = true ]; then
                # Manual push (individual message mode)
                should_push_submodule=true
            fi
            
            if [ "$should_push_submodule" = true ]; then
                echo "   📤 Pushing to remote..."
                
                # Get current branch name
                current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
                
                if [ -z "$current_branch" ]; then
                    echo "   ⚠️  Cannot push from detached HEAD"
                    FAILED_SUBMODULES+=("$submodule_path (detached HEAD, cannot push)")
                else
                    # Try to push
                    push_output=$(git push 2>&1)
                    push_exit_code=$?
                    
                    if [ $push_exit_code -eq 0 ]; then
                    echo "   ✅ Pushed successfully"
                else
                        # Check if it's an upstream issue
                        if echo "$push_output" | grep -q "no upstream branch\|has no upstream branch\|set upstream"; then
                            if [ "$SUBMODULE_AUTO_UPSTREAM" = true ]; then
                                # Auto-set upstream for submodules (same message mode)
                                echo "   🔗 Auto-setting upstream to origin/$current_branch..."
                                if git push --set-upstream origin "$current_branch"; then
                                    echo "   ✅ Upstream set and pushed successfully"
                                else
                                    echo "   ❌ Failed to set upstream and push"
                                    FAILED_SUBMODULES+=("$submodule_path (upstream setup failed)")
                                fi
                            else
                                # Manual prompt (individual message mode)
                                echo "   ⚠️  Branch '$current_branch' has no upstream set"
                                echo "   Set upstream to 'origin/$current_branch'? (y/n, default: y):"
                                read -r set_upstream
                                
                                if [ -z "$set_upstream" ] || [ "$set_upstream" = "y" ] || [ "$set_upstream" = "Y" ] || [ "$set_upstream" = "yes" ] || [ "$set_upstream" = "YES" ]; then
                                    echo "   🔗 Setting upstream to origin/$current_branch..."
                                    if git push --set-upstream origin "$current_branch"; then
                                        echo "   ✅ Upstream set and pushed successfully"
                                    else
                                        echo "   ❌ Failed to set upstream and push"
                                        FAILED_SUBMODULES+=("$submodule_path (upstream setup failed)")
                                    fi
                                else
                                    echo "   ℹ️  Skipping upstream setup (push not performed)"
                                    FAILED_SUBMODULES+=("$submodule_path (upstream not set)")
                                fi
                            fi
                        else
                            echo "   ⚠️  Push failed: $push_output"
                    echo "   ⚠️  Push failed (commit was successful)"
                    FAILED_SUBMODULES+=("$submodule_path (push failed)")
                        fi
                    fi
                fi
            fi
        else
            echo "   ❌ Commit failed"
            FAILED_SUBMODULES+=("$submodule_path (commit failed)")
        fi
    else
        echo "   ℹ️  No changes to commit (working tree clean)"
    fi
    
    cd "$REPO_ROOT" || exit 1
    echo ""
done

# Process main repository if selected
if [ "$INCLUDE_MAIN_REPO" = true ]; then
    echo "📦 Processing: [Main repository]"
    cd "$REPO_ROOT" || {
        echo "   ❌ Failed to change to repository root"
        FAILED_SUBMODULES+=("[Main repository] (cd failed)")
    }
    
    # Check if HEAD is detached (same logic as submodules)
    if [ -z "$(git symbolic-ref -q HEAD)" ]; then
        echo "   ⚠️  HEAD is detached"
        echo "   Would you like to switch to a branch? (y/n, default: n):"
        read -r switch_branch
        
        if [ "$switch_branch" = "y" ] || [ "$switch_branch" = "Y" ] || [ "$switch_branch" = "yes" ] || [ "$switch_branch" = "YES" ]; then
            # List available branches
            echo "   Available branches:"
            branches=$(git branch -a | grep -v HEAD | sed 's/^\*\? *//' | sed 's/^remotes\/origin\///' | sort -u)
            branch_array=()
            i=1
            while IFS= read -r branch; do
                [ -z "$branch" ] && continue
                echo "      $i. $branch"
                branch_array+=("$branch")
                i=$((i + 1))
            done <<< "$branches"
            
            if [ ${#branch_array[@]} -eq 0 ]; then
                echo "   ℹ️  No existing branches found"
            else
                echo "      $((${#branch_array[@]} + 1)). [Create new branch]"
            fi
            
            echo "   Enter branch number, name, or 'new' to create a new branch (default: main):"
            read -r branch_selection
            
            if [ -z "$branch_selection" ]; then
                branch_selection="main"
            fi
            
            # Check if user wants to create a new branch
            if [ "$branch_selection" = "new" ] || [ "$branch_selection" = "NEW" ] || [ "$branch_selection" = "New" ]; then
                echo "   Enter name for new branch:"
                read -r new_branch_name
                
                if [ -z "$new_branch_name" ]; then
                    echo "   ⚠️  No branch name provided, continuing with detached HEAD"
                    selected_branch=""
                else
                    # Create and checkout new branch
                    if git checkout -b "$new_branch_name" 2>/dev/null; then
                        echo "   ✅ Created and switched to new branch: $new_branch_name"
                        selected_branch="$new_branch_name"
                    else
                        echo "   ⚠️  Failed to create branch, continuing with detached HEAD"
                        selected_branch=""
                    fi
                fi
            # Check if it's a number
            elif [[ "$branch_selection" =~ ^[0-9]+$ ]]; then
                idx=$((branch_selection - 1))
                # Check if it's the "create new branch" option
                if [ "$idx" -eq ${#branch_array[@]} ]; then
                    echo "   Enter name for new branch:"
                    read -r new_branch_name
                    
                    if [ -z "$new_branch_name" ]; then
                        echo "   ⚠️  No branch name provided, continuing with detached HEAD"
                        selected_branch=""
                    else
                        # Create and checkout new branch
                        if git checkout -b "$new_branch_name" 2>/dev/null; then
                            echo "   ✅ Created and switched to new branch: $new_branch_name"
                            selected_branch="$new_branch_name"
                        else
                            echo "   ⚠️  Failed to create branch, continuing with detached HEAD"
                            selected_branch=""
                        fi
                    fi
                elif [ "$idx" -ge 0 ] && [ "$idx" -lt ${#branch_array[@]} ]; then
                    selected_branch="${branch_array[$idx]}"
                else
                    echo "   ⚠️  Invalid branch number, continuing with detached HEAD"
                    selected_branch=""
                fi
            else
                # User entered a branch name directly
                selected_branch="$branch_selection"
            fi
            
            if [ -n "$selected_branch" ] && [ "$selected_branch" != "$new_branch_name" ]; then
                # Try to checkout the branch (only if we didn't just create it)
                if git checkout "$selected_branch" 2>/dev/null || git checkout -b "$selected_branch" "origin/$selected_branch" 2>/dev/null || git checkout -b "$selected_branch" 2>/dev/null; then
                    echo "   ✅ Switched to branch: $selected_branch"
                else
                    echo "   ⚠️  Failed to switch to branch, continuing with detached HEAD"
                fi
            fi
        else
            echo "   ℹ️  Continuing with detached HEAD"
        fi
    fi
    
    # Get commit message (individual or shared)
    main_commit_message=""
    if [ "$USE_SAME_MESSAGE" = false ]; then
        echo "   Enter commit message for main repository (or press Enter to skip):"
        read -r main_commit_message
        
        if [ -z "$main_commit_message" ]; then
            echo "   ℹ️  Skipping (no commit message provided)"
            echo ""
        fi
    else
        # Use shared commit message
        main_commit_message="$commit_message"
    fi
    
    # Only proceed if we have a commit message
    if [ -n "$main_commit_message" ]; then
        # Check if there are any changes to commit
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo "   📝 Staging changes..."
            if ! git add .; then
                echo "   ❌ Failed to stage changes"
                FAILED_SUBMODULES+=("[Main repository] (git add failed)")
            else
                echo "   💾 Committing with message: '$main_commit_message'"
                if git commit -m "$main_commit_message"; then
                    echo "   ✅ Committed successfully"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    
                    # Push logic for main repository (always prompts, even in same message mode)
                    if [ "$MAIN_REPO_PUSH" = true ]; then
                        echo "   📤 Pushing to remote..."
                        
                        # Get current branch name
                        current_branch=$(git symbolic-ref -q HEAD | sed 's/^refs\/heads\///')
                        
                        if [ -z "$current_branch" ]; then
                            echo "   ⚠️  Cannot push from detached HEAD"
                            FAILED_SUBMODULES+=("[Main repository] (detached HEAD, cannot push)")
                        else
                            # Try to push
                            push_output=$(git push 2>&1)
                            push_exit_code=$?
                            
                            if [ $push_exit_code -eq 0 ]; then
                                echo "   ✅ Pushed successfully"
                            else
                                    # Check if it's an upstream issue (main repo always prompts)
                                    if echo "$push_output" | grep -q "no upstream branch\|has no upstream branch\|set upstream"; then
                                        # Main repository always prompts for upstream (never auto)
                                        echo "   ⚠️  Branch '$current_branch' has no upstream set"
                                        echo "   Set upstream to 'origin/$current_branch'? (y/n, default: y):"
                                        read -r set_upstream
                                        
                                        if [ -z "$set_upstream" ] || [ "$set_upstream" = "y" ] || [ "$set_upstream" = "Y" ] || [ "$set_upstream" = "yes" ] || [ "$set_upstream" = "YES" ]; then
                                            echo "   🔗 Setting upstream to origin/$current_branch..."
                                            if git push --set-upstream origin "$current_branch"; then
                                                echo "   ✅ Upstream set and pushed successfully"
                                            else
                                                echo "   ❌ Failed to set upstream and push"
                                                FAILED_SUBMODULES+=("[Main repository] (upstream setup failed)")
                                            fi
                                        else
                                            echo "   ℹ️  Skipping upstream setup (push not performed)"
                                            FAILED_SUBMODULES+=("[Main repository] (upstream not set)")
                                        fi
                                else
                                    echo "   ⚠️  Push failed: $push_output"
                                    echo "   ⚠️  Push failed (commit was successful)"
                                    FAILED_SUBMODULES+=("[Main repository] (push failed)")
                                fi
                            fi
                        fi
                    fi
                else
                    echo "   ❌ Commit failed"
                    FAILED_SUBMODULES+=("[Main repository] (commit failed)")
                fi
            fi
        else
            echo "   ℹ️  No changes to commit (working tree clean)"
        fi
    fi
    echo ""
fi

# Summary
echo "=========================================="
echo "📊 Summary"
echo "=========================================="

# Calculate expected count (submodules + main repo if selected)
EXPECTED_COUNT=${#SELECTED_SUBMODULES[@]}
if [ "$INCLUDE_MAIN_REPO" = true ]; then
    EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
fi

echo "✅ Successfully committed: $SUCCESS_COUNT repository/repositories"
if [ ${#FAILED_SUBMODULES[@]} -gt 0 ]; then
    echo "❌ Failed:"
    for failed in "${FAILED_SUBMODULES[@]}"; do
        echo "   - $failed"
    done
fi
echo ""

if [ $SUCCESS_COUNT -eq $EXPECTED_COUNT ] && [ ${#FAILED_SUBMODULES[@]} -eq 0 ]; then
    echo "🎉 All selected repositories processed successfully!"
    exit 0
else
    echo "⚠️  Some repositories had issues. See summary above."
    exit 1
fi

