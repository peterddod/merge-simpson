#!/bin/bash
set -euo pipefail

# pr-is-mergeable.sh
# Checks if the PR is mergeable (checks passed, approved, no conflicts).
# If not mergeable, removes candidate label.
# Sets output: is_mergeable=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER, LABEL_CANDIDATE, LABEL_QUEUE

echo "🔍 Checking if PR #$PR_NUMBER is mergeable..."

# Get PR details
PR_DATA=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json mergeable,mergeStateStatus,reviewDecision)

MERGEABLE=$(echo "$PR_DATA" | jq -r '.mergeable')
MERGE_STATE=$(echo "$PR_DATA" | jq -r '.mergeStateStatus')
REVIEW_DECISION=$(echo "$PR_DATA" | jq -r '.reviewDecision // "NONE"')

echo "  Mergeable: $MERGEABLE"
echo "  Merge State: $MERGE_STATE"
echo "  Review Decision: $REVIEW_DECISION"

# Check conditions for mergeability
IS_MERGEABLE=true
REASON=""

if [ "$MERGEABLE" != "MERGEABLE" ]; then
    IS_MERGEABLE=false
    REASON="PR has merge conflicts or is not mergeable ($MERGEABLE)"
fi

if [ "$MERGE_STATE" = "DIRTY" ]; then
    IS_MERGEABLE=false
    REASON="PR has merge conflicts"
fi

if [ "$MERGE_STATE" = "BLOCKED" ]; then
    IS_MERGEABLE=false
    REASON="PR is blocked by branch protection rules"
fi

if [ "$MERGE_STATE" = "UNSTABLE" ]; then
    IS_MERGEABLE=false
    REASON="PR has failing checks"
fi

# Note: We don't check reviewDecision here as it depends on repo settings
# The merge will fail if reviews are required and not met

if [ "$IS_MERGEABLE" = true ]; then
    echo "✅ PR #$PR_NUMBER is mergeable"
    echo "is_mergeable=true" >> "$GITHUB_OUTPUT"
else
    echo "❌ PR #$PR_NUMBER is NOT mergeable: $REASON"
    echo "🏷️  Removing candidate label..."
    gh pr edit "$PR_NUMBER" --repo "$REPO" --remove-label "$LABEL_CANDIDATE" 2>/dev/null || true
    echo "is_mergeable=false" >> "$GITHUB_OUTPUT"
fi

