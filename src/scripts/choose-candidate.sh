#!/bin/bash
set -euo pipefail

# choose-candidate.sh
# Assigns the candidate label to the oldest queued PR if no candidate exists.
#
# Required env vars:
#   GH_TOKEN, REPO, LABEL_CANDIDATE, LABEL_QUEUE
# Optional env vars:
#   MERGED_PR - PR just merged; ignored because PR listings can lag behind the merge

echo "🔍 Checking for existing candidate..."

# Check if there's already a candidate
EXISTING_CANDIDATE=$(gh pr list --repo "$REPO" --label "$LABEL_CANDIDATE" --state open --json number --jq "[.[] | select(.number != ${MERGED_PR:-0})] | .[0].number // empty")

if [ -n "$EXISTING_CANDIDATE" ]; then
    echo "✅ PR #$EXISTING_CANDIDATE is already the candidate. Nothing to do."
    exit 0
fi

echo "📭 No candidate found. Looking for queued PRs..."

# Get oldest queued PR (sorted by created date, oldest first)
OLDEST_QUEUED=$(gh pr list --repo "$REPO" --label "$LABEL_QUEUE" --state open --json number,createdAt --jq "[.[] | select(.number != ${MERGED_PR:-0})] | sort_by(.createdAt) | .[0].number // empty")

if [ -n "$OLDEST_QUEUED" ]; then
    echo "✅ Assigning '$LABEL_CANDIDATE' to PR #$OLDEST_QUEUED"
    gh pr edit "$OLDEST_QUEUED" --repo "$REPO" --add-label "$LABEL_CANDIDATE" 2>/dev/null || true
else
    echo "📭 No queued PRs found. Queue is empty."
fi
