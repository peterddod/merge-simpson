#!/bin/bash
set -euo pipefail

# fix-labels.sh
# Fixes label issues by ensuring only the oldest candidate PR keeps the label.
# Uses createdAt for determining oldest (not PR number).
#
# Required env vars:
#   GH_TOKEN, REPO, LABEL_CANDIDATE

echo "🔧 Fixing candidate labels..."

# Get all open PRs with candidate label (sorted by createdAt)
CANDIDATE_DATA=$(gh pr list --repo "$REPO" --label "$LABEL_CANDIDATE" --state open --json number,createdAt)
CANDIDATE_COUNT=$(echo "$CANDIDATE_DATA" | jq 'length')

if [ "$CANDIDATE_COUNT" -le 1 ]; then
    echo "✅ No fix needed (0 or 1 candidate)"
    exit 0
fi

echo "Found $CANDIDATE_COUNT candidates. Keeping only the oldest by creation date..."

# Get the oldest candidate by createdAt
OLDEST_CANDIDATE=$(echo "$CANDIDATE_DATA" | jq -r 'sort_by(.createdAt) | .[0].number')
echo "Keeping PR #$OLDEST_CANDIDATE as candidate (oldest by creation date)"

# Remove candidate label from all others
for PR in $(echo "$CANDIDATE_DATA" | jq -r '.[].number'); do
    if [ "$PR" != "$OLDEST_CANDIDATE" ]; then
        echo "Removing '$LABEL_CANDIDATE' from PR #$PR"
        gh pr edit "$PR" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" 2>/dev/null || true
    fi
done

echo "✅ Labels fixed"
