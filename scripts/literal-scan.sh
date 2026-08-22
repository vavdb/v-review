#!/usr/bin/env bash
# v-review preflight — literal scan (hunt #21).
#
# Every string literal the diff ADDS gets three questions asked of it:
#
#   1. Does a BCL / framework constant already exist for this value?
#      ("nl" -> CultureInfo, "application/json" -> MediaTypeNames,
#       "Bearer" -> JwtBearerDefaults.AuthenticationScheme, ...)
#   2. Does THIS REPO already define it as a const / static readonly / enum?
#   3. Does it appear 2+ times in the repo (i.e. it is already a de-facto
#      constant that nobody extracted)?
#
# Any "yes" is a finding candidate. Agents re-type literals that the platform
# or the project already named, and the drift between the two copies is where
# the bug lands (see: [Authorize(Policy = "Admin")] vs the policy-registration
# string).
#
# Scope: C# / .NET source only — .cs .csx .razor .cshtml .aspx .ascx .asax
# .ashx .asmx .master .xaml .axaml. Generated output (.Designer.cs, .g.cs,
# *ModelSnapshot.cs, obj/, bin/) is excluded on both the diff side and the
# search side. A magic string in a .razor is the same finding as one in a .cs,
# which is why the markup dialects are in scope. A diff with no C# in it exits
# 0 with a message — walk hunt #21 by hand for other languages.
#
# Usage: scripts/literal-scan.sh <base-ref>
# Example: scripts/literal-scan.sh origin/master

set -euo pipefail

BASE_REF="${1:-}"
if [ -z "$BASE_REF" ]; then
  echo "usage: $0 <base-ref>" >&2
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
# tree instead and print a note saying so. A hardcoded policy name is worth
# catching before it is committed, not after.
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

ADDED=$(git diff "$DIFF_RANGE" --no-color -U0 -- "${CS_SCOPE[@]}" | grep -E '^\+' | grep -vE '^\+\+\+' || true)
if [ -z "$ADDED" ]; then
  if [ "$REPO_MODE" -eq 1 ]; then
    echo "no C#/.NET source in this repo — nothing to scan"
  else
    echo "no C#/.NET source added vs $BASE_REF — nothing to scan"
  fi
  echo "(scope: ${CS_PATHS[*]}; generated files excluded)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Pass 1 — known-standard literals that have a BCL home
# ---------------------------------------------------------------------------
# Format: <extended-regex>::<what to use instead>
# Delimiter is '::' — a bare '|' would collide with regex alternation.
KNOWN_PATTERNS=(
  '"[a-z]{2}-[A-Z]{2}"::CultureInfo.GetCultureInfo(...) — culture literal (BCP-47)'
  '"(nl|en|de|fr|es|it|pt|pl|sv|da|no|fi|cs|tr|ru|ja|zh|ko|ar)"::CultureInfo / .TwoLetterISOLanguageName — ISO 639-1 language literal'
  '"(EUR|USD|GBP|CHF|SEK|NOK|DKK|PLN|JPY|CAD|AUD)"::RegionInfo.ISOCurrencySymbol — ISO 4217 currency literal'
  '"(application|text|image|audio|video|multipart)/[a-zA-Z0-9.+-]+"::System.Net.Mime.MediaTypeNames.*'
  '"(Authorization|Content-Type|Accept|User-Agent|Cache-Control|If-None-Match|Location|Set-Cookie|X-Forwarded-For)"::Microsoft.Net.Http.Headers.HeaderNames.*'
  '"(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)"::HttpMethods.* / HttpMethod.*'
  '"(Bearer|Cookies|Identity.Application|Identity.External|OpenIdConnect|Negotiate)"::*Defaults.AuthenticationScheme (JwtBearerDefaults, CookieAuthenticationDefaults, ...)'
  '"(utf-8|UTF-8|utf8|us-ascii|iso-8859-1)"::System.Text.Encoding.*'
  '"(sub|role|roles|name|email|given_name|family_name|preferred_username|scope|aud|iss|exp|nbf|jti)"::ClaimTypes.* / JwtRegisteredClaimNames.*'
  '"(yyyy-MM-dd|yyyy-MM-ddTHH:mm:ss|dd-MM-yyyy|MM/dd/yyyy|HH:mm:ss)"::a named format const, or "o"/"R"/"s" round-trip specifiers'
  '"[A-Za-z. ]+ (Standard|Daylight) Time"::TimeZoneInfo.FindSystemTimeZoneById — .NET 6+ accepts BOTH Windows and IANA ids; hardcoding one form is a portability bug'
  '"[A-Za-z_]+/[A-Za-z_]+"[[:space:]]*\)::possible IANA timezone id — see TimeZoneInfo note above'
)

echo "=== Pass 1: literals with an existing BCL/framework constant ==="
echo ""

BCL_HITS=0
for entry in "${KNOWN_PATTERNS[@]}"; do
  pattern="${entry%%::*}"
  advice="${entry#*::}"
  hits=$(printf '%s\n' "$ADDED" | grep -oE "$pattern" | sort -u || true)
  if [ -n "$hits" ]; then
    echo "  ${advice}"
    printf '%s\n' "$hits" | sed 's/^/      /'
    echo ""
    BCL_HITS=$((BCL_HITS + 1))
  fi
done
[ "$BCL_HITS" -eq 0 ] && echo "  (no known-standard literals added)" && echo ""

# ---------------------------------------------------------------------------
# Pass 2 — literals the REPO already names
# ---------------------------------------------------------------------------
echo "=== Pass 2: literals this repo already defines as const/static/enum ==="
echo ""

# Collect distinct string literals added by this diff. Skip trivially short
# ones, pure whitespace, and format placeholders.
NEW_LITERALS=$(
  printf '%s\n' "$ADDED" \
    | grep -oE '"[^"]{3,60}"' \
    | sort -u \
    | grep -vE '^"[[:space:]]*"$' \
    | grep -vE '^"\{[0-9]+\}"$' \
    || true
)

# In whole-repo mode every literal in the codebase is "new", so the output
# needs a ceiling or it becomes wallpaper. The cap is ANNOUNCED, never silent:
# a truncated scan that reads as complete is worse than no scan.
MAX_REPORT=0
[ "$REPO_MODE" -eq 1 ] && MAX_REPORT=40

REPO_HITS=0
DUPE_HITS=0
SKIPPED=0
while IFS= read -r lit; do
  [ -z "$lit" ] && continue
  if [ "$MAX_REPORT" -gt 0 ] && [ "$((REPO_HITS + DUPE_HITS))" -ge "$MAX_REPORT" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  bare="${lit%\"}"
  bare="${bare#\"}"

  # 2a — is it already given a name somewhere?
  named=$(git grep -nE "(const|static readonly)[^=]*=[[:space:]]*${lit}" -- "${CS_SCOPE[@]}" 2>/dev/null | head -3 || true)
  if [ -n "$named" ]; then
    echo "  $lit is ALREADY NAMED:"
    printf '%s\n' "$named" | sed 's/^/      /'
    REPO_HITS=$((REPO_HITS + 1))
    continue
  fi

  # 2b — does an enum member carry this name? ("Active" vs Status.Active)
  if printf '%s' "$bare" | grep -qE '^[A-Z][A-Za-z0-9]*$'; then
    ENUM_FILES=$(git grep -lE '\benum[[:space:]]+[A-Za-z0-9_]+' -- "${CS_SCOPE[@]}" 2>/dev/null || true)
    enumhit=""
    if [ -n "$ENUM_FILES" ]; then
      enumhit=$(printf '%s\n' "$ENUM_FILES" \
        | xargs -r grep -HnE "([{,][[:space:]]*${bare}[[:space:]]*([=,}]|$)|^[[:space:]]*${bare}[[:space:]]*(=[^,]*)?,?[[:space:]]*$)" 2>/dev/null \
        | head -3 || true)
    fi
    if [ -n "$enumhit" ]; then
      echo "  $lit matches an ENUM MEMBER — string comparison where the enum belongs:"
      printf '%s\n' "$enumhit" | sed 's/^/      /'
      REPO_HITS=$((REPO_HITS + 1))
      continue
    fi
  fi

  # 2c — de-facto constant: same literal typed in 2+ places.
  count=$(git grep -cF "$lit" -- "${CS_SCOPE[@]}" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
  if [ "${count:-0}" -ge 2 ]; then
    echo "  $lit typed in ${count} places — de-facto constant, nobody extracted it:"
    git grep -nF "$lit" -- "${CS_SCOPE[@]}" 2>/dev/null | head -4 | sed 's/^/      /'
    DUPE_HITS=$((DUPE_HITS + 1))
  fi
done <<< "$NEW_LITERALS"

[ "$REPO_HITS" -eq 0 ] && [ "$DUPE_HITS" -eq 0 ] && echo "  (no repo-named or repeated literals added)"
if [ "$SKIPPED" -gt 0 ]; then
  echo ""
  echo "  *** TRUNCATED: $SKIPPED further literals not examined (cap: $MAX_REPORT). ***"
  echo "  This scan is INCOMPLETE. Treat the output as a sample, report it as a"
  echo "  sample, and re-run scoped to a subdirectory to see the rest."
fi
echo ""

# ---------------------------------------------------------------------------
# Pass 3 — nameof candidates
# ---------------------------------------------------------------------------
echo "=== Pass 3: nameof candidates ==="
echo "(string literals in positions that take a MEMBER name)"
echo ""

NAMEOF=$(
  printf '%s\n' "$ADDED" \
    | grep -nE '(ArgumentNullException|ArgumentException|ArgumentOutOfRangeException)\([^)]*"[A-Za-z0-9_]+"|\.(Include|ThenInclude|Property|HasIndex|HasKey|OwnsOne|Ignore)\([[:space:]]*"[A-Za-z0-9_.]+"|OnPropertyChanged\([[:space:]]*"[A-Za-z0-9_]+"|\[Display\(Name[[:space:]]*=[[:space:]]*"' \
    || true
)
if [ -n "$NAMEOF" ]; then
  printf '%s\n' "$NAMEOF" | sed 's/^/      /'
  echo ""
  echo "  -> use nameof(...) so a rename cannot silently break these."
else
  echo "  (none)"
fi
echo ""

# ---------------------------------------------------------------------------
# Pass 4 — authorization policy / role literal drift (security-relevant)
# ---------------------------------------------------------------------------
echo "=== Pass 4: policy / role literal drift ==="
echo ""

POLICY_LITS=$(
  printf '%s\n' "$ADDED" \
    | grep -oE '(Policy|Roles|Role)[[:space:]]*[=:][[:space:]]*"[^"]+"|AddPolicy\([[:space:]]*"[^"]+"|RequireRole\([[:space:]]*"[^"]+"|IsInRole\([[:space:]]*"[^"]+"' \
    | grep -oE '"[^"]+"' \
    | sort -u \
    || true
)
if [ -n "$POLICY_LITS" ]; then
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    echo "  $p"
    git grep -nF "$p" -- "${CS_SCOPE[@]}" 2>/dev/null | head -6 | sed 's/^/      /'
    echo ""
  done <<< "$POLICY_LITS"
  echo "  -> [Authorize(Policy=\"X\")] and AddPolicy(\"X\") drifting apart is a"
  echo "     SILENT authz failure (403 for everyone, or a policy that never runs)."
  echo "     Both sides must reference one const. Severity: HIGH minimum."
else
  echo "  (no policy/role literals added)"
fi
echo ""

echo "=== Reminder ==="
echo "Candidates, not findings. A literal used once, in one place, with no BCL"
echo "equivalent and no repo constant, is fine. Do not manufacture a constants"
echo "class for a single call site — that trades one problem for another."
