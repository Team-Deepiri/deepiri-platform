#!/bin/bash
# Fix all submodule hooks to handle .git as file (not directory)

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

echo "🔧 Fixing submodule hooks to handle .git as file..."
echo ""

# Function to fix a hook file
fix_hook_file() {
    local hook_file=$1
    
    if [ ! -f "$hook_file" ]; then
        return
    fi
    
    # Check if it needs fixing (has mkdir -p .git/hooks without check)
    if grep -q "mkdir -p \.git/hooks" "$hook_file" && ! grep -q "if \[ -d \"\.git\" \]" "$hook_file"; then
        echo "  Fixing: $hook_file"
        
        # Create backup
        cp "$hook_file" "$hook_file.bak"
        
        # Fix the hook - replace the problematic section
        # This is a bit complex, so we'll use sed to add the check
        
        # Pattern to match: lines with "mkdir -p .git/hooks" followed by hook copying
        # We need to wrap it in an if statement
        
        # For now, let's use a Python script or just replace the whole section
        # Actually, let's use a simpler approach - replace the specific pattern
        
        # Check if it's post-checkout or post-merge
        if grep -q "Install hooks from .git-hooks to .git/hooks" "$hook_file"; then
            # This is the section we need to fix
            # We'll use a here-doc to create the fixed version
            python3 << 'PYTHON_SCRIPT'
import sys
import re

hook_file = sys.argv[1]

with open(hook_file, 'r') as f:
    content = f.read()

# Pattern to match the problematic section
pattern = r'(# Install hooks from \.git-hooks to \.git/hooks if needed\nif \[ -d "\.git-hooks" \]; then\n\s+)mkdir -p \.git/hooks\n(\s+for hook in \.git-hooks/\*; do\n\s+if \[ -f "\$hook" \] && \[ -x "\$hook" \]; then\n\s+hook_name=\$\(basename "\$hook"\)\n\s+# Only copy if missing or outdated\n\s+if \[ ! -f "\.git/hooks/\$hook_name" \] \|\| \[ "\.git/hooks/\$hook_name" -ot "\$hook" \]; then\n\s+cp "\$hook" "\.git/hooks/\$hook_name"\n\s+chmod \+x "\.git/hooks/\$hook_name"\n\s+fi\n\s+fi\n\s+done\n\s+fi)'

replacement = r'''\1# NOTE: For submodules, .git is usually a FILE, not a directory
    # We only create .git/hooks if .git is actually a directory (not a file)
    if [ -d ".git" ] && [ ! -f ".git" ]; then
        mkdir -p .git/hooks
\2
    fi
fi'''

fixed_content = re.sub(pattern, replacement, content)

with open(hook_file, 'w') as f:
    f.write(fixed_content)

print(f"Fixed: {hook_file}")
PYTHON_SCRIPT
            "$hook_file"
        fi
    fi
}

# Find all submodule hook files
if [ -f ".gitmodules" ]; then
    while IFS= read -r submodule_path; do
        [ -z "$submodule_path" ] && continue
        
        if [ -d "$submodule_path/.git-hooks" ]; then
            echo "📦 Checking $submodule_path..."
            
            # Fix post-checkout
            if [ -f "$submodule_path/.git-hooks/post-checkout" ]; then
                fix_hook_file "$submodule_path/.git-hooks/post-checkout"
            fi
            
            # Fix post-merge
            if [ -f "$submodule_path/.git-hooks/post-merge" ]; then
                fix_hook_file "$submodule_path/.git-hooks/post-merge"
            fi
        fi
    done < <(grep -E "^\s*path\s*=\s*" .gitmodules | sed -E 's/^\s*path\s*=\s*//' | sed 's/[[:space:]]*$//')
fi

echo ""
echo "✅ Submodule hooks fixed!"

