#!/bin/bash
set -euo pipefail

# merge-pr.sh
# Merges the PR using squash merge.
# Sets output: merged=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER

echo "🔀 Merging PR #$PR_NUMBER..."

if gh pr merge "$PR_NUMBER" --repo "$REPO" --squash --delete-branch; then
    echo "✅ PR #$PR_NUMBER merged successfully!"
    echo "merged=true" >> "$GITHUB_OUTPUT"
else
    echo "❌ Failed to merge PR #$PR_NUMBER"
    echo "merged=false" >> "$GITHUB_OUTPUT"
    exit 1
fi

