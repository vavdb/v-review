#!/usr/bin/env bash
# v-review preflight — hard precondition.
# Scans the diff against the given base ref for unresolved git conflict markers.
# Exits 0 with no output when the diff is clean.
# Exits 1 with the offending paths when conflict markers are found.
#
# Usage: scripts/conflict-marker-scan.sh <base-ref>
# Example: scripts/conflict-marker-scan.sh origin/master

set -euo pipefail

BASE_REF="${1:-}"
if [ -z "$BASE_REF" ]; then
  echo "usage: $0 <base-ref>" >&2
  echo "  e.g. $0 origin/master" >&2
  exit 2
fi

# Validate the base ref resolves to a commit. Fail loudly if not — a bad
# ref must NOT collapse to a silent "clean" verdict.
if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
  echo "base ref does not resolve: $BASE_REF" >&2
  exit 2
fi

# Look for lines the diff ADDS (lines starting with '+') that match the
# canonical conflict-marker shapes: <<<<<<< , ======= , >>>>>>>
# (Use the unambiguous 7-character form to avoid false positives on
# decoration banners or shell-style heredocs.)
CONFLICT_HITS=$(
  git diff "$BASE_REF"...HEAD --no-color 2>/dev/null \
    | grep -nE '^\+(<{7}|={7}|>{7})( |$)' \
    || true
)

if [ -z "$CONFLICT_HITS" ]; then
  exit 0
fi

echo "CONFLICT MARKERS PRESENT — refusing to review until resolved:" >&2
echo "" >&2
echo "$CONFLICT_HITS" >&2
exit 1
