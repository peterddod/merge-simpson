#!/bin/bash
set -euo pipefail

# fix-labels.sh
# Fixes label issues by ensuring only the oldest candidate PR keeps the label.
#
# Required env vars:
#   GH_TOKEN, REPO, LABEL_CANDIDATE

echo "🔧 Fixing candidate labels..."

# Get all open PRs with candidate label, sorted by PR number (oldest first)
CANDIDATE_PRS=$(gh pr list --repo "$REPO" --label "$LABEL_CANDIDATE" --state open --json number --jq '.[].number' | sort -n)
CANDIDATE_COUNT=$(echo "$CANDIDATE_PRS" | grep -c '[0-9]' || echo "0")

if [ "$CANDIDATE_COUNT" -le 1 ]; then
    echo "✅ No fix needed (0 or 1 candidate)"
    exit 0
fi

echo "Found $CANDIDATE_COUNT candidates. Keeping only the oldest..."

# Keep the first (oldest) and remove from the rest
FIRST=true
for PR in $CANDIDATE_PRS; do
    if [ "$FIRST" = true ]; then
        echo "Keeping PR #$PR as candidate"
        FIRST=false
    else
        echo "Removing '$LABEL_CANDIDATE' from PR #$PR"
        gh pr edit "$PR" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" || true
    fi
done

echo "✅ Labels fixed"

