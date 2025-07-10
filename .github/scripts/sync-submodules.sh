#!/bin/bash
# Sync submodules to their main branches
# This script ensures submodules stay in sync with their upstream main branches

set -e

echo "🔄 Syncing submodules to main branches..."

# Update submodule references
git submodule update --remote --merge

# Check if we have any changes to commit
if git diff --quiet HEAD -- src/gengines/; then
    echo "✅ Submodules already up to date"
    exit 0
fi

echo "📝 Submodule updates detected:"
git diff --name-only HEAD -- src/gengines/

# Check if we're in a PR context (GitHub Actions)
if [ -n "${GITHUB_REF:-}" ]; then
    echo "🔍 Running in CI - submodule changes will be handled by workflows"
    exit 0
fi

# If running locally, offer to commit the changes
echo "💡 Run 'git add src/gengines/ && git commit -m \"🔄 Update submodules to latest main\"' to commit these changes"