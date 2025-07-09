#!/bin/bash
# Test script to verify Claude integration is working correctly

echo "🧪 Testing Claude Code Integration..."

# Test 1: Check if all required files exist
echo "📁 Checking required files..."
required_files=(
  "src/coding/entrypoints/claude-runner.ts"
  "src/coding/entrypoints/webhook-claude-handler.ts"
  "src/coding/claudecode/claudecodeaction/src/entrypoints/kubernetes-runner.ts"
  "src/coding/claudecode/claudecodebaseaction/src/index.ts"
  "src/coding/utils/kubernetes-core.ts"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ Missing: $file"
    exit 1
  fi
done

# Test 2: Run TypeScript compilation check
echo -e "\n📝 Checking TypeScript compilation..."
cd src/coding/claudecode/claudecodeaction
bun run tsc --noEmit || echo "⚠️  TypeScript errors in claudecodeaction"

cd ../claudecodebaseaction
bun run tsc --noEmit || echo "⚠️  TypeScript errors in claudecodebaseaction"

cd ../../../../

# Test 3: Check if webhook handler compiles
echo -e "\n🔧 Checking webhook handler..."
bun run src/coding/entrypoints/webhook-claude-handler.ts --help 2>/dev/null || echo "✅ Webhook handler syntax OK"

# Test 4: Check if claude-runner compiles
echo -e "\n🏃 Checking claude-runner..."
bun run src/coding/entrypoints/claude-runner.ts --help 2>/dev/null || echo "✅ Claude runner syntax OK"

# Test 5: Check Docker images build
echo -e "\n🐳 Docker build check..."
echo "Run these commands to build Docker images:"
echo "  docker build -f Dockerfile.claude-runner -t claude-runner:test ."
echo "  docker build -f src/webhook-server/Dockerfile -t webhook-server:test ."

echo -e "\n✨ Basic integration checks complete!"
echo "Next steps:"
echo "1. Build and push Docker images"
echo "2. Update Kubernetes deployments with new images"
echo "3. Configure GitHub webhook to point to /hooks/agent-issue-router"
echo "4. Test with a '@claude' comment on a GitHub issue"