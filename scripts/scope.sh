#!/usr/bin/env bash
# v-review preflight — scope.
# Prints the diff scope vs the given base ref: changed-file count, line
# stats, branch-name, and the file-level stat output.
#
# Usage: scripts/scope.sh <base-ref>
# Example: scripts/scope.sh origin/master

set -euo pipefail

BASE_REF="${1:-}"
if [ -z "$BASE_REF" ]; then
  echo "usage: $0 <base-ref>" >&2
  echo "  e.g. $0 origin/master" >&2
  exit 2
fi

# Parse REMOTE/BRANCH up front — the validation step below may need to
# fetch first (a fresh checkout might not have the remote-tracking ref
# yet), and the main fetch block below uses them too.
REMOTE="${BASE_REF%%/*}"
BRANCH="${BASE_REF#*/}"

# Validate the base ref resolves to a commit. Fail loudly if not — a bad
# ref must NOT print an empty scope and lull the reviewer into thinking
# the diff is trivial.
if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
  # Try to fetch in case the ref is a remote-tracking ref that hasn't
  # been fetched yet, then re-validate. If still missing, fail.
  if [ -n "${REMOTE:-}" ] && [ -n "${BRANCH:-}" ] && [ "$REMOTE" != "$BASE_REF" ]; then
    git fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null || true
  fi
  if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
    echo "base ref does not resolve: $BASE_REF" >&2
    exit 2
  fi
fi

# Fetch the base ref so the diff is against the latest remote state.
# Suppress fetch output; failures (offline, no remote) are non-fatal.
if [ -n "$REMOTE" ] && [ -n "$BRANCH" ] && [ "$REMOTE" != "$BASE_REF" ]; then
  git fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null || true
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
CURRENT_BRANCH="${CURRENT_BRANCH:-(detached: $(git rev-parse --short HEAD 2>/dev/null || echo unknown))}"

echo "Reviewing branch: $CURRENT_BRANCH"
echo "Base: $BASE_REF"
echo ""
echo "--- File-level stats ---"
git diff "$BASE_REF"...HEAD --stat
echo ""
echo "--- Changed files only ---"
git diff "$BASE_REF"...HEAD --name-only
