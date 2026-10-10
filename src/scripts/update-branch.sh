#!/bin/bash
set -euo pipefail

# update-branch.sh
# Updates the PR branch with the latest base branch if needed.
# Sets output: updated=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER

echo "🔄 Checking if PR #$PR_NUMBER needs to be updated..."

# Check if the PR branch is behind the base branch
PR_DATA=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json mergeStateStatus,baseRefName,headRefOid)
MERGE_STATE=$(echo "$PR_DATA" | jq -r '.mergeStateStatus')
BASE_REF=$(echo "$PR_DATA" | jq -r '.baseRefName')
HEAD_SHA=$(echo "$PR_DATA" | jq -r '.headRefOid')
echo "Current merge state: $MERGE_STATE"

# GitHub only reports BEHIND when branch protection requires branches to be
# up to date, so ask the compare API how far behind the base the head is.
BEHIND_BY=$(gh api "repos/$REPO/compare/${BASE_REF}...${HEAD_SHA}" --jq '.behind_by')
echo "Commits behind $BASE_REF: $BEHIND_BY"

# Check if branch is behind (needs update)
# BEHIND = branch is behind base, needs update
# DIRTY = has conflicts
# BLOCKED = blocked by branch protection
# CLEAN = ready to merge
# UNSTABLE = checks failing
# HAS_HOOKS = has pre-merge hooks

if [ "$MERGE_STATE" = "BEHIND" ] || [ "$BEHIND_BY" -gt 0 ]; then
    echo "📥 Branch is behind. Updating with base branch..."
    
    if gh pr update-branch "$PR_NUMBER" --repo "$REPO"; then
        echo "✅ Branch updated successfully. Exiting to let new workflow run."
        echo "updated=true" >> "$GITHUB_OUTPUT"
    else
        echo "❌ Failed to update branch"
        echo "updated=false" >> "$GITHUB_OUTPUT"
        exit 1
    fi
else
    echo "✅ Branch is up to date with base"
    echo "updated=false" >> "$GITHUB_OUTPUT"
fi

