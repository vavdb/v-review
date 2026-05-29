# v-review output format

> Reference loaded by the `v-review` skill before producing the final review output. Two sections, in this order — the compressed block first so it is paste-ready into a PR comment without scrolling.

## §1 — Paste-ready PR comment block (always first, always at the top)

A `caveman-review`-style compressed block. Two parts:

**Lead line — count-shape summary.** Tell the reader the *shape* of the review in one line, with concrete numbers. Pattern: `**N findings** — X to add to this PR, Y to file as separate issues, Z blockers.` (If `Z = 0`, write "no blockers" rather than "0 blockers".) Reader knows what they're in for within one line, without scanning the list.

**Then one numbered line per finding.** Format: `N. <file>:L<lines>: <severity-emoji> <severity-word>: <problem>. <imperative-fix>.` Plain integers — never opaque prefixes like `F1`/`CR1`/`R-001`. Severity emoji: 🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 LOW. Same numbers as the §2 findings table so the two sections cross-reference.

**Every fix half must start with an imperative verb** so the reader sees the action immediately. Catalog: `Add`, `Move`, `Delete`, `Extract`, `Inline`, `Rename`, `Mark`, `Replace`, `Reject`, `File issue`, `Revert`, `Wrap`, `Split`, `Combine`. Avoid passive prescriptions like "Pick one layer", "Let X own", "Consider refactoring", "Maybe rework".

**No throat-clearing, no prose, no per-line "consider" or "you might want to".** Designed to paste directly into a GitHub PR review comment without editing.

**Vocabulary to avoid (jargon that reads as opaque to non-reviewers):** `fold in` (write `add to this PR`); `land` (write `merge`); `ship it` (write `merge`); `site` to mean "place in code" (write `place` or `call site`); `bucket` to mean "group" or "category" (write the plain word); `dispatched` / `dispatch` (write `ran` or `invoked`); `registered` / `registry` (write `installed` / `list of installed X`); `mandated` (write `required`); `ecosystem` (write `plugins` or `set of tools`); `dish` / `meatball` / `cargo` as standalone framings (name the underlying symptom directly). Also: never write `Hunt #N` or `step Na` in output — those are skill-internal references, not for the reader. **And: do not apply this same jargon in the prose around the output.** If the skill body itself slips into jargon, fix it.

If `caveman:caveman-review` is installed (see availability check), you *may* dispatch it to do the compression; otherwise apply these rules inline. The block must exist either way.

## §2 — Full review (verbose, below the compressed block)

Everything below is for the author/reviewer dialogue — not the PR comment. Order:

- **Pre-flight notes — warnings and skipped checks only.** Do *not* list every passing precondition (clean conflict scan, passing sibling diff, passing procedural sweep) — that's noise the reader has to skim past to reach the findings. List only items that are warnings, skipped checks, missing tooling, or otherwise required the reviewer to do something the reader needs to know about. If every pre-flight item passed, **omit the section entirely**. Example of what *to* surface: `⚠️ subagents differential-review and security-reviewer not registered in this session — walked their hunt-list items manually; coverage is thinner than with them available.` Example of what *not* to surface: `✅ conflict-marker scan: clean`.
- **Findings table** covering every cleanup, with severity per finding. One row per finding, grouped by file. Severity per the project's rule file (CRITICAL / HIGH / MEDIUM / LOW or equivalent). **Number findings plainly: `1`, `2`, `3`, …** so later sections (trajectory note, follow-up issues, §1 PR comment) can cite them. Do *not* invent opaque prefixes like `F1`, `CR1`, `R-001` — they look like project-specific tracker IDs and confuse the reader. Plain integers, nothing else.
  - **Columns**: `#`, `File:line`, `Severity`, `Pattern`, `Finding`.
  - **`Pattern` column uses plain-English labels**, not the skill's internal hunt numbers. Catalog: `missing tests`, `duplicated query`, `redundant code`, `silent failure`, `framework drift`, `cascading drift`, `dead code`, `unjustified addition`, `UI-only authz`, `hand-edited generated file`, `unsafe migration`, `leftover artifact`, `architecture drift`, `code sweep` (for procedural-sweep catches), `sibling mismatch` (for pairwise-diff catches). Pick the closest label; coin a new plain-English one if none fits. Never write `Hunt #N` or `step Na` in this column — those are internal-to-the-skill, not for the reader.
  - **Findings copy uses imperative verbs in the fix half** (`Add`, `Move`, `Delete`, `Extract`, `Inline`, `Rename`, `Mark`, `Replace`, `Reject`, `File issue`, `Revert`, `Wrap`, `Split`, `Combine`). Same rule as §1.
- **Unfixed CRITICAL/HIGH** listed separately for the user's decision (design-level concerns, architectural calls, risky migrations).
- **Considered-but-left**, with a one-sentence reason each (e.g. "`DateTime.UtcNow` vs injected `TimeProvider` — codebase uses `DateTime.UtcNow` everywhere; introducing a new abstraction for one file is inconsistent"). This is the future-check operator's signature — the things you *didn't* change tell the reader what the codebase's actual posture is.
- **Skills + tools used** — a three-bucket table mirroring the pre-flight banner: `subagents dispatched`, `skills invoked` (with one-line headline output each), `skills available but not invoked` (with one-phrase skip reason each). `not-installed` subagents go in a fourth row only if their absence materially limited the review. Never collapse the categories.
- **Exact build + test commands** you ran, with pass/fail.
- **Trajectory note** when applicable: if the diff establishes a pattern that will compound (e.g. "this is the third hand-rolled retry loop in the codebase — Polly is already configured, recommend a follow-up to consolidate"), call it out. Trajectory is the future-check signal.

## Vocabulary-to-avoid recap

**Vocabulary to avoid (jargon that reads as opaque to non-reviewers):** `fold in` (write `add to this PR`); `land` (write `merge`); `ship it` (write `merge`); `site` to mean "place in code" (write `place` or `call site`); `bucket` to mean "group" or "category" (write the plain word); `dispatched` / `dispatch` (write `ran` or `invoked`); `registered` / `registry` (write `installed` / `list of installed X`); `mandated` (write `required`); `ecosystem` (write `plugins` or `set of tools`); `dish` / `meatball` / `cargo` as standalone framings (name the underlying symptom directly). Also: never write `Hunt #N` or `step Na` in output — those are skill-internal references, not for the reader. **And: do not apply this same jargon in the prose around the output.** If the skill body itself slips into jargon, fix it.

## Worked example

```
**8 findings** — 3 to add to this PR, 5 to file as separate issues. No blockers.

1. PR-wide: 🟡 MEDIUM: no tests for silent bug fix + new region picker. Add a bUnit or Playwright case before merge.
2. ProductDialog.razor:L296-302: 🔵 LOW: 4th place in the codebase loading company-with-countries (also EditCompany:L639, AddNewRequest:L153, CreateNewProject:L509). Extract `CompanyQueries.GetWithCountriesAsync(ids)`.
3. ProductDialog.razor:L296-304, L334: 🔵 LOW: duplicated dedup — runs 2-3× across server query + `AddCountries` filter. Delete server `GroupBy`; let `AddCountries` handle uniqueness alone.
…
```
