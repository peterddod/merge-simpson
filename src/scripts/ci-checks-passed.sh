#!/bin/bash
set -euo pipefail

# ci-checks-passed.sh
# Checks if all required CI checks have passed for the PR.
# Sets output: checks_passed=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER

echo "🔍 Checking CI status for PR #$PR_NUMBER..."

# Get the check status - this will fail if checks are pending or failed
# --fail-fast exits on first failure, --required only checks required checks
if gh pr checks "$PR_NUMBER" --repo "$REPO" --required 2>/dev/null; then
    echo "✅ All required checks have passed"
    echo "checks_passed=true" >> "$GITHUB_OUTPUT"
else
    CHECK_STATUS=$?
    
    # Check if it's because checks are still running (pending)
    PENDING=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json state --jq '[.[] | select(.state == "PENDING" or .state == "IN_PROGRESS")] | length' 2>/dev/null || echo "0")
    
    if [ "$PENDING" -gt 0 ]; then
        echo "⏳ Checks are still running ($PENDING pending). Exiting to wait for workflow_run trigger."
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    else
        echo "❌ Some checks have failed"
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    fi
fi

