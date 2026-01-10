#!/bin/sh
# Master script to install Git hooks for all Deepiri repositories
# This installs hooks into .git/hooks so they run automatically on checkout/pull

echo "🔧 Installing Git hooks for all Deepiri repositories..."
echo ""

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

# Function to install hooks in a directory
install_hooks() {
    local repo_path=$1
    local repo_name=$2
    
    if [ -d "$repo_path" ] && [ -f "$repo_path/.git-hooks/pre-push" ]; then
        echo "📦 Installing hooks for $repo_name..."
        cd "$repo_path" || return
        
        if [ -f "scripts/install-git-hooks.sh" ]; then
            chmod +x scripts/install-git-hooks.sh
            ./scripts/install-git-hooks.sh
        elif [ -d ".git" ]; then
            # Direct installation
            mkdir -p .git/hooks
            if [ -f ".git-hooks/post-checkout" ]; then
                cp .git-hooks/post-checkout .git/hooks/post-checkout
                chmod +x .git/hooks/post-checkout
            fi
            if [ -f ".git-hooks/post-merge" ]; then
                cp .git-hooks/post-merge .git/hooks/post-merge
                chmod +x .git/hooks/post-merge
            fi
            git config core.hooksPath .git-hooks
            echo "✔ Hooks installed for $repo_name"
        fi
        
        cd "$REPO_ROOT" || return
    else
        echo "⚠️  Skipping $repo_name (not found or hooks not present)"
    fi
}

# Install hooks for main repo (deepiri-platform)
echo "🏠 Installing hooks for main repository (deepiri-platform)..."
if [ -d ".git" ] && [ -f ".git-hooks/pre-push" ]; then
    mkdir -p .git/hooks
    if [ -f ".git-hooks/post-checkout" ]; then
        cp .git-hooks/post-checkout .git/hooks/post-checkout
        chmod +x .git/hooks/post-checkout
    fi
    if [ -f ".git-hooks/post-merge" ]; then
        cp .git-hooks/post-merge .git/hooks/post-merge
        chmod +x .git/hooks/post-merge
    fi
    git config core.hooksPath .git-hooks
    echo "✔ Main repository hooks installed"
else
    echo "⚠️  Warning: Main repository hooks not found"
fi
echo ""

# Install hooks for all submodules
echo "📚 Installing hooks for submodules..."
install_hooks "deepiri-core-api" "deepiri-core-api"
install_hooks "deepiri-web-frontend" "deepiri-web-frontend"
install_hooks "platform-services/backend/deepiri-api-gateway" "deepiri-api-gateway"
install_hooks "platform-services/backend/deepiri-auth-service" "deepiri-auth-service"
install_hooks "platform-services/backend/deepiri-external-bridge-service" "deepiri-external-bridge-service"
install_hooks "diri-cyrex" "diri-cyrex"

echo ""
echo "✅ Git hooks installation complete for all repositories!"
echo ""
echo "📝 How it works:"
echo "   - Hooks are now installed in .git/hooks for each repo"
echo "   - post-checkout runs on checkout/clone and configures hooksPath"
echo "   - post-merge runs after pull and configures hooksPath"
echo "   - pre-push blocks pushes to main/dev branches"
echo ""
echo "🎉 Hooks will now automatically configure on checkout and pull!"

