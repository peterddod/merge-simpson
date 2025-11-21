# Merge Simpson 🍩

**Merge Simpson** is a zero-config, GitHub-native Merge Queue Action. It orchestrates your Pull Requests to ensure they are merged sequentially and safely, preventing broken main branches.

It runs entirely as a GitHub Action—no external services, webhooks, or servers required.

## How It Works

1.  **Queue**: You label a PR (e.g., `mq-queue`).
2.  **Lock**: The action picks the oldest valid PR from the queue, locks it (adds `mq-next`), and updates it with the latest `main`.
3.  **Verify**: It waits for your existing CI checks to pass.
4.  **Merge**: If CI passes, it merges the PR and picks the next one. If CI fails, it kicks the PR out of the queue.

## Installation

Create a workflow file (e.g., `.github/workflows/merge-queue.yml`) in your repository:

```yaml
name: Merge Queue

on:
  pull_request:
    types: [labeled, synchronized, unlabeled]
  check_suite:
    types: [completed]
  workflow_dispatch:

concurrency:
  group: merge_simpson_queue
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  checks: read
  statuses: read
  issues: write

jobs:
  merge-queue:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Merge Simpson
        uses: peterdodd/merge-simpson@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration

| Input | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `github-token` | Your `GITHUB_TOKEN` to allow the action to manage PRs. | **Yes** | N/A |
| `label-queue` | Label to add to a PR to join the queue. | No | `mq-queue` |
| `label-next` | Internal label used to lock the current PR. | No | `mq-next` |
| `label-priority` | Label to give a PR priority (jumps to front of queue). | No | `mq-priority` |

## Setup

1.  **Create Labels**: Ensure the labels (default: `mq-queue`, `mq-next`, `mq-priority`) exist in your repository.
2.  **Protect Main**: It is recommended to require status checks to pass before merging, but **disable** "Require branches to be up to date" if you want this action to handle the updates for you.

## License

MIT

