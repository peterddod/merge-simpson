#!/bin/bash
set -euo pipefail

# validate-fix-choose-candidate.sh
# Ensures exactly one PR has the candidate label. If none, assigns to oldest queued PR.
# 
# Required env vars:
#   GH_TOKEN, REPO, LABEL_CANDIDATE, LABEL_QUEUE

echo "🔍 Validating candidate labels..."

# Get all open PRs with candidate label
CANDIDATE_PRS=$(gh pr list --repo "$REPO" --label "$LABEL_CANDIDATE" --state open --json number --jq '.[].number' | tr '\n' ' ')
CANDIDATE_COUNT=$(echo "$CANDIDATE_PRS" | wc -w | tr -d ' ')

echo "Found $CANDIDATE_COUNT PR(s) with '$LABEL_CANDIDATE' label: $CANDIDATE_PRS"

if [ "$CANDIDATE_COUNT" -gt 1 ]; then
    echo "⚠️  Multiple candidates found. Fixing..."
    
    # Keep only the oldest candidate (first PR number when sorted ascending)
    OLDEST_CANDIDATE=$(echo "$CANDIDATE_PRS" | tr ' ' '\n' | grep -v '^$' | sort -n | head -1)
    echo "Keeping PR #$OLDEST_CANDIDATE as candidate"
    
    # Remove candidate label from all others
    for PR in $CANDIDATE_PRS; do
        if [ "$PR" != "$OLDEST_CANDIDATE" ]; then
            echo "Removing '$LABEL_CANDIDATE' from PR #$PR"
            gh pr edit "$PR" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" || true
        fi
    done
    
elif [ "$CANDIDATE_COUNT" -eq 0 ]; then
    echo "📭 No candidate found. Looking for queued PRs..."
    
    # Get oldest queued PR (sorted by created date, oldest first)
    OLDEST_QUEUED=$(gh pr list --repo "$REPO" --label "$LABEL_QUEUE" --state open --json number,createdAt --jq 'sort_by(.createdAt) | .[0].number // empty')
    
    if [ -n "$OLDEST_QUEUED" ]; then
        echo "✅ Assigning '$LABEL_CANDIDATE' to PR #$OLDEST_QUEUED"
        gh pr edit "$OLDEST_QUEUED" --repo "$REPO" --add-label "$LABEL_CANDIDATE"
    else
        echo "📭 No queued PRs found. Nothing to do."
    fi
else
    echo "✅ Exactly one candidate exists. Labels are valid."
fi

