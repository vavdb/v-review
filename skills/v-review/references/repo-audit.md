# Whole-repo audit mode — reference

Load this when the ask is "audit this codebase" / "scan the whole repo" /
"where's the tech debt" / "I'm onboarding, what's here" / "survey before we
refactor" — anything that is **not** scoped to a diff.

## The posture change, stated plainly

Diff mode asks: *should this change land?* Audit mode asks: *what is true
about this codebase, and what should we do about it first?*

Same 28 hunts, different unit of output, and **three rules invert**:

| Diff mode | Audit mode |
|---|---|
| "Out of scope: pre-existing code outside the diff" | Pre-existing code **is** the subject |
| "Pre-existing code isn't in *this* diff" (Rationalizations) | Suspended — that rationalization exists to stop scope creep in a PR, and there is no PR here |
| Apply mechanical fixes, stage them | **Do not apply fixes.** See below |
| One finding per instance | One **theme** per pattern, with counts and exemplars |

State the mode in the first line of the output. A reader who sees findings
against untouched files needs to know immediately that this was deliberate.

## Do not apply fixes

Diff mode stages mechanical fixes because the user wants to see the result.
Repo-wide, the same behaviour produces a 10,000-line diff across 300 files
that nobody can review, the same artifact v-review refuses to accept from
other people. Applying it to yourself is not an exception.

What to produce instead: a prioritised plan, plus **one exemplar fix per
theme** if asked. The exemplar proves the pattern and makes the rest
mechanical for whoever picks it up.

## Sequence

### 1. Survey before reading anything

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/repo-survey.sh [since] [top-n]
# e.g. repo-survey.sh 1.year 40
```

Gives you: total file and line counts (the denominators for your coverage
statement), churn ranking, size ranking, the **hotspot intersection**,
always-read security surface, dead zones, debt-marker counts, and test
distribution.

The ordering principle is **risk × churn**. Defects concentrate where change
concentrates: a 900-line file untouched for three years is a smaller risk
than a 400-line file rewritten eleven times this year, even though the first
one looks worse in a size ranking. Read the intersection first.

### 2. Read the hotspots end-to-end

Plus, regardless of churn: `Program.cs` / startup wiring, DI registration,
auth configuration, migrations, upload paths, external API clients. These are
where a single defect has the widest blast radius.

### 3. Run the mechanical scans in whole-repo mode

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/dup-scan.sh --repo
${CLAUDE_PLUGIN_ROOT}/scripts/literal-scan.sh --repo
${CLAUDE_PLUGIN_ROOT}/scripts/package-scan.sh --repo
```

`--repo` diffs against the empty tree, so every tracked line counts as new.
Two things change in this mode:

- **`dup-scan.sh`'s jscpd pass gets far more valuable.** In diff mode it
  compares a handful of changed files; here it finds clone *clusters* across
  the whole codebase, which is the real duplication picture.
- **`literal-scan.sh` truncates at 40 reported literals and says so.** Do not
  paper over that line. A truncated scan described as complete is worse than
  no scan, because it closes a question it never actually answered. Re-run
  scoped to a subdirectory if you need the rest.

### 4. Aggregate into themes, not findings

3,000 individual findings is wallpaper. Each pattern becomes one entry:

> **UI-only authorization** — 14 endpoints across 9 files.
> Exemplars: `OrderController.cs:42`, `AdminPage.razor:88`, `UserService.cs:15`.
> Blast radius: 6 of the 14 are reachable by any authenticated user who
> guesses an id; the other 8 sit behind an additional gateway check.
> Fix order: the 6 reachable ones, then a policy applied at the controller
> base, then delete the per-page checks.

Only **CRITICAL and HIGH** get listed individually. MEDIUM and LOW become
counts with three exemplars each. Severity needs recalibrating for scale:
MEDIUM in a diff is actionable; MEDIUM × 800 is wallpaper with a severity tag.

### 5. State coverage honestly — mandatory

```
Coverage: 47 files read end-to-end / 312 scanned mechanically / 541 not examined
Selection: top-40 churn ∩ >400 lines, plus all auth + migration paths
Not examined: tests/, generated clients, .planning/
Scans truncated: literal-scan (40 of 380 literals reported)
```

Without this, an audit is hunt #23's failure aimed at itself: a confident,
clean answer to a narrower question than the one asked. The reader cannot
tell "there is nothing in `Services/`" from "I never opened `Services/`" —
and those are opposite facts.

## Hunts that don't transfer

- **#22 change-narration** — no PR body to check. The comment half still
  applies.
- **#23 requirement fidelity** — no ticket. Replace it with the inverse
  question: does the code's *structure* match what the README and the
  architecture docs claim (that's #18 at repo scale)?
- **#14 hand-edited generated artifacts** — needs `git log` on the generated
  files, not a diff. Check whether migration snapshots were ever hand-edited:
  `git log -p -- '*ModelSnapshot.cs' | grep -c '^+.*// '` is a rough probe.
- **#5a parallel-instance drift** — still applies, but *every* instance is
  pre-existing, so it is a theme ("three `HttpClient` registrations, three
  different timeout policies"), not a finding.
- **#3a sibling pairwise diff** — transfers well and gets *better* at repo
  scale: compare all N implementations of the same interface, rather than
  only the ones a diff happens to touch.
- **#28 AI-slop prose** — transfers as a theme, not per-string findings.
  No PR body to read, but every `README`, `docs/`, `.resx`, i18n `.json`,
  and user-visible error string is pre-existing and in scope. Probe first,
  then dispatch `prose-reviewer` on the hotspots:
  `grep -rilE 'delve|tapestry|crucial|furthermore|shifting landscape|worth noting|let.s dive in|oops' --include='*.md' --include='*.resx' --include='*.json' --include='*.razor' .`
  Report as one theme ("41 user-facing strings open with 'Oops', three
  different apology registers across `.resx` files"), three exemplars, and
  the canonical register to converge on.

## Hunts that only exist at repo scale

Add these when in audit mode:

- **Unreferenced public surface.** Public members with zero call sites
  outside their own assembly. Every one is either dead or an accidental API.
- **Clone clusters.** jscpd across the whole repo — not "these two functions
  are similar" but "this shape appears in 14 places".
- **Convention divergence.** N implementations of the same concern that don't
  agree: three ways to read the current user, four error-response shapes, two
  date-formatting conventions. Pick the canonical one, name it, list the
  deviants.
- **Dependency freshness and CVE surface** across *every* project file, not
  just the ones a diff touched: `dotnet list package --vulnerable
  --include-transitive --outdated`.
- **Orphaned feature flags.** Flags with no remaining branch, or branches
  with no flag definition.
- **Environment config drift.** `appsettings.json` vs
  `appsettings.Production.json` vs the deployment template: keys present in
  one and missing in another, and which side the default falls to.
- **Test distribution, not test coverage.** A 78% average hides that the
  payment module is at 12%. Cross-reference the hotspot list: **a hotspot
  with no test file next to it is the highest-value gap in the repo.**
- **Directory-level entropy.** Which folders have grown fastest, and whether
  the folder names still describe their contents.

## Ratchet, not cleanup

An audit that ends with "you have 400 problems" gets filed and forgotten.
End with a ratchet instead:

1. Write the theme counts to a baseline file (a small JSON or Markdown table:
   theme → count → date → commit sha).
2. The standing rule becomes: **new code meets the bar; existing debt burns
   down by theme, one theme per sprint.**
3. Re-running the audit later diffs against the baseline, so the number moves
   and someone can see it moving.

This is the difference between an audit that changes behaviour and an audit
that produces a document. Pick two or three themes with the best
blast-radius-to-effort ratio and say *those* are the ones — a prioritised
list of three beats a complete list of forty.

## Cost control

A whole-repo audit is unbounded by default. Before starting, state the
budget: how many files will be read end-to-end, and how the rest is sampled.
Then hold to it and report against it. "I read what mattered" is not a
sampling method; "top-40 churn ∩ >400 lines, plus all auth paths" is.
