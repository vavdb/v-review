#!/usr/bin/env bash
# v-review — whole-repo audit survey.
#
# Produces the READING PLAN for an audit. It does not review anything; it
# tells you which files are worth reading end-to-end, and gives you the
# denominators you need to state coverage honestly.
#
# The ordering principle is risk x churn. Defects concentrate where change
# concentrates: a 900-line file nobody has touched in three years is a
# smaller risk than a 400-line file rewritten eleven times this year, even
# though the first one looks worse in a size ranking. The intersection of
# "big" and "churning" is where you start.
#
# Usage: scripts/repo-survey.sh [since] [top-n]
# Example: scripts/repo-survey.sh 1.year 40
#          scripts/repo-survey.sh 6.months 25

set -euo pipefail

SINCE="${1:-1.year}"
TOP="${2:-40}"

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "not a git repository" >&2
  exit 2
fi
cd "$(git rev-parse --show-toplevel)"

SRC_GLOBS=( '*.cs' '*.csx' '*.razor' '*.cshtml' '*.aspx' '*.ascx' '*.xaml' '*.axaml'
            '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.go' '*.rs' '*.java' '*.kt' '*.rb' '*.php' )
GENERATED=( ':(exclude)*.Designer.cs' ':(exclude)*.g.cs' ':(exclude)*.generated.cs'
            ':(exclude)*ModelSnapshot.cs' ':(exclude)*/obj/*' ':(exclude)*/bin/*'
            ':(exclude)*/node_modules/*' ':(exclude)*/dist/*' ':(exclude)*.min.js' )
SCOPE=( "${SRC_GLOBS[@]}" "${GENERATED[@]}" )

echo "==============================================================="
echo " Repo survey — reading plan for a whole-repo audit"
echo " window: $SINCE   top-n: $TOP"
echo "==============================================================="
echo ""

# ---------------------------------------------------------------------------
# 0. Denominators — you cannot state coverage without these
# ---------------------------------------------------------------------------
TOTAL_TRACKED=$(git ls-files | wc -l | tr -d ' ')
TOTAL_SRC=$(git ls-files -- "${SCOPE[@]}" | wc -l | tr -d ' ')
TOTAL_LINES=$(git ls-files -- "${SCOPE[@]}" | xargs -r wc -l 2>/dev/null | tail -1 | awk '{print $1}')
echo "--- Size of the problem ---"
echo "  tracked files:      $TOTAL_TRACKED"
echo "  source files:       $TOTAL_SRC"
echo "  source lines:       ${TOTAL_LINES:-unknown}"
echo ""
echo "  Report coverage against these numbers. An audit that reads 40 of"
echo "  $TOTAL_SRC files is a SAMPLE, and must say so."
echo ""

# ---------------------------------------------------------------------------
# 1. Churn — where change concentrates
# ---------------------------------------------------------------------------
echo "--- Churn: most-changed source files since $SINCE ---"
CHURN=$(git log --format= --name-only --since="$SINCE" -- "${SCOPE[@]}" 2>/dev/null \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -"$TOP" || true)
if [ -n "$CHURN" ]; then
  printf '%s\n' "$CHURN" | sed 's/^/  /'
else
  echo "  (no commits in window — widen it: $0 5.years)"
fi
echo ""

# ---------------------------------------------------------------------------
# 2. Size — god files
# ---------------------------------------------------------------------------
echo "--- Size: largest source files ---"
SIZES=$(git ls-files -- "${SCOPE[@]}" | xargs -r wc -l 2>/dev/null \
  | sort -rn | grep -v ' total$' | head -"$TOP" || true)
printf '%s\n' "$SIZES" | sed 's/^/  /'
echo ""

# ---------------------------------------------------------------------------
# 3. Hotspots — the intersection. START HERE.
# ---------------------------------------------------------------------------
echo "--- HOTSPOTS: big AND churning (read these end-to-end first) ---"
CHURN_FILES=$(printf '%s\n' "$CHURN" | awk '{print $2}' | sort -u)
SIZE_FILES=$(printf '%s\n' "$SIZES" | awk '{print $2}' | sort -u)
HOTSPOTS=$(comm -12 <(printf '%s\n' "$CHURN_FILES") <(printf '%s\n' "$SIZE_FILES") 2>/dev/null || true)
if [ -n "$HOTSPOTS" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    commits=$(printf '%s\n' "$CHURN" | awk -v f="$f" '$2==f {print $1}')
    printf '  %-60s %5s lines  %3s commits\n' "$f" "$lines" "${commits:-?}"
  done <<< "$HOTSPOTS"
else
  echo "  (no overlap between the two top-$TOP lists — widen top-n)"
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Always-read surface, regardless of churn
# ---------------------------------------------------------------------------
echo "--- Always read: security + wiring surface ---"
for pat in 'Program.cs' 'Startup.cs' '*DbContext.cs' '*appsettings*.json' \
           '*Auth*' '*Login*' '*Upload*' '*Permission*' '*Policy*' '*Token*'; do
  found=$(git ls-files -- "$pat" 2>/dev/null | head -8 || true)
  # `|| true` matters: without it, a pattern that matches nothing makes the
  # last command in the loop return 1, `set -e` kills the pipeline, and the
  # report silently truncates here — losing every section below.
  if [ -n "$found" ]; then printf '%s\n' "$found"; fi || true
done | sort -u | sed 's/^/  /' || true
echo ""

# ---------------------------------------------------------------------------
# 5. Dead zones — untouched for a long time
# ---------------------------------------------------------------------------
echo "--- Dead zones: source files with the oldest last-touch ---"
OLDEST=$( { git ls-files -- "${SCOPE[@]}" | while IFS= read -r f; do
  ts=$(git log -1 --format=%ct -- "$f" 2>/dev/null || echo 0)
  echo "$ts $f"
done | sort -n | head -15; } || true )
if [ -n "$OLDEST" ]; then
  while read -r ts f; do
    [ -z "$ts" ] && continue
    [ "$ts" = "0" ] && continue
    printf '  %s  %s\n' "$(date -d "@$ts" +%Y-%m-%d 2>/dev/null || echo '????-??-??')" "$f"
  done <<< "$OLDEST"
else
  echo "  (none)"
fi
echo ""
echo "  Old is not bad. Old + still-imported + no tests IS. Check which of"
echo "  these are actually reachable before spending reading budget on them."
echo ""

# ---------------------------------------------------------------------------
# 6. Debt markers — counts, not locations. These become audit THEMES.
# ---------------------------------------------------------------------------
echo "--- Debt markers (counts across the whole repo) ---"
count_of() {
  local label="$1"; shift
  local n
  # `|| true` inside the braces: git grep exits 1 when it matches nothing, and
  # `set -o pipefail` would propagate that and abort the report. A zero count
  # is a RESULT, not a failure.
  n=$( { git grep -cE "$1" -- "${SCOPE[@]}" 2>/dev/null || true; } | awk -F: '{s+=$NF} END {print s+0}')
  printf '  %-38s %s\n' "$label" "${n:-0}"
}
count_of "TODO / FIXME / HACK / XXX"        'TODO|FIXME|HACK|XXX'
count_of "empty or logging-only catch"      'catch[[:space:]]*\([^)]*\)[[:space:]]*\{[[:space:]]*\}'
count_of "analyzer suppressions"            '#pragma warning disable|SuppressMessage'
count_of "skipped / ignored tests"          '\[Ignore|Skip[[:space:]]*=|test\.skip|it\.skip|@pytest\.mark\.skip'
count_of "null-forgiving operator (C#)"     '![[:space:]]*[;),.]'
count_of "sync-over-async"                  '\.Result\b|\.Wait\(\)|GetAwaiter\(\)\.GetResult\(\)'
count_of "interpolated-string logging"      'Log(Information|Warning|Error|Debug|Critical)\([[:space:]]*\$"'
count_of "Console.WriteLine / console.log"  'Console\.WriteLine|console\.log'
count_of "IgnoreQueryFilters"               'IgnoreQueryFilters'
count_of "raw SQL execution"                'FromSqlRaw|ExecuteSqlRaw'
echo ""
echo "  These are THEME SEEDS, not findings. In an audit each becomes one"
echo "  aggregated entry — count, three exemplars, blast radius, fix order —"
echo "  never N individual findings."
echo ""

# ---------------------------------------------------------------------------
# 7. Test distribution
# ---------------------------------------------------------------------------
echo "--- Test distribution ---"
TEST_FILES=$( { git ls-files -- '*Test*' '*Tests*' '*.spec.*' '*_test.*' '*test_*' 2>/dev/null || true; } | wc -l | tr -d ' ')
echo "  test files: $TEST_FILES of $TOTAL_SRC source files"
echo ""
echo "  The number that matters is not the ratio — it is WHERE the tests are."
echo "  Cross-reference the hotspot list above: a hotspot with no test file"
echo "  next to it is the highest-value gap in the repo."
echo ""

echo "==============================================================="
echo " Next: read the hotspots end-to-end, then run the mechanical scans"
echo " in whole-repo mode:"
echo "     scripts/dup-scan.sh --repo"
echo "     scripts/literal-scan.sh --repo"
echo "     scripts/package-scan.sh --repo"
echo " Then aggregate into themes. Do NOT emit one finding per instance."
echo "==============================================================="
