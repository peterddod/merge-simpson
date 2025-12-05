#!/bin/bash

log() { echo -e "\033[1;35m[SELECTOR]\033[0m $1"; }

# Double-check lock (Race condition safety)
CURRENT_LOCK=$(gh pr list --repo "$REPO" --label "$LABEL_NEXT" --state open --limit 1)
if [ ! -z "$CURRENT_LOCK" ]; then
    log "Lock is currently held. Exiting."
    exit 0
fi

log "Scanning $LABEL_QUEUE..."

# Fetch Candidates
CANDIDATES=$(gh pr list --repo "$REPO" --label "$LABEL_QUEUE" --state open --json number,labels,createdAt,mergeable)
COUNT=$(echo "$CANDIDATES" | jq length)

if [ "$COUNT" -eq 0 ]; then
    log "Queue is empty. Resting."
    exit 0
fi

log "Found $COUNT candidate(s) in queue."

# SELECTION ALGORITHM
# 1. Must not be CONFLICTING
# 2. Priority Label First
# 3. Oldest First
WINNER=$(echo "$CANDIDATES" | jq -r '
    map(select(.mergeable != "CONFLICTING" and .mergeable != null)) |
    sort_by([
        ((.labels // []) | map(.name) | contains(["'"$LABEL_PRIORITY"'"]) | not),
        .createdAt
    ]) |
    if length > 0 then .[0].number else null end
')

if [ "$WINNER" == "null" ] || [ -z "$WINNER" ]; then
    log "No eligible candidates (all have conflicts or invalid state). Waiting."
    exit 0
fi

log "🏆 Selected PR #$WINNER."

# Apply Lock
gh pr edit "$WINNER" --repo "$REPO" --add-label "$LABEL_NEXT"
gh pr comment "$WINNER" --repo "$REPO" --body "🚂 **Merge Simpson**: You are next in line. Updating branch..."

# Update Branch
if gh pr update-branch "$WINNER" --repo "$REPO"; then
    log "Branch updated. Logic hands off to CI."
else
    log "Failed to update branch. Kicking."
    gh pr edit "$WINNER" --repo "$REPO" --remove-label "$LABEL_NEXT,$LABEL_QUEUE"
    gh pr comment "$WINNER" --repo "$REPO" --body "🚨 **Merge Simpson**: Update branch failed. Please resolve conflicts."
    # We exit here; the next check_suite or push will re-trigger the queue
fi

