#!/bin/bash

# Set up logging functions
log() { echo -e "\033[1;34m[CHECK-ACTIVE]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

log "Checking for existing lock ($LABEL_NEXT)..."

# Fetch the PR currently holding the lock
LOCKED_PR_JSON=$(gh pr list --repo "$REPO" --label "$LABEL_NEXT" --state all --json number,state,mergeable,mergeStateStatus,headRefName,headRefOid,labels --limit 1 | jq '.[0]')

# DEFAULT: Assume queue is busy unless we explicitly find it empty or clear it
QUEUE_FREE="false"

if [ "$LOCKED_PR_JSON" == "null" ]; then
  log "No active lock found."
  QUEUE_FREE="true"
else
  PR_NUM=$(echo "$LOCKED_PR_JSON" | jq '.number')
  PR_STATE=$(echo "$LOCKED_PR_JSON" | jq -r '.state')
  PR_HEAD_SHA=$(echo "$LOCKED_PR_JSON" | jq -r '.headRefOid')
  PR_MERGE_STATUS=$(echo "$LOCKED_PR_JSON" | jq -r '.mergeStateStatus')

  log "Queue is LOCKED by PR #$PR_NUM (State: $PR_STATE, MergeStatus: $PR_MERGE_STATUS)"

  # 1. Handle Closed/Merged PRs externally
  if [ "$PR_STATE" != "OPEN" ]; then
    log "PR #$PR_NUM is closed/merged but still has lock. Cleaning up..."
    gh pr edit "$PR_NUM" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE,$LABEL_PRIORITY"
    log "Lock released."
    QUEUE_FREE="true"
  elif [ "$PR_MERGE_STATUS" == "BEHIND" ]; then
    log "PR #$PR_NUM is behind main. Updating..."
    if gh pr update-branch "$PR_NUM" --repo "$REPO"; then
      log "Branch updated. Waiting for CI."
      QUEUE_FREE="false"
    else
      log "Failed to update branch (Conflict?). Kicking."
      gh pr comment "$PR_NUM" --repo "$REPO" --body "🚨 **Merge Simpson**: Update branch failed (Conflict). Removing from queue."
      gh pr edit "$PR_NUM" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE"
      QUEUE_FREE="true"
    fi
  else
    # 2. Check CI Status
    log "Checking CI status for PR #$PR_NUM..."
    
    CHECKS_JSON=$(gh api "repos/$REPO/commits/$PR_HEAD_SHA/check-runs" --jq '.check_runs')

    # Filter self (Merge Simpson) out of checks to avoid circular waits
    RELEVANT_CHECKS=$(echo "$CHECKS_JSON" | jq '[.[] | select(.name | contains("Merge Simpson") | not)]')
    FAILURES=$(echo "$RELEVANT_CHECKS" | jq '[.[] | select(.conclusion == "failure" or .conclusion == "timed_out")] | length')
    PENDING=$(echo "$RELEVANT_CHECKS" | jq '[.[] | select(.status == "in_progress" or .status == "queued")] | length')
    TOTAL=$(echo "$RELEVANT_CHECKS" | jq 'length')

    if [ "$FAILURES" -gt 0 ]; then
      log "PR #$PR_NUM failed CI. Kicking."
      gh pr comment "$PR_NUM" --repo "$REPO" --body "🚨 **Merge Simpson**: CI checks failed. Removing from queue."
      gh pr edit "$PR_NUM" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE"
      QUEUE_FREE="true"
    elif [ "$PENDING" -gt 0 ]; then
      log "PR #$PR_NUM is still running CI. Waiting."
      QUEUE_FREE="false"
    elif [ "$TOTAL" -eq 0 ]; then
      log "PR #$PR_NUM has no checks yet. Waiting for CI to spawn."
      QUEUE_FREE="false"
    else
      log "PR #$PR_NUM passed all checks. Merging..."
      if gh pr merge "$PR_NUM" --repo "$REPO" --merge --auto; then
        log "Merge initiated."
        gh pr edit "$PR_NUM" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE,$LABEL_PRIORITY"
        QUEUE_FREE="true"
      else
        err "Merge failed (Conflict?). Kicking."
        gh pr comment "$PR_NUM" --repo "$REPO" --body "🚨 **Merge Simpson**: Merge failed. Removing from queue."
        gh pr edit "$PR_NUM" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE"
        QUEUE_FREE="true"
      fi
    fi
  fi
fi

echo "queue_free=$QUEUE_FREE" >> $GITHUB_OUTPUT

