#!/bin/bash
set -euo pipefail

# ci-checks-passed.sh
# Checks if all required CI checks have passed for the PR.
# If no checks are required, waits for all checks except this workflow's own.
# Sets output: checks_passed=true/false
#
# Required env vars:
#   GH_TOKEN, REPO, PR_NUMBER, GITHUB_WORKFLOW

echo "🔍 Checking CI status for PR #$PR_NUMBER..."

# First, check if there are any required checks configured
CHECK_COUNT=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --required --json state --jq 'length' 2>/dev/null || echo "0")

if [ "$CHECK_COUNT" -eq 0 ]; then
    # No required checks: wait for every check on the PR except this workflow's own
    echo "ℹ️  No required checks configured — waiting for all checks except '$GITHUB_WORKFLOW'"
    ALL_CHECKS=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,bucket,workflow 2>/dev/null) || true
    OTHER_CHECKS=$(echo "${ALL_CHECKS:-[]}" | jq --arg self "$GITHUB_WORKFLOW" '[.[] | select(.workflow != $self)]')
    TOTAL=$(echo "$OTHER_CHECKS" | jq 'length')
    FAILED=$(echo "$OTHER_CHECKS" | jq '[.[] | select(.bucket == "fail" or .bucket == "cancel")] | length')
    PENDING=$(echo "$OTHER_CHECKS" | jq '[.[] | select(.bucket == "pending")] | length')

    # Workflow runs that are queued or awaiting approval report no checks yet, so count them too
    HEAD_SHA=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefOid --jq '.headRefOid')
    OTHER_RUNS=$(gh run list --repo "$REPO" --commit "$HEAD_SHA" --json workflowName,status,conclusion \
        | jq --arg self "$GITHUB_WORKFLOW" '[.[] | select(.workflowName != $self)]')
    FAILED=$((FAILED + $(echo "$OTHER_RUNS" | jq '[.[] | select(.status == "completed" and (.conclusion | IN("failure", "cancelled", "timed_out", "startup_failure")))] | length')))
    PENDING=$((PENDING + $(echo "$OTHER_RUNS" | jq '[.[] | select(.status != "completed" or .conclusion == "action_required")] | length')))
    TOTAL=$((TOTAL + $(echo "$OTHER_RUNS" | jq 'length')))

    if [ "$TOTAL" -eq 0 ]; then
        echo "⏳ No checks reported yet. Waiting for CI to start..."
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    elif [ "$FAILED" -gt 0 ]; then
        echo "❌ Some checks have failed"
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    elif [ "$PENDING" -gt 0 ]; then
        echo "⏳ Checks are still running ($PENDING pending). Waiting for completion..."
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    else
        echo "✅ All checks and workflow runs have passed ($TOTAL)"
        echo "checks_passed=true" >> "$GITHUB_OUTPUT"
    fi
    exit 0
fi

echo "Found $CHECK_COUNT required check(s)"

# Get the check status - this will fail if checks are pending or failed
if gh pr checks "$PR_NUMBER" --repo "$REPO" --required 2>/dev/null; then
    echo "✅ All required checks have passed"
    echo "checks_passed=true" >> "$GITHUB_OUTPUT"
else
    # Check if it's because checks are still running (pending)
    PENDING=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --required --json state --jq '[.[] | select(.state == "PENDING" or .state == "IN_PROGRESS")] | length' 2>/dev/null || echo "0")
    
    if [ "$PENDING" -gt 0 ]; then
        echo "⏳ Checks are still running ($PENDING pending). Waiting for completion..."
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    else
        echo "❌ Some checks have failed"
        echo "checks_passed=false" >> "$GITHUB_OUTPUT"
    fi
fi
