#!/bin/bash
set -euo pipefail

# pr-is-candidate.sh
# Checks if the current PR has the candidate label.
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
    echo "⏸️  PR #$PR_NUMBER is NOT the candidate. Skipping merge queue processing."
    echo "is_candidate=false" >> "$GITHUB_OUTPUT"
fi

