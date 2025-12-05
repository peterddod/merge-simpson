#!/bin/bash
set -euo pipefail

# pr-is-candidate.sh
# Checks if the current PR has the candidate label.
# If not the candidate, cancels any running workflows for this PR.
# Sets output: is_candidate=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER, LABEL_CANDIDATE

echo "🔍 Checking if PR #$PR_NUMBER is the candidate..."

# Get labels for this PR
LABELS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json labels --jq '.labels[].name' 2>/dev/null || echo "")

if echo "$LABELS" | grep -q "^${LABEL_CANDIDATE}$"; then
    echo "✅ PR #$PR_NUMBER is the candidate"
    echo "is_candidate=true" >> "$GITHUB_OUTPUT"
else
    echo "⏸️  PR #$PR_NUMBER is NOT the candidate."
    echo "is_candidate=false" >> "$GITHUB_OUTPUT"
    
    # Cancel other running workflows for this PR (except the current one)
    echo "🛑 Cancelling other workflows for this PR..."
    
    # Get the head SHA for this PR to find related workflow runs
    HEAD_SHA=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefOid --jq '.headRefOid' 2>/dev/null || echo "")
    
    if [ -n "$HEAD_SHA" ]; then
        # Find and cancel in-progress workflow runs for this commit (except current)
        CURRENT_RUN_ID="${GITHUB_RUN_ID:-}"
        
        gh run list --repo "$REPO" --commit "$HEAD_SHA" --status in_progress --json databaseId --jq '.[].databaseId' 2>/dev/null | while read -r RUN_ID; do
            if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "$CURRENT_RUN_ID" ]; then
                echo "  Cancelling workflow run #$RUN_ID"
                gh run cancel "$RUN_ID" --repo "$REPO" 2>/dev/null || true
            fi
        done
        
        echo "✅ Workflow cancellation complete"
    fi
fi
