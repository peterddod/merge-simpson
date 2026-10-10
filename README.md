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
      - name: Create GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          client-id: ${{ secrets.MERGE_SIMPSON_APP_CLIENT_ID }}
          private-key: ${{ secrets.MERGE_SIMPSON_APP_PRIVATE_KEY }}

      - name: Run Merge Simpson
        uses: peterddod/merge-simpson@v1
        with:
          github-token: ${{ steps.app-token.outputs.token }}
```

## Configuration

| Input | Description | Required | Default |
|:------|:------------|:---------|:--------|
| `github-token` | Token for all writes (update branch, labels, merge). Use a GitHub App token or fine-grained PAT — see [Token](#token) | No | `GITHUB_TOKEN` (with a warning) |
| `label-queue` | Label to add PRs to the queue | No | `mq-queue` |
| `label-candidate` | Label for the current merge candidate | No | `mq-candidate` |

## Token

Events caused by the default `GITHUB_TOKEN` do not trigger workflows. If the action writes with it, a branch it updates gets no CI run, and a PR it promotes to candidate is never woken up, so the queue stalls until something else touches the repo. Give the action a GitHub App installation token (recommended) or a fine-grained PAT instead. Without one, it falls back to `GITHUB_TOKEN` and logs a warning.

### GitHub App setup

1. **Create the App:** Settings → Developer settings → GitHub Apps → New GitHub App (or https://github.com/settings/apps/new).
   - Name: anything unique, e.g. `merge-simpson-<your-user>`. Homepage URL: your repo URL.
   - Webhook: untick **Active**.
   - Repository permissions:
     - **Contents:** Read and write (merge, update branch, delete branch)
     - **Pull requests:** Read and write (labels, merge)
     - **Workflows:** Read and write (needed to update or merge a branch whose diff touches `.github/workflows/`)
     - **Checks:** Read-only
     - **Commit statuses:** Read-only
     - **Actions:** Read-only. Don't grant write: the cancel step would then cancel CI on PRs that aren't queued.
     - **Metadata:** Read-only (mandatory)
   - Where can this GitHub App be installed: **Only on this account**.
2. **Get the credentials:** on the App's settings page, copy the **Client ID** and click **Generate a private key** (it downloads a `.pem` file).
3. **Install the App:** on the App's page, go to Install App → your account → **Only select repositories** → pick this repo.
4. **Add the repository secrets:**
   ```sh
   gh secret set MERGE_SIMPSON_APP_CLIENT_ID --repo <owner>/<repo> --body '<client id>'
   gh secret set MERGE_SIMPSON_APP_PRIVATE_KEY --repo <owner>/<repo> < path/to/app.private-key.pem
   ```

Alternatively, a fine-grained PAT scoped to the repo with the same permissions works: store it as a secret and pass it as `github-token`.

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
