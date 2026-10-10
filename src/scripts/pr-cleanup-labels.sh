#!/bin/bash
set -euo pipefail

# pr-cleanup-labels.sh
# Removes merge queue labels from a closed PR.
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER, LABEL_CANDIDATE, LABEL_QUEUE

echo "🧹 Cleaning up labels from PR #$PR_NUMBER..."

# Remove candidate label if present
echo "Removing '$LABEL_CANDIDATE' label..."
gh pr edit "$PR_NUMBER" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" 2>/dev/null || true

# Remove queue label if present
echo "Removing '$LABEL_QUEUE' label..."
gh pr edit "$PR_NUMBER" --repo "$REPO" --remove-label "$LABEL_QUEUE" 2>/dev/null || true

echo "✅ Labels cleaned up"

