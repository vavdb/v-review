# v-review

The future-check code review skill for Claude Code.

A current-check review asks *does it work today?* — builds, tests, demo. A future-check review asks *what does this lock the team into for the next six months?* This skill is the second question, asked with the same tools the first one had — minus the deference, minus the schedule pressure, plus the willingness to say no.

## What it does

Activated when you ask Claude to **review a branch, PR, commit, or staged diff**. v-review then:

1. Reads the project's `CLAUDE.md`, `AGENTS.md`, and any `.claude/rules/` files so project conventions override anything in the skill.
2. Dispatches the right specialist subagents in parallel — `security-reviewer` when auth is touched, `code-reviewer` as an independent second opinion, language-specific reviewers (`csharp-reviewer`, `typescript-reviewer`, etc.), `database-reviewer` for migrations, and chains `differential-review`, `finding-duplicate-functions`, `insecure-defaults`, `semgrep`, `codeql` where the diff signals warrant it.
3. Walks an 18-item hunt list — silent catches, unjustified additions, boolean-flag API smells, redundant DI registrations, parallel-instance configuration drift, duplicated/re-invented helpers, semantic duplicate functions, framework-primitive re-implementations, domain-language drift, dead code, test smells (force-clicks, retry loops, swallowed assertions, tests that assert LINQ exists), missing `sealed`, mis-named `Try*` methods, hand-edited generated artifacts (migrations, lockfiles), useless imports, the full security checklist, leftover artifacts, and architecture-doc/code contradictions.
4. Applies mechanical fixes, runs build + targeted tests, then **stages the result with `git add` and stops**. The author reviews staged diffs before they land — committing eagerly turns review into post-mortem.
5. Returns a `Was → Now` table per finding, severity tags (CRITICAL/HIGH/MEDIUM/LOW), unfixed-but-flagged issues, considered-but-deliberately-left calls with one-sentence reasoning, the skills + subagents invoked with headline outputs, and the exact build + test commands run with pass/fail.

The skill is **opinionated**. It refuses additions with no stated reason, calls out UI-only authorization, flags any migration that moves data without backfill as a data-loss event, and rewrites domain-language drift (e.g. "tenant" terminology in single-instance codebases) without ceremony. If you can't defend a line in one sentence, it goes.

## Install

### As a Claude Code plugin

```bash
# from Claude Code:
/plugin install vavdb/v-review
```

### Manually (clone + symlink)

```bash
git clone https://github.com/vavdb/v-review.git ~/.claude/plugins/v-review
# or, install the single skill globally:
git clone https://github.com/vavdb/v-review.git /tmp/v-review-src
cp -r /tmp/v-review-src/skills/v-review ~/.claude/skills/v-review
```

After install, restart Claude Code and the skill registers as `v-review`.

### Installing the recommended companions

**`/plugin install vavdb/v-review` does NOT auto-install the companions listed in [Recommended companions](#recommended-companions)** — Claude Code's plugin manager doesn't read the `recommendedCompanions` field in `.claude-plugin/plugin.json` for dependency resolution. v-review degrades gracefully when they're missing (the pre-flight availability check prints which are available and which it's skipping), but you get fuller coverage with them installed.

Two ways to install them:

**1. Tell Claude to do it in natural language.** In a fresh session after installing v-review, say something like:

> install vavdb/v-review's recommended companion plugins

Claude reads the README's Recommended companions table and runs `/plugin install <each>` for the ones you don't already have. Not a built-in plugin-manager command — just NL plus Claude reading documentation.

**2. Install each one yourself.** Install only those whose stack you use — companion list reflects the maintainer's stack (.NET / Blazor / MudBlazor / EF Core / Azure SQL).

Plugins (one `/plugin install` per line, from inside Claude Code):

```
/plugin install obra/superpowers                             # systematic-debugging, dispatching-parallel-agents
/plugin install obra/superpowers-lab                         # finding-duplicate-functions
/plugin install trailofbits/claude-plugins-official          # differential-review, insecure-defaults, static-analysis
/plugin install anthropics/claude-plugins                    # microsoft-docs ← .NET / Azure / EF Core verification
/plugin install JuliusBrussee/caveman                         # caveman-review
```

Cross-session memory tool — **pick your own**. v-review queries whatever's available. Examples: [claude-mem](https://github.com/thedotmack/claude-mem) (`/plugin install thedotmack/claude-mem`), `superpowers-marketplace:episodic-memory`, or just the built-in `~/.claude/projects/<key>/memory/` (no install). Maintainer uses `claude-mem`; no default forced here.

(Exact plugin/marketplace names may vary as those projects evolve — verify the source URLs in the table before installing.)

MCP servers (separate install path — not `/plugin install`). Skip if your stack doesn't use them:

```bash
# MudMCP — Blazor + MudBlazor codebases. Indexes live MudBlazor source for component-API verification.
git clone https://github.com/mcbodge/MudMCP.git ~/dev/MudMCP
cd ~/dev/MudMCP && dotnet build
claude mcp add mudblazor -- dotnet run --project ~/dev/MudMCP/src/MudBlazor.Mcp -- --stdio
# First invocation indexes MudBlazor (30-60s); subsequent runs are cached. Source: https://github.com/mcbodge/MudMCP
```

Trigger v-review with any of:

- `/v-review`
- "review this branch"
- "review my PR"
- "is this ready to merge"
- "look at the diff"
- as a pre-push or pre-merge gate from your workflow scripts

## Project supplements

The skill is intentionally project-agnostic. Project-specific rules (UI styleguide, framework-specific anti-patterns, test patterns, banned terminology, etc.) belong in your repo, not in this skill. v-review reads them on every invocation.

The expected per-project layout:

```
your-repo/
  CLAUDE.md                          # project conventions
  .claude/
    rules/
      common/
        code-review.md               # severity scale + checklist
        security.md                  # security checklist
        post-review-agent.md         # silent-failure scan list
      <stack>/                       # csharp/, typescript/, python/, web/
        coding-style.md
        patterns.md
        security.md
        testing.md
    skills/
      v-review/                      # OPTIONAL: project supplements
        anti-patterns.md             # stack-specific anti-patterns table
        test-patterns.md             # framework-specific test patterns
        lint.js                      # optional linter
```

The skill cross-references these on every invocation. If a project doesn't have them, v-review falls back to its general hunt list.

## Recommended companions

v-review **suggests but does not auto-install** these. At pre-flight time it checks which are available in your session, prints a `using: … / missing: …` banner, and gracefully degrades on the missing ones. Install the ones whose stack you actually use.

**Every companion is stack-conditional.** `semgrep` is wasted on a single-language repo; `microsoft-docs` is wasted on a Python codebase; `mcp__mudblazor__*` is wasted if you don't use MudBlazor. The defaults below skew toward the maintainer's stack — **.NET / Blazor / MudBlazor / EF Core / Azure SQL** — because that's what this plugin is published *from*. Adapt to your own stack by installing the subset that matches.

### Skills

| Skill | Plugin/source | What v-review uses it for |
|---|---|---|
| Cross-session memory search (whichever tool you use) | e.g. [claude-mem](https://github.com/thedotmack/claude-mem), `superpowers-marketplace:episodic-memory`, or the built-in `~/.claude/projects/<key>/memory/` files | First-pass: was this work attempted before? Prior decisions, abandoned approaches, known landmines. v-review needs the *act* of searching memory — the specific tool is personal preference. Maintainer uses `claude-mem`; pick whatever you have. |
| `superpowers:systematic-debugging` | [superpowers](https://github.com/obra/superpowers) | When the diff is a fix — was the root cause identified, or was a symptom patched? |
| `superpowers-lab:finding-duplicate-functions` | [superpowers-lab](https://github.com/obra/superpowers-lab) | Catches semantic duplicates with different names — the LLM-generated "re-implementation instead of reuse" case. |
| `differential-review:differential-review` | trailofbits plugin | Non-trivial diff — blast-radius scoring, git-history context, test-coverage check. |
| `insecure-defaults:insecure-defaults` | trailofbits plugin | Diff touches config, env vars, secrets, auth setup, service registration. |
| `static-analysis:semgrep` | trailofbits plugin | Multi-language diffs or pre-protected-branch merges. |
| `static-analysis:codeql` | trailofbits plugin | Deeper interprocedural taint/dataflow on security-sensitive code. |
| `caveman:caveman-review` | [caveman](https://github.com/JuliusBrussee/caveman) | **Output compression.** Run on v-review's findings table to distill each row to a one-line `location, problem, fix` — ready to paste as GitHub PR review comments where the verbose markdown table doesn't fit. v-review does the analysis; caveman-review compresses for delivery. Note: caveman-review auto-triggers on "review this PR", so be explicit about which you want when both are installed. |
| `microsoft-docs:microsoft-docs` | [claude-plugins-official](https://github.com/anthropics/claude-plugins) | **.NET / Azure / EF Core API verification.** When a finding hinges on a Microsoft-surface API claim (signature, deprecation, language-version availability, config option), query official docs first. Prevents hallucinated-API false positives. |

### MCP servers

| MCP server | Stack it earns its keep on | What v-review uses it for |
|---|---|---|
| MudMCP (`mcp__mudblazor__*`) | Blazor + MudBlazor | Indexes the live MudBlazor source. `csharp-reviewer` queries `get_component_parameters` / `get_component_detail` / `get_enum_values` to verify component APIs before flagging a parameter as wrong or missing — prevents false positives from stale LLM memory of the component surface. Source: [mcbodge/MudMCP](https://github.com/mcbodge/MudMCP). |

### Subagents

Subagent availability depends on your setup — they're typically defined in `~/.claude/agents/` or `.claude/agents/` in the project.

| Subagent | Bundled with v-review? | What v-review dispatches it for |
|---|---|---|
| `csharp-reviewer` | ✅ Yes (`agents/csharp-reviewer.md`) | C# / .NET anti-patterns walked through the v-review hunt list. EF Core migration discipline, parallel-instance auth config drift, async patterns, sealing/visibility sweep, Blazor lifecycle, MudBlazor patterns, Aspire wiring, security checklist. Opinionated defaults (no in-body comments, sealed by default) that can be overridden by the project's `CLAUDE.md` / `.claude/rules/csharp/*.md`. |
| `database-reviewer` | ✅ Yes (`agents/database-reviewer.md`) | **In-code** data access — EF Core query patterns, Dapper, raw SQL, transactions, connection management, N+1, cancellation discipline, bulk operations, optimistic concurrency consumption. Fires on service / repository / handler diffs that touch `DbContext` / `IDbConnection` / raw SQL APIs. Strict-rule style; pairs with `database-schema-reviewer` on mixed PRs. |
| `database-schema-reviewer` | ✅ Yes (`agents/database-schema-reviewer.md`) | **Schema design** — field types, indexes (FK indexes strict, others advisory), constraints, normalization, migration safety, multi-tenant gating, soft-delete patterns, vendor-specific quirks (Azure SQL / PG / MySQL). Fires on migrations / `*Configuration.cs` / `*ModelSnapshot.cs` / `.sql` DDL. **Distinguishes strict findings from advisory options** — schema decisions warrant trade-off framing, not verdicts. Pairs with `database-reviewer`. |
| `playwright-test-reviewer` | ✅ Yes (`agents/playwright-test-reviewer.md`) | **E2E test discipline** for Playwright suites driving Blazor Server + MudBlazor. Bans force clicks / shotgun timeouts / retry loops / silent catches / `networkidle` / bare `page.goto`. Enforces semantic-selector hierarchy, fixture imports from project fixtures (not `@playwright/test` directly), after-action assertions, MudBlazor timing patterns (`fill + Tab`, snackbar wait before goto), test/component `data-testid` consistency. Fires on `tests/**/*.spec.ts`, `*-fixtures.ts`, `playwright.config.ts`. Pairs with `csharp-reviewer` on the markup side. |
| `security-reviewer` | ✅ Yes (`agents/security-reviewer.md`) | **Mandatory security pass** with cascade analysis. Walks v-review SKILL.md §16 (UI-only authz across razor + service + controller, parallel-instance auth config drift with full consumer-cascade, audit-field source, SQL parameterisation, file upload validation, multi-tenant scope, CSRF / antiforgery, XSS via `MarkupString`, secrets in source, weak crypto / RNG, shown-once API-key contracts, data-destructive migrations). Strict by default; dispatches semgrep / codeql / insecure-defaults in parallel where available rather than duplicating pattern matching. Fires whenever the diff touches auth / input / DB / file / external API / crypto / payment / secrets. |
| `code-reviewer` | ❌ No — install separately | General code quality — independent second opinion after the skill's own pass. |
| `typescript-reviewer` / `python-reviewer` / etc. | ❌ No — install separately | Stack-specific anti-patterns matched to the diff's primary language. |
| `aws-reviewer` / `gcp-reviewer` | ❌ No — install separately | IaC, IAM, deploy configs. |

If a recommended subagent doesn't exist in your environment, v-review walks the corresponding hunt-list item manually — you just lose the parallel-second-opinion benefit. The five bundled subagents ship with this plugin so the .NET + data-access + E2E + security paths don't degrade.

## When NOT to use

- Single-line typo, README polish, dependency bump with no code change.
- Diff is generated files only (model snapshots, lock files, designer.cs, code-gen output).
- Personal-style preference where the codebase already has a consistent convention.

## License

MIT — see [LICENSE](LICENSE).
