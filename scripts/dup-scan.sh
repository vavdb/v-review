#!/usr/bin/env bash
# v-review preflight — near-duplicate scan (hunt #19).
#
# Answers one question mechanically: does anything this diff ADDS already
# exist somewhere in the repo under a different name?
#
# Three passes, cheapest first:
#   1. Verb-synonym grep  — new method Verb+Noun vs every synonym of Verb.
#   2. Signature-shape    — same parameter-type sequence + return type.
#   3. Token-clone report — jscpd across changed files vs the WHOLE repo
#                           (optional: only runs when npx/jscpd is reachable).
#
# Passes 1 and 2 catch type-3 clones (same shape, one extra param / one
# extra null check / one different constant) that token-based detectors
# miss. Pass 3 catches type-1/2 (exact + renamed).
#
# Output is a candidate list, NOT a finding list. Every hit still needs a
# human/model side-by-side read to decide duplicate vs coincidence.
#
# Scope: C# / .NET source only — .cs .csx .razor .cshtml .aspx .ascx .asax
# .ashx .asmx .master .xaml .axaml. Generated output (.Designer.cs, .g.cs,
# *ModelSnapshot.cs, obj/, bin/) is excluded on both the diff side and the
# search side. A diff with no C# in it exits 0 with a message — walk hunt #19
# by hand for other languages.
#
# Usage: scripts/dup-scan.sh <base-ref> [--no-jscpd]
# Example: scripts/dup-scan.sh origin/master

set -euo pipefail

BASE_REF="${1:-}"
RUN_JSCPD=1
[ "${2:-}" = "--no-jscpd" ] && RUN_JSCPD=0

if [ -z "$BASE_REF" ]; then
  echo "usage: $0 <base-ref> [--no-jscpd]" >&2
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

# ---------------------------------------------------------------------------
# Scope: C# / .NET source only
# ---------------------------------------------------------------------------
# Both the diff side (what the change ADDS) and the search side (what the repo
# ALREADY has) are restricted to these. Everything here is a file a C# literal
# or method can actually live in — including the markup dialects, because a
# magic string in a .razor or .aspx is the same finding as one in a .cs.
#
# Generated output is excluded: it is not hand-written, so a duplicate or a
# literal in it is not a review finding. Hunt #14 covers hand-edits to those
# files separately.
CS_PATHS=(
  '*.cs' '*.csx'
  '*.razor' '*.cshtml' '*.razor.css'
  '*.aspx' '*.ascx' '*.asax' '*.ashx' '*.asmx' '*.master'
  '*.xaml' '*.axaml'
)
CS_EXCLUDES=(
  ':(exclude)*.Designer.cs'
  ':(exclude)*.designer.cs'
  ':(exclude)*.g.cs'
  ':(exclude)*.g.i.cs'
  ':(exclude)*.generated.cs'
  ':(exclude)*ModelSnapshot.cs'
  ':(exclude)*AssemblyInfo.cs'
  ':(exclude)*/obj/*'
  ':(exclude)*/bin/*'
)
CS_SCOPE=( "${CS_PATHS[@]}" "${CS_EXCLUDES[@]}" )

# Diff range. Default is BASE...HEAD (committed work only), matching scope.sh.
# v-review also runs against staged and uncommitted work, so when BASE...HEAD
# is empty and the tree is dirty, compare the merge-base against the working
# tree instead and print a note saying so. A duplicate that only exists in an
# uncommitted file is still a duplicate.
DIFF_RANGE="$BASE_REF...HEAD"
if [ "$BASE_IS_COMMIT" -eq 0 ]; then
  # A tree-ish has no history to three-dot against; a two-dot diff against the
  # working tree is the whole-repo view.
  DIFF_RANGE="$BASE_REF"
  echo "mode: WHOLE-REPO audit — every tracked line counts as new" >&2
  echo "" >&2
elif [ -z "$(git diff "$BASE_REF"...HEAD --name-only -- "${CS_SCOPE[@]}" 2>/dev/null)" ] \
   && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo "$BASE_REF")
  DIFF_RANGE="$MERGE_BASE"
  echo "note: no committed diff vs $BASE_REF — scanning the working tree (staged + unstaged) instead" >&2
  echo "" >&2
fi

CHANGED=$(git diff "$DIFF_RANGE" --name-only --diff-filter=ACMR -- "${CS_SCOPE[@]}" || true)
if [ -z "$CHANGED" ]; then
  if [ "$REPO_MODE" -eq 1 ]; then
    echo "no C#/.NET source in this repo — nothing to scan"
  else
    echo "no C#/.NET source changed vs $BASE_REF — nothing to scan"
  fi
  echo "(scope: ${CS_PATHS[*]}; generated files excluded)"
  exit 0
fi

# Added lines only. A method that already existed before this diff is not
# this diff's problem.
ADDED=$(git diff "$DIFF_RANGE" --no-color -U0 -- "${CS_SCOPE[@]}" | grep -E '^\+' | grep -vE '^\+\+\+' || true)

# ---------------------------------------------------------------------------
# Pass 1 — verb-synonym grep
# ---------------------------------------------------------------------------
# Each line is one synonym class. A new `IsCompanyOwner` must be checked
# against `HasCompanyOwner`, `CanCompanyOwner`, `VerifyCompanyOwner`,
# `CheckCompanyOwner`, `ValidateCompanyOwner`, `EnsureCompanyOwner` — the
# exact shape that made `UserBelongsToCompany` slip past review.
SYNONYM_CLASSES=(
  "Get Fetch Retrieve Load Read Lookup Resolve"
  "Save Persist Store Write Commit Flush"
  "Check Validate Verify Ensure Assert Is Has Can Should"
  "Build Create Make Construct New Initialize Init"
  "Convert Map Transform Parse Translate To From Project"
  "Delete Remove Purge Drop Clear Erase"
  "Update Modify Patch Set Apply Mutate"
  "List GetAll Query Search Find Filter Select Enumerate"
  "Send Publish Dispatch Emit Post Notify Raise"
  "Handle Process Execute Run Invoke Perform"
  "Add Insert Append Register Attach"
  "Calculate Compute Determine Derive Evaluate"
  "Format Render Print Display Stringify"
  "Normalize Sanitize Clean Scrub Strip Trim"
)

echo "=== Pass 1: verb-synonym candidates ==="
echo "(new method name on the left; pre-existing repo matches on the right)"
echo ""

# Extract PascalCase method-ish declarations from the added lines. Broad on
# purpose — over-collecting here is cheap, missing a duplicate is not.
NEW_METHODS=$(
  printf '%s\n' "$ADDED" \
    | grep -oE '\b[A-Z][A-Za-z0-9]{2,}[[:space:]]*\(' \
    | sed 's/[[:space:]]*($//; s/($//' \
    | tr -d '(' \
    | sort -u \
    || true
)

VERB_HITS=0
SEEN_PAIRS=""
while IFS= read -r method; do
  [ -z "$method" ] && continue

  # Split leading verb from the rest: IsCompanyOwner -> Is / CompanyOwner
  for class in "${SYNONYM_CLASSES[@]}"; do
    for verb in $class; do
      case "$method" in
        "$verb"?*)
          noun="${method#"$verb"}"
          # Nouns shorter than 4 chars produce noise, not signal.
          [ "${#noun}" -lt 4 ] && continue

          # Grep every OTHER verb in the same class against the same noun.
          for alt in $class; do
            [ "$alt" = "$verb" ] && continue
            hits=$(git grep -ln "\b${alt}${noun}\b" -- "${CS_SCOPE[@]}" 2>/dev/null || true)
            if [ -n "$hits" ]; then
              # Dedupe the pair. In whole-repo mode BOTH names are "new", so
              # without this every duplicate is reported twice, once from each
              # side, and the count doubles for no added information.
              pair=$(printf '%s\n%s\n' "$method" "${alt}${noun}" | sort | paste -sd'~' -)
              if ! printf '%s\n' "$SEEN_PAIRS" | grep -qxF "$pair"; then
                SEEN_PAIRS="${SEEN_PAIRS}
${pair}"
                echo "  $method  ~~  ${alt}${noun}"
                printf '%s\n' "$hits" | sed 's/^/      /'
                VERB_HITS=$((VERB_HITS + 1))
              fi
            fi
          done
          ;;
      esac
    done
  done
done <<< "$NEW_METHODS"

[ "$VERB_HITS" -eq 0 ] && echo "  (no verb-synonym collisions)"
echo ""

# ---------------------------------------------------------------------------
# Pass 2 — signature-shape collisions (C#-shaped, best-effort)
# ---------------------------------------------------------------------------
# Two methods with the same return type and the same parameter-type sequence
# are duplicate candidates regardless of what they are called.
echo "=== Pass 2: signature-shape candidates ==="
echo "(same return type + same parameter-type sequence, different names)"
echo ""

# Extract declarations from the added lines. No temp file — the signature
# list is small and a pipeline keeps cleanup out of the picture entirely.
NEW_SIGS=$(
  printf '%s\n' "$ADDED" \
    | grep -oE '(public|internal|private|protected)[[:space:]]+(static[[:space:]]+)?(async[[:space:]]+)?[A-Za-z0-9_<>,?\[\]]+[[:space:]]+[A-Za-z0-9_]+\([^)]*\)' \
    | sed -E 's/^(public|internal|private|protected)[[:space:]]+//; s/^static[[:space:]]+//; s/^async[[:space:]]+//' \
    | sort -u \
    || true
)

SIG_HITS=0
while IFS= read -r sig; do
  [ -z "$sig" ] && continue
  ret=$(printf '%s' "$sig" | awk '{print $1}')
  name=$(printf '%s' "$sig" | sed -E 's/^[^ ]+[[:space:]]+([A-Za-z0-9_]+)\(.*/\1/')
  [ "$ret" = "$name" ] && continue

  # Parameter TYPES only. Names are the part that differs between clones.
  ptypes=$(printf '%s' "$sig" \
    | sed -E 's/^[^(]*\((.*)\)$/\1/' \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]*//; s/[[:space:]]+[A-Za-z0-9_]+[[:space:]]*$//' \
    | paste -sd',' - || true)
  [ -z "$ptypes" ] && continue

  first_ptype=$(printf '%s' "$ptypes" | cut -d',' -f1)
  existing=$(git grep -nE "\b${ret}[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\(" -- "${CS_SCOPE[@]}" 2>/dev/null \
    | grep -vE "\b${name}[[:space:]]*\(" \
    | grep -F "$first_ptype" \
    | head -5 || true)
  if [ -n "$existing" ]; then
    echo "  $name  ->  $ret($ptypes)"
    printf '%s\n' "$existing" | sed 's/^/      /'
    SIG_HITS=$((SIG_HITS + 1))
  fi
done <<< "$NEW_SIGS"

[ "$SIG_HITS" -eq 0 ] && echo "  (no signature-shape collisions)"
echo ""

# ---------------------------------------------------------------------------
# Pass 3 — token clones (jscpd), changed files vs the whole repo
# ---------------------------------------------------------------------------
echo "=== Pass 3: token-clone report (jscpd) ==="
if [ "$RUN_JSCPD" -eq 0 ]; then
  echo "  (skipped: --no-jscpd)"
elif ! command -v npx >/dev/null 2>&1; then
  echo "  (skipped: npx not on PATH — install Node or run with --no-jscpd)"
else
  # --min-tokens 50 is the sweet spot for C#: below it, ctor boilerplate and
  # property blocks dominate the report and drown the real clones.
  npx --yes jscpd@latest . \
    --min-tokens 50 \
    --formats "csharp" \
    --reporters consoleFull \
    --ignore "**/node_modules/**,**/bin/**,**/obj/**,**/*.Designer.cs,**/*ModelSnapshot.cs,**/dist/**,**/.git/**" \
    2>/dev/null \
    || echo "  (jscpd unavailable or failed — walk hunt #19 by hand)"
fi
echo ""

echo "=== Reminder ==="
echo "These are CANDIDATES, not findings. For each hit, open both sides and"
echo "compare structure. Type-3 clones differ by one param, one null check,"
echo "or one constant — jscpd will not flag those. Passes 1 and 2 will."
echo "Anything >=70% structurally similar needs a stated reason both exist."
