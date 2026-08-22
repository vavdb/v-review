#!/usr/bin/env bash
# v-review preflight — dependency provenance (hunt #25).
#
# Every NuGet package the diff ADDS gets checked against nuget.org:
#
#   1. Does it exist at all?          -> CRITICAL if not (hallucinated package)
#   2. Is it the canonical name?      -> CRITICAL if a far more popular package
#                                        has a near-identical id (slopsquat)
#   3. Is it plausibly maintained?    -> flag low downloads / brand-new ids
#   4. Is it deprecated / unlisted?   -> flag
#   5. Is it version-pinned?          -> flag floating ranges and *
#
# WHY THIS IS NOT PARANOIA: current frontier models hallucinate package names
# in roughly 4.6%-6.1% of package-bearing answers, and ~43% of hallucinated
# names REPEAT across queries — which makes them predictable enough for an
# attacker to pre-register. `dotnet restore` succeeding proves nothing: a
# slopsquatted package resolves fine. That is the whole point of it.
#
# Scope: <PackageReference> and <PackageVersion> elements added in .csproj /
# .props / .targets files. Network access is required for the nuget.org
# queries; without it the script degrades to the offline checks and says so.
#
# Usage: scripts/package-scan.sh <base-ref> [--offline]
# Example: scripts/package-scan.sh origin/master

set -euo pipefail

BASE_REF="${1:-}"
OFFLINE=0
[ "${2:-}" = "--offline" ] && OFFLINE=1

if [ -z "$BASE_REF" ]; then
  echo "usage: $0 <base-ref> [--offline]" >&2
  echo "  e.g. $0 origin/master" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Base ref resolution — supports whole-repo audit mode
# ---------------------------------------------------------------------------
# `--repo` (or passing a tree-ish, e.g. the empty tree) audits the ENTIRE
# working tree instead of a diff: `git diff <empty-tree>` reports every
# tracked line as added, which is exactly "review everything" expressed in
# the same vocabulary the diff path already speaks.
REPO_MODE=0
if [ "$BASE_REF" = "--repo" ] || [ "$BASE_REF" = "--all" ]; then
  BASE_REF=$(git hash-object -t tree /dev/null)
  REPO_MODE=1
fi

if git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
  BASE_IS_COMMIT=1
elif git rev-parse --verify --quiet "$BASE_REF^{tree}" >/dev/null 2>&1; then
  BASE_IS_COMMIT=0
  REPO_MODE=1
else
  echo "base ref does not resolve: $BASE_REF" >&2
  echo "  pass a commit-ish (origin/master), a tree-ish, or --repo for a whole-repo audit" >&2
  exit 2
fi


REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

PROJ_PATHS=( '*.csproj' '*.props' '*.targets' '*.fsproj' '*.vbproj' )

# Same working-tree fallback as the other scans: v-review is used on staged and
# uncommitted diffs, and silently reporting "nothing to scan" over a dirty tree
# is exactly the quiet miss this skill exists to prevent.
DIFF_RANGE="$BASE_REF...HEAD"
if [ "$BASE_IS_COMMIT" -eq 0 ]; then
  # A tree-ish has no history tothree-dot against; a two-dot diff against the
  # working tree is the whole-repo view.
  DIFF_RANGE="$BASE_REF"
  echo "mode: WHOLE-REPO audit — every tracked line counts as new" >&2
  echo "" >&2
elif [ -z "$(git diff "$BASE_REF"...HEAD --name-only -- "${PROJ_PATHS[@]}" 2>/dev/null)" ] \
   && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo "$BASE_REF")
  DIFF_RANGE="$MERGE_BASE"
  echo "note: no committed project-file diff vs $BASE_REF — scanning the working tree (staged + unstaged) instead" >&2
  echo "" >&2
fi

ADDED=$(git diff "$DIFF_RANGE" --no-color -U0 -- "${PROJ_PATHS[@]}" \
  | grep -E '^\+' | grep -vE '^\+\+\+' || true)

if [ -z "$ADDED" ]; then
  echo "no project files found — no dependencies to scan"
  exit 0
fi

# id|version, one per line.
PKGS=$(
  printf '%s\n' "$ADDED" \
    | grep -oE '<Package(Reference|Version)[^>]*Include="[^"]+"[^>]*' \
    | sed -E 's/.*Include="([^"]+)".*[Vv]ersion="([^"]*)".*/\1|\2/; t; s/.*Include="([^"]+)".*/\1|/' \
    | sort -u \
    || true
)

if [ -z "$PKGS" ]; then
  echo "no new <PackageReference> / <PackageVersion> entries in the diff"
  exit 0
fi

if [ "$REPO_MODE" -eq 1 ]; then
  echo "=== All package references in the repo ==="
else
  echo "=== New package references in this diff ==="
fi
printf '%s\n' "$PKGS" | sed 's/|/  version: /' | sed 's/^/  /'
echo ""

# ---------------------------------------------------------------------------
# Offline checks — these run regardless of network
# ---------------------------------------------------------------------------
echo "=== Offline checks ==="
echo ""

CPM_FILE=""
for f in Directory.Packages.props directory.packages.props; do
  [ -f "$f" ] && CPM_FILE="$f" && break
done

OFFLINE_HITS=0
while IFS='|' read -r id ver; do
  [ -z "$id" ] && continue

  # Floating / wildcard / unpinned versions.
  case "$ver" in
    *'*'*)
      echo "  $id: version '$ver' is a WILDCARD — the build is not reproducible and a"
      echo "      future publish lands in your app without a diff. Pin it."
      OFFLINE_HITS=$((OFFLINE_HITS + 1))
      ;;
    '['*|'('*)
      echo "  $id: version '$ver' is a RANGE — same problem as a wildcard. Pin it."
      OFFLINE_HITS=$((OFFLINE_HITS + 1))
      ;;
  esac

  # Central Package Management: a version on the PackageReference is a smell
  # when the repo uses CPM, because it silently overrides the central pin.
  if [ -n "$CPM_FILE" ] && [ -n "$ver" ]; then
    if printf '%s\n' "$ADDED" | grep -q "<PackageReference[^>]*Include=\"$id\"[^>]*[Vv]ersion="; then
      echo "  $id: repo uses Central Package Management ($CPM_FILE) but this"
      echo "      <PackageReference> carries its own Version=\"$ver\" — that overrides"
      echo "      the central pin for this project only. Move it to $CPM_FILE."
      OFFLINE_HITS=$((OFFLINE_HITS + 1))
    fi
  fi
done <<< "$PKGS"

[ "$OFFLINE_HITS" -eq 0 ] && echo "  (no offline findings)"
echo ""

# ---------------------------------------------------------------------------
# Online checks — nuget.org
# ---------------------------------------------------------------------------
echo "=== nuget.org provenance ==="
echo ""

if [ "$OFFLINE" -eq 1 ]; then
  echo "  (skipped: --offline)"
  echo ""
  echo "  Existence and slopsquat checks did NOT run. Do them by hand before"
  echo "  approving: search nuget.org for each id above and confirm the owner,"
  echo "  the download count, and that no far-more-popular near-identical id exists."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "  (skipped: python3 not on PATH)"
  echo "  Check each package by hand on nuget.org — see hunt #25."
  exit 0
fi

PY_SRC=$(cat <<'PYEOF'
import json, sys, urllib.request, urllib.parse, difflib

SEARCH = "https://azuresearch-usnc.nuget.org/query?q={}&prerelease=true&take=20"

# Thresholds. Deliberately loose — this is a candidate list, and a noisy
# supply-chain scan gets ignored, which is worse than a quiet one.
LOW_DOWNLOADS = 10_000
LOOKALIKE_RATIO = 0.86      # difflib ratio above which two ids are "near-identical"
LOOKALIKE_FACTOR = 50       # other package must be this many times more popular

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "v-review-package-scan"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)

def norm(s):
    return s.lower().replace(".", "").replace("-", "").replace("_", "")

findings = 0
offline = False

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    pkg_id, _, version = line.partition("|")
    if not pkg_id:
        continue

    try:
        exact = fetch(SEARCH.format(urllib.parse.quote(f'packageid:"{pkg_id}"')))
    except Exception as e:
        print(f"  {pkg_id}: could not reach nuget.org ({type(e).__name__}) — check by hand")
        offline = True
        continue

    data = exact.get("data", [])
    match = next((d for d in data if d.get("id", "").lower() == pkg_id.lower()), None)

    if match is None:
        print(f"  {pkg_id}: *** DOES NOT EXIST ON NUGET.ORG ***")
        print(f"      CRITICAL. This is the hallucinated-package shape. Either the id is")
        print(f"      wrong, or the package is private — confirm which before approving.")
        print(f"      If a private feed supplies it, say so in the PR; a reviewer cannot")
        print(f"      tell 'internal package' from 'invented package' by reading the diff.")
        findings += 1
        print()
        continue

    downloads = match.get("totalDownloads", 0)
    owners = match.get("owners") or []
    verified = match.get("verified", False)
    versions = match.get("versions") or []

    line_out = f"  {pkg_id}: {downloads:,} downloads"
    if owners:
        line_out += f", owners: {', '.join(owners[:3])}"
    if verified:
        line_out += ", verified-prefix"
    print(line_out)

    # Version present in the feed?
    if version and versions:
        known = {v.get("version", "").lower() for v in versions}
        if version.lower() not in known and "*" not in version and not version.startswith(("[", "(")):
            print(f"      version {version} is NOT published — check the version string")
            findings += 1

    if downloads < LOW_DOWNLOADS:
        print(f"      low download count (<{LOW_DOWNLOADS:,}). Not damning on its own —")
        print(f"      new and niche packages are legitimate — but combined with an id")
        print(f"      that resembles a popular package it is the slopsquat signature.")
        findings += 1

    # Slopsquat check: is there a MUCH more popular package with a near-identical id?
    try:
        fuzzy = fetch(SEARCH.format(urllib.parse.quote(pkg_id)))
    except Exception:
        fuzzy = {"data": []}

    for other in fuzzy.get("data", []):
        oid = other.get("id", "")
        if oid.lower() == pkg_id.lower():
            continue
        odl = other.get("totalDownloads", 0)
        ratio = difflib.SequenceMatcher(None, norm(pkg_id), norm(oid)).ratio()
        if ratio >= LOOKALIKE_RATIO and odl > max(downloads, 1) * LOOKALIKE_FACTOR:
            print(f"      *** LOOKALIKE: '{oid}' has {odl:,} downloads ({ratio:.0%} similar id) ***")
            print(f"      Confirm which one you actually meant. This is the typosquat /")
            print(f"      slopsquat shape: a near-identical id with a fraction of the reach.")
            findings += 1
            break

    print()

print()
if offline:
    print("Some lookups failed — treat this scan as INCOMPLETE, not as a pass.")
if findings == 0:
    print("No provenance findings. Note this checks existence and popularity, NOT")
    print("whether the dependency is justified — that is hunt #3's question.")
else:
    print(f"{findings} provenance candidate(s). A package existing is not the same as a")
    print("package being the right one: slopsquatted packages exist by construction.")
PYEOF
)

printf '%s\n' "$PKGS" | python3 -c "$PY_SRC"
