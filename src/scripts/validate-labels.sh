#!/bin/bash
set -euo pipefail

# validate-labels.sh
# Validates that label state is correct (only one candidate).
# Returns exit code 0 if valid, 1 if invalid.
#
# Required env vars:
#   GH_TOKEN, REPO, LABEL_CANDIDATE

echo "🔍 Validating labels..."

# Get all open PRs with candidate label
CANDIDATE_COUNT=$(gh pr list --repo "$REPO" --label "$LABEL_CANDIDATE" --state open --json number --jq 'length')

if [ "$CANDIDATE_COUNT" -eq 0 ]; then
    echo "⚠️  No candidate PR found"
    exit 1
elif [ "$CANDIDATE_COUNT" -eq 1 ]; then
    echo "✅ Labels are valid (exactly one candidate)"
    exit 0
else
    echo "❌ Invalid: Multiple candidate PRs found ($CANDIDATE_COUNT)"
    exit 1
fi

