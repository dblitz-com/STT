#!/bin/bash
# Instant Claude trigger - just @Claude and go!

echo "🤖 @Claude triggered!"

curl -X POST http://localhost:9000/webhook/local \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: issue_comment" \
  -d '{
    "action": "created",
    "issue": {
      "number": 123,
      "title": "Test instant Claude",
      "body": "Test issue",
      "state": "open",
      "user": {"login": "user", "type": "User"}
    },
    "comment": {
      "id": 456,
      "body": "@Claude create a TypeScript hello world function in hello.ts and commit it with message \"feat: add hello world\"",
      "user": {"login": "user", "type": "User"}
    },
    "repository": {
      "name": "engine",
      "full_name": "dblitz/engine",
      "owner": {"login": "dblitz"},
      "default_branch": "main"
    },
    "sender": {"login": "user", "type": "User"}
  }'