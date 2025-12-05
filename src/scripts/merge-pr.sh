#!/bin/bash
set -euo pipefail

# merge-pr.sh
# Merges the PR using squash merge.
# On failure, removes candidate label so queue can proceed.
# Sets output: merged=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER, LABEL_CANDIDATE

echo "🔀 Merging PR #$PR_NUMBER..."

if gh pr merge "$PR_NUMBER" --repo "$REPO" --squash --delete-branch; then
    echo "✅ PR #$PR_NUMBER merged successfully!"
    echo "merged=true" >> "$GITHUB_OUTPUT"
else
    echo "❌ Failed to merge PR #$PR_NUMBER"
    echo "merged=false" >> "$GITHUB_OUTPUT"
    
    # Remove candidate label so next run picks a new candidate
    echo "🏷️  Removing candidate label to unblock queue..."
    gh pr edit "$PR_NUMBER" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" 2>/dev/null || true
    
    exit 1
fi
