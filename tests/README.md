# Merge Simpson Tests

This directory contains tests for the Merge Simpson action.

## Structure

```
tests/
├── unit/           # Unit tests for bash scripts
├── integration/    # Integration tests with mocked GitHub API
├── fixtures/       # Mock data and API responses
└── README.md       # This file
```

## Running Tests

Tests can be run using [bats-core](https://github.com/bats-core/bats-core):

```bash
# Install bats (macOS)
brew install bats-core

# Run all tests
bats tests/unit/*.bats

# Run specific test file
bats tests/unit/test-select-next.bats
```

## Test Coverage Goals

### Unit Tests (`tests/unit/`)

- **test-select-next.bats** - Tests for `src/select-next.sh`
  - Priority PR selection
  - CONFLICTING PR filtering
  - Null/invalid mergeable state handling
  - Empty queue handling
  - Race condition lock checks

- **test-check-active.bats** - Tests for `src/check-active.sh`
  - No active lock scenario
  - PR state transitions (BEHIND → update → wait)
  - CI check status parsing
  - Merge success/failure handling
  - Failed CI kick logic
  - No CI checks scenario

### Integration Tests (`tests/integration/`)

- End-to-end workflow tests with mocked GitHub API
- Label event handling
- Check suite completion handling
- Queue concurrency tests

### Fixtures (`tests/fixtures/`)

- Mock `gh` CLI responses
- Sample PR JSON structures
- Sample check-runs API responses
- Various mergeable state examples

