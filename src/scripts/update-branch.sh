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
MERGE_STATE=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json mergeStateStatus --jq '.mergeStateStatus')
echo "Current merge state: $MERGE_STATE"

# Check if branch is behind (needs update)
# BEHIND = branch is behind base, needs update
# DIRTY = has conflicts
# BLOCKED = blocked by branch protection
# CLEAN = ready to merge
# UNSTABLE = checks failing
# HAS_HOOKS = has pre-merge hooks

if [ "$MERGE_STATE" = "BEHIND" ]; then
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

