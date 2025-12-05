![Merge Simpson Banner](./assets/merge-simpson-banner.png)

# Merge Simpson 🍩

A GitHub-native merge queue that processes PRs sequentially using labels — no external services required.

## How It Works

1. **Queue** — Add the `mq-queue` label to a PR to join the queue
2. **Candidate** — The oldest queued PR becomes the candidate and receives `mq-candidate`
3. **Update** — The candidate is automatically rebased if behind the base branch
4. **Verify** — Waits for required CI checks to pass
5. **Merge** — If all checks pass, the PR is merged and the next candidate is selected

Only one PR is processed at a time. Non-candidate PRs have their workflows cancelled to save resources.

## Installation

Create `.github/workflows/merge-queue.yml` in your repository:

```yaml
name: Merge Queue

on:
  pull_request:
    types: [opened, synchronize, closed, labeled, unlabeled]
  check_suite:
    types: [completed]

concurrency:
  group: merge-queue-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  checks: read
  actions: write

jobs:
  merge-queue:
    runs-on: ubuntu-latest
    if: github.event.pull_request != null
    steps:
      - name: Run Merge Simpson
        uses: peterddod/merge-simpson@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration

| Input | Description | Required | Default |
|:------|:------------|:---------|:--------|
| `github-token` | GitHub token for API access | **Yes** | — |
| `label-queue` | Label to add PRs to the queue | No | `mq-queue` |
| `label-candidate` | Label for the current merge candidate | No | `mq-candidate` |

## Setup

### 1. Create Labels

Create these labels in your repository (Settings → Labels):

- `mq-queue` — Add this to PRs you want in the merge queue
- `mq-candidate` — Managed automatically by the action

### 2. Configure Branch Protection (Recommended)

In Settings → Branches → Branch protection rules:

- ✅ Require status checks to pass before merging
- ❌ Require branches to be up to date before merging *(let the action handle this)*

### 3. Required Permissions

The workflow needs these permissions:

- `contents: write` — To merge PRs
- `pull-requests: write` — To manage labels
- `checks: read` — To check CI status
- `actions: write` — To cancel non-candidate workflows

## Usage

1. Open a PR as normal
2. Add the `mq-queue` label when ready to merge
3. The action handles the rest automatically

## Behaviour

| Scenario | Action |
|:---------|:-------|
| PR added to queue | Oldest queued PR becomes candidate |
| Candidate is behind base | Automatically rebased |
| CI checks pending | Waits for completion |
| CI checks pass | PR is merged |
| CI checks fail | Candidate label removed, next PR selected |
| Merge conflicts | Candidate label removed, next PR selected |
| Non-candidate PR | Workflows cancelled |
| PR closed/merged | Labels cleaned up, next candidate selected |

## License

MIT
