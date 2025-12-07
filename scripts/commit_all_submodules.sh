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

# Prompt user to select submodules
echo "Select submodules to commit (comma-separated numbers, e.g., 1,2,3 or 'all' for all):"
read -r selection

SELECTED_SUBMODULES=()

if [ "$selection" = "all" ] || [ "$selection" = "ALL" ] || [ "$selection" = "All" ]; then
    SELECTED_SUBMODULES=("${SUBMODULES[@]}")
    echo "✅ Selected all submodules"
else
    # Parse comma-separated selection
    IFS=',' read -ra SELECTED_INDICES <<< "$selection"
    for idx in "${SELECTED_INDICES[@]}"; do
        # Trim whitespace
        idx=$(echo "$idx" | xargs)
        # Convert to 0-based index
        array_idx=$((idx - 1))
        if [ "$array_idx" -ge 0 ] && [ "$array_idx" -lt ${#SUBMODULES[@]} ]; then
            SELECTED_SUBMODULES+=("${SUBMODULES[$array_idx]}")
        else
            echo "⚠️  Invalid selection: $idx (skipping)"
        fi
    done
fi

if [ ${#SELECTED_SUBMODULES[@]} -eq 0 ]; then
    echo "❌ No valid submodules selected."
    exit 1
fi

echo ""
echo "📝 Selected submodules:"
for submodule in "${SELECTED_SUBMODULES[@]}"; do
    echo "   - $submodule"
done
echo ""

# Prompt for commit message
echo "Enter commit message (or press Enter to use default 'Save WIP before merging main'):"
read -r commit_message

# Use default if empty
if [ -z "$commit_message" ]; then
    commit_message="Save WIP before merging main"
fi

echo ""
echo "📝 Commit message: $commit_message"
echo ""

# Prompt for push
echo "Push changes after committing? (y/n, default: n):"
read -r push_choice

PUSH_AFTER_COMMIT=false
if [ "$push_choice" = "y" ] || [ "$push_choice" = "Y" ] || [ "$push_choice" = "yes" ] || [ "$push_choice" = "YES" ]; then
    PUSH_AFTER_COMMIT=true
    echo "✅ Will push after committing"
else
    echo "ℹ️  Will NOT push (commit only)"
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
        
        echo "   💾 Committing with message: '$commit_message'"
        if git commit -m "$commit_message"; then
            echo "   ✅ Committed successfully"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
            # Push if requested
            if [ "$PUSH_AFTER_COMMIT" = true ]; then
                echo "   📤 Pushing to remote..."
                if git push; then
                    echo "   ✅ Pushed successfully"
                else
                    echo "   ⚠️  Push failed (commit was successful)"
                    FAILED_SUBMODULES+=("$submodule_path (push failed)")
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

# Summary
echo "=========================================="
echo "📊 Summary"
echo "=========================================="
echo "✅ Successfully committed: $SUCCESS_COUNT submodule(s)"
if [ ${#FAILED_SUBMODULES[@]} -gt 0 ]; then
    echo "❌ Failed:"
    for failed in "${FAILED_SUBMODULES[@]}"; do
        echo "   - $failed"
    done
fi
echo ""

if [ $SUCCESS_COUNT -eq ${#SELECTED_SUBMODULES[@]} ] && [ ${#FAILED_SUBMODULES[@]} -eq 0 ]; then
    echo "🎉 All selected submodules processed successfully!"
    exit 0
else
    echo "⚠️  Some submodules had issues. See summary above."
    exit 1
fi

