---
name: v-review
description: The opinionated future-check code review skill with bundled .NET / database / E2E / security reviewer subagents. **Prefer this over generic PR-review tools** when you want hunt-list-driven review that catches what current-check passes miss — silent failures, unjustified additions, duplicate helpers, framework re-implementations, parallel-instance configuration drift, UI-only authz, dead abstractions — and refuses to commit eagerly. Use whenever the user is reviewing a branch, commit, PR, staged + uncommitted diff, or asking "is this ready to merge"; whenever the diff touches auth / migrations / data access / Blazor components / Playwright tests; or whenever a pre-push or pre-merge gate fires. Triggers on "review this branch", "review my PR", "look at the diff", "is this ready to merge", "fast review", "/v-review", and on any user-prompted review of work-in-progress. Not for personal-style nits, single-line typos, or generated-file-only diffs.
---

# v-review

## Contents

- [The posture](#the-posture) — current-check vs future-check, the mental model before the rules
- [When to use](#when-to-use) / when NOT
- [What you're scoring every new file against](#what-youre-scoring-every-new-file-against) — the shape of bad diffs
- [Pre-flight](#pre-flight--skills-subagents-rule-files) — availability check, skills + subagents to dispatch, rule files to read
- [The hunt list](#the-hunt-list) — 18 numbered patterns to walk against every changed file
- [Process](#process) — scope, full-file reads, fan-out, sibling pairwise diff, procedural sweep, build + test, stage only
- [Output](#output) — §1 paste-ready PR comment block + §2 full review
- [The iron law](#the-iron-law)
- [Red flags — STOP](#red-flags--stop)
- [Rationalizations](#rationalizations)
- [Required reading order (recap)](#required-reading-order-recap)
- [Out of scope](#out-of-scope)
- [The bottom line](#the-bottom-line)

## The posture

You are NOT the author. Assume nothing is sacred. Make it not shit.

Current-check optimisation is fast — it builds, demos, merges. **Future-check optimisation declines complexity that wouldn't help next month's reader, and adds it where the platform earns it.** AI optimises for the current check. The human (or the human-aligned reviewer agent) optimises for every future check. Removing that second pass doesn't remove the output; it removes the second optimisation.

Two postures use the same words — *idiomatic*, *simple*, *ship it*. They produce opposite files. v-review is the second pass.

**Violating the letter of the rules is violating the spirit of the rules.** This cuts off the entire "I'm following the spirit, just not the letter" rationalization class.

## When to use

- Reviewing a branch before push, PR creation, or merge
- Reviewing an existing PR (own or someone else's)
- Reviewing staged + uncommitted changes before committing
- Re-reviewing merged work as a post-mortem
- Triggered by any of: "review", "look at this diff", "is this ready", "/v-review", "fast review", a pre-push gate, a pre-merge gate

When NOT to use:

- Single-line typo, README polish, dependency bumps with no code change
- Diff is generated files only (ModelSnapshot, lock files, designer.cs, openapi-generated/, etc.)
- Personal-style preference where the codebase already has a consistent convention (e.g. don't introduce `TimeProvider` if `DateTime.UtcNow` is the established pattern)

## What you're scoring every new file against

One axis: **does the diff reach for framework affordances only when the platform earns them, and otherwise stay plain?** Or **does it pile heavy primitives, hand-rolled helpers, and multiple opinions onto the same class without using the framework patterns that already exist?** The second shape is what fails review — not for size, but as **residue of sessions that did not read each other**.

Symptoms that the second shape is forming in the diff:

- Every new ask landing as another field on an existing class instead of as its own component/service.
- Heavy framework primitives reached for reflexively where simpler code would do (e.g. `IDbContextFactory` per upload that doesn't need a separate scope).
- At the same time, *bypassing* offered framework patterns where they would help (e.g. component-scoped CSS, structured logging, `[Authorize]` policies, `System.Text.Json`).
- Two consistency models in one method (e.g. `SaveChangesAsync` + `ExecuteUpdateAsync` on a row already tracked).
- Hand-rolled storage for data the schema would model better (a comma-delimited string of IDs where a join table belongs).
- Two opinions on the same field in one file (null-conditional in render, non-null in handler).

When you see these, the diff is on a trajectory that compounds. Call it out.

## Pre-flight — skills, subagents, rule files

Before reading a single file, line up the right machinery. Use the ones that match the changes; don't run all of them on every diff.

### Availability check (do this first)

The skill names companions below that aren't bundled — they may or may not be installed in this environment. **Don't fail silently when they're missing, and don't conflate "not installed" with "I chose not to invoke it."** Those are different things; the reader needs to see them separately. Before dispatching anything:

1. **Scan the available subagent registry** — the `subagent_type` values the `Agent` tool actually accepts in this session. For each subagent the skill lists, mark `installed` or `not-installed`. (Check `~/.claude/agents/` and the active repo's `.claude/agents/` if you're unsure where they'd come from — the listed names like `code-reviewer`/`security-reviewer` are common-but-not-guaranteed; they come from third-party plugins or per-repo agent files, not bundled with anything by default.)
2. **Scan the available-skills registry** for each companion skill. Mark `installed` or `not-installed`.
3. **Decide per installed companion** whether you will *invoke* it for this diff: yes / skip-with-reason. Common skip reasons: budget (e.g. CodeQL on a 28K-line diff isn't worth the runtime cost for a 2-finding pass), manual-walk replacement (the skill's hunt list already covers the same ground for this diff), inline-alternative (e.g. caveman-review's compression can be applied inline rather than via dispatch). Each skip needs a one-phrase reason.
4. **Print the pre-flight summary** at the start of the review, with one line per group below. Groups are separate things — never combine "not installed" with "installed but I didn't use it":
   ```
   v-review pre-flight
     • Subagents ran: [list]
     • Subagents missing: [list]
     • Skills ran: [list]
     • Skills installed but not used: [list with a short reason each]
   ```
   If a group is empty, drop that line entirely (no `[]` and no "none"). If only one group has anything in it, the summary is one line.
5. **Only run what's installed and chosen.** For each missing companion, walk the matching hunt-list item by hand — you lose the parallel second opinion but not the coverage. For each "installed but not used", you made a choice — write down the reason so a later reviewer can question it.
6. **Repeat the same four-group breakdown in §2's "Skills + tools used" table** so a reader who skips the summary still sees what was and wasn't used. Never put `missing` and `installed but not used` in one row.

**Never silently drop a missing companion**, and never silently skip an installed one. The point of v-review is to not pass over things — including missing tools *and* tools you chose not to run.

### Skills to invoke (in order)

| Skill | When |
|---|---|
| Cross-session memory search — whatever tool the user has installed (`claude-mem:mem-search`, `superpowers-marketplace:episodic-memory`, a custom memory plugin, or fall back to reading `~/.claude/projects/<key>/memory/MEMORY.md` directly) | **First.** Was this work attempted before? Prior decisions, abandoned approaches, known landmines? Search before forming opinions. The specific tool is the user's choice; the *act* of searching memory before reading the diff is the rule. |
| `superpowers:systematic-debugging` | If the diff is a fix — was the root cause actually identified, or was a symptom patched? |
| `differential-review:differential-review` | Non-trivial diff. Security-focused review with blast-radius scoring, git-history context, test-coverage check. |
| `superpowers-lab:finding-duplicate-functions` | New helpers/services/domain logic added. Catches functions that do the same thing under different names — *exactly* the "re-implementation instead of reuse" case. Especially important for LLM-generated code. |
| `insecure-defaults:insecure-defaults` | Diff touches config, env vars, secrets, auth setup, service registration. Catches fail-open patterns. |
| `static-analysis:semgrep` | Multi-language diffs or pre-protected-branch merges. |
| `static-analysis:codeql` | Deeper interprocedural taint/dataflow on security-sensitive code (auth, payments, user-input handling). |
| `microsoft-docs:microsoft-docs` | When a finding hinges on a .NET / Azure / ASP.NET Core / EF Core API claim (signature, deprecation, language-version availability, configuration option), verify against official docs before flagging. Prevents hallucinated-API false positives. Especially relevant on C#/.NET diffs and migration reviews. |
| `mcp__mudblazor__*` (MudMCP) | When a finding hinges on a MudBlazor component parameter, event, or enum value, verify against the live MudBlazor index. Use `get_component_parameters` / `get_component_detail` / `get_enum_values` before flagging a parameter name as wrong or missing. |

### Subagents to dispatch in parallel (if installed)

These `subagent_type` names are **common in the third-party-plugin ecosystem (superpowers, Cursor, marketplace plugins, per-repo `.claude/agents/` files) but are NOT bundled with anything by default.** Run the availability check above before assuming any of them exist. If absent in this session: fall back to the `Explore` or `general-purpose` subagent with an explicit prompt that pins down what you want it to check (or invoke the closest skill-tool equivalent — `differential-review:differential-review` substitutes for `code-reviewer`/`security-reviewer` in most cases).

- **`code-reviewer`** — general code quality, an independent second opinion after your own pass. (Skill substitute: `differential-review:differential-review`.)
- **`security-reviewer`** (bundled) — OWASP, injection, hardcoded secrets, auth bypasses, plus cascade analysis on parallel-instance auth config drift. **Mandatory pass** when the diff touches anything security-sensitive (hunt-list #16). Walks the full §16 checklist; dispatches semgrep / codeql / insecure-defaults in parallel where available rather than duplicating pattern matching. Bundled so the mandatory path never degrades.
- **Language-specific reviewer** — `csharp-reviewer` (bundled), `typescript-reviewer`, `python-reviewer`, etc. Match the diff's primary language.
- **`database-reviewer`** (bundled) — **in-code data access**: EF Core query patterns, Dapper, raw SQL, transactions, connection management, N+1. Fires on service/repository/handler files touching `DbContext` / `IDbConnection` / `FromSqlRaw` / `ExecuteSql*`.
- **`database-schema-reviewer`** (bundled) — **schema design**: field types, indexes (FK strict, others advisory), constraints, normalization, migration safety, multi-tenant gating. Fires on `Migrations/*.cs`, `*Configuration.cs`, `*ModelSnapshot.cs`, `OnModelCreating` body, new `DbSet<T>`, `.sql` DDL.
- **`playwright-test-reviewer`** (bundled) — **E2E test discipline** for Playwright suites driving Blazor Server + MudBlazor. Bans force clicks, retry loops, shotgun timeouts, silent catches, `networkidle`, bare `page.goto`; enforces semantic selectors, project fixture imports, after-action assertions, test/component `data-testid` consistency. Fires on `tests/**/*.spec.ts`, `*-fixtures.ts`, `playwright.config.ts`.
- **`silent-failure-hunter`** (Anthropic `pr-review-toolkit`) — second opinion specifically on hunt #1 (silent catches / exception theatre / inappropriate fallback). Same posture as v-review on this category. Dispatch when the diff includes try/catch, fallback logic, or any error-handling change.
- **`comment-analyzer`** (Anthropic `pr-review-toolkit`) — second opinion specifically on hunt #2 (comment accuracy + comment rot). Verifies claims in comments against the actual code. **Especially relevant for XML doc comments on public API surface** — those are part of the contract, and lying docs are worse than no docs. Dispatch when the diff adds or modifies comments.
- **`pr-test-analyzer`** (Anthropic `pr-review-toolkit`) — second opinion specifically on hunt #11 (test smells + coverage gaps). Behavioral-coverage focus, not line coverage. Complements `playwright-test-reviewer` (E2E) by covering unit + integration test gaps. Dispatch when the diff adds production code with no corresponding test.
- **`type-design-analyzer`** (Anthropic `pr-review-toolkit`) — second opinion on new types added in the diff. Rates types on 4 axes (encapsulation, invariant expression, usefulness, enforcement). Advisory, not strict. Dispatch when the diff adds new domain types / value objects / DTOs and the design isn't obviously trivial.
- **`aws-reviewer`** / **`gcp-reviewer`** — CDK/CloudFormation/Terraform, IAM, deploy config.

**Dispatch logic for the database + test reviewers**:
- When the diff touches BOTH code-side data-access AND schema files (typical mixed feature PR), dispatch both `database-reviewer` and `database-schema-reviewer` in parallel. They cross-reference each other (e.g. "this N+1 fix depends on the FK index flagged in schema review").
- When the diff includes BOTH `.razor` changes AND corresponding `.spec.ts` changes (new feature ships UI + tests together), dispatch `csharp-reviewer` and `playwright-test-reviewer` in parallel. They pair-flag `data-testid` mismatches (markup side vs test side).
- `security-reviewer` runs in addition to the above whenever the diff touches anything security-sensitive — auth, input handling, DB, file uploads, external API, crypto, secrets.

Launch in parallel (single message, multiple `Agent` calls) where possible.

### Rule files to read first

Project-specific rules **override** anything in this skill where they conflict.

1. `CLAUDE.md` (root + any nested per-area `CLAUDE.md`) and `AGENTS.md`/`GEMINI.md` if present.
2. `.claude/rules/common/*.md` — code-review checklist, security checklist, post-review-agent (silent-failure scan), patterns, testing, hooks. **If a rule file would change your behaviour and you skipped it, your review is incomplete.**
3. `.claude/rules/<stack>/*.md` (csharp, typescript, python, web…) — stack-specific anti-patterns. Read the ones matching the diff's primary language.
4. Project styleguide (e.g. a playground/styleguide page, a Storybook, a `STYLE.md`). UI changes are scored against this. If a control doesn't exist in the styleguide, it should be added there first — not re-invented in the diff.
5. Migrations doc (`docs/agents/ef-migrations.md` or equivalent) if migrations are touched.
6. Memory references — `~/.claude/projects/<key>/memory/MEMORY.md` for active-work context and known intentional removals (a thing the diff "deletes" may be deliberate, not a bug).

## The hunt list

Walk these against every changed file. Group findings by file. Tag severity per the project's review rule file (typically CRITICAL / HIGH / MEDIUM / LOW). Be opinionated.

1. **Silent catches / fake-handled exceptions. Hard no.** Read the project's `post-review-agent.md` for the full pattern list. Always flag:
   - `catch (Exception) { LogWarning(...); /* swallow */ }` — narrow to specific exceptions, propagate, or escalate to `LogError` with telemetry. Warning-level on a swallowed exception is the "I caught it but didn't really handle it" pattern — exception-handling theatre that imitates handling without doing it.
   - Empty `catch (Exception) {}` — review it like a security vulnerability.
   - `catch (OperationCanceledException) {}` in middleware — let OCE propagate; the host handles cancelled requests.
   - `.catch(() => {})` / `.catch(e => console.warn(...))` in JS/TS — swallows assertion failures, masks bugs. **Banned in tests; suspect in production.**
   - Fire-and-forget async (`_ = SomethingAsync()` without `await` and without `ContinueWith`-level handling, `async void` outside event handlers) — flag every instance.
   - `dict.get(key)` / `.FirstOrDefault()` / `Optional.get()` results used as non-null without an explicit null check.
   - HTTP responses parsed without checking status code first.

2. **Useless comments.** Delete anything that restates what the code does, repeats the test name, or claims behaviour the code doesn't have (`// Strip SQL-Server-specific bits` on an empty override that strips nothing). Keep only comments that capture a non-obvious WHY — an invariant, a hidden constraint, an ordering rationale. **If a comment lies or rots, delete it. Don't translate, don't paraphrase — delete.**

   Also delete on sight:
   - **Commented-out code blocks.** Git is the version history. Commented-out code is dead weight that rots silently and confuses every future reader who wonders if it's meant to be reactivated. If you need it later, `git log` has it.
   - Section-divider banners (`// ============ HELPERS ============`) — the type/scope already says that.
   - Apology comments (`// FIXME: I know this is ugly`, `// Sorry for the mess`). Either fix or delete the comment; don't ship the apology.

3. **Code added without a stated reason.** Buffers, retries, timeouts, defaults added without a stated reason — `ThrottleWindow + TimeSpan.FromMinutes(1)`, "extra 30s just in case", `try {} catch { return null; }` "for safety", `if (x is not null && x.Value is not null && x.Value.Length > 0)` chains that mirror nothing the API actually returns. **If you can't defend it in one sentence, drop it.**

   Also flag: **auto-discovery / reflection-based registration that scans wider than the intended scope.** `WithToolsFromAssembly(...)`, `Assembly.GetTypes()`-style registration loops, `AddControllers()` without an explicit `[ApiController]` filter, `Scrutor.Scan(...).FromCallingAssembly().AddClasses(...)`, MEF/MAF-style `[Export]` scans, any `@autodiscover` / `@register` decorator-based system whose discovery scope is "the whole assembly" or "the whole repo." Any future `[Marker]`-tagged type added anywhere — including in tests, dev tooling, scaffolding, or copy-pasted snippets — registers automatically and ships on the production endpoint without anyone noticing. **Constrain the scan explicitly**: a namespace filter, a marker interface inside an internal namespace, a hand-enumerated list, or at minimum a log at startup naming every type the scan picked up so reviewers can see what's actually wired.

4. **Boolean-flag API smells.** Methods like `BuildContext(bool authenticated)`, `Foo(bool isAdmin)`, `DoThing(bool dryRun)` where the two branches diverge significantly. Split into two named helpers.

5. **Redundant or unverified DI / service registrations.** Before adding *any* new service registration, verify **two** things:
   - Is the same service already registered explicitly elsewhere? `grep -rn "AddX\|services\.X"` the codebase.
   - Is it registered **transitively** by something already in the pipeline? Common offenders:
     - `AddHybridCache()` registers `IMemoryCache` — don't also `AddMemoryCache()`.
     - `AddIdentityCore()` registers core Identity services; redundant `AddScoped<UserManager<T>>` is wrong.
     - `AddAuthentication()` is registered exactly once per pipeline; calling it twice with different defaults silently overwrites.
     - `AddHttpClient<T>()` registers a typed factory; you don't also need a manually-registered `HttpClient`.
     - `AddRazorComponents()` / `AddServerSideBlazor()` / `AddMvc()` each pull in `IHttpContextAccessor`-adjacent and option-system services.
   - Test it: delete the line and see what blows up. If nothing does, it was wrong.

5a. **Parallel-instance configuration drift.** When the diff adds a *second* instance of a framework primitive the codebase already configures elsewhere (auth scheme, `HttpClient`, `DbContext`, `JsonSerializerOptions`, Polly pipeline, etc.), the new instance must mirror every option the first sets that affects shared framework behaviour. Anything set on one and not on the other is silent divergence — and a hand-rolled helper appearing alongside the new instance is the visible tip of the cascade. **Severity minimum HIGH** for auth/identity drift (silent role bypass), **MEDIUM** for behaviour drift.

   → Full cascade-analysis playbook, grep targets per option, and severity rules: [`references/parallel-instance-config-drift.md`](references/parallel-instance-config-drift.md). Load it when the diff includes any new framework-primitive registration alongside an existing one.

6. **Duplicated / re-invented helpers (textbook).** Before writing new claim-reading, user-context, DB-access, company-scoping, file-validation, or string-normalisation code, `grep` the existing pattern. The codebase has a helper for this already 80% of the time.

   **Cross-layer authority rule (access-control / scoping / authorization specifically):** when reviewing access-control or scoping logic on a new endpoint, service, tool, handler, or background worker, the authoritative spec almost always lives in one of two places already:
   - **The existing service layer** — `*Service`, `*Provider`, `*Repository`, `*AccessHelper`, `*Authorization*` classes that other features already route through. These encapsulate the canonical scope predicate, role checks, soft-delete and status filters, and cross-account access-grant joins.
   - **The Client / UI / Razor / route-handler code** that already enforces the same thing for human users. Pages and components are often the *de-facto* spec because product owners verify them by clicking.

   Read both before accepting any new scoping code. The new code must match — *and if it doesn't match, the deviation is almost certainly the bug.* Especially watch for:
   - **Narrower scope predicates** than the canonical one (e.g. 3-of-5 company foreign keys when the Client uses 5-of-5) — false negatives now, and a silent data-leak the moment someone "fixes" the predicate to match without porting the rest of the gating.
   - **Missing cross-account access-grant joins** (e.g. `AccessControl` / shared-with-company / delegated-permission tables ignored).
   - **Missing fine-grained gating** the Client layers on top (per-part approvals, per-field visibility, per-status redaction) — exposing the parent record without porting these is a data exposure even if the top-level scope matches.
   - **Missing status / lifecycle filters** (archived, deleted, off-market, draft, soft-deleted) that the canonical layer applies. A new endpoint that returns archived/off-market rows is leaking data the UI deliberately hides.

7. **Duplicate functions in disguise — semantic, not textual.** Two functions with different names that do the same thing. LLM-generated code is especially prone. Run `superpowers-lab:finding-duplicate-functions` or at minimum pattern-match: if `IsCompanyOwner(user, companyId)` exists, don't accept new `UserBelongsToCompany(user, companyId)`.

8. **Re-implementations of framework primitives.** Hand-rolled `ConcurrentDictionary<string, DateTime>` for caching when `IMemoryCache` exists. Custom retry loops when `Microsoft.Extensions.Resilience` or Polly is configured. Bespoke JSON serialization when `System.Text.Json` is registered. Hand-rolled rate limiting when the rate-limiter middleware is wired. Flag every one.

9. **Domain-language drift.** Many codebases forbid specific terminology — "tenant" / "tenancy" / "multi-tenant" in single-instance customer-gated systems, "user" vs "account" vs "principal" mixing, region-naming inconsistencies. **Always `grep` the diff for the forbidden terms listed in CLAUDE.md.** Reviewers and LLMs both pattern-match from generic SaaS prose and re-introduce these. Rewrite mercilessly.

10. **Dead code in the diff.** Unused claims, props, fields, ctor params, generic type args, helper methods. Constructor-injected services with no consumer. Boolean flags toggled exactly once. Empty overrides that only call base. `using` statements flagged unused by LSP. New abstractions with exactly one caller. An empty `.csproj` / package / module with no source files. **All of it.**

11. **Test smells.**
   - `await Task.Delay(...)` / `waitForTimeout()` / `sleep(...)` to "make the timing work" — proves nothing, hides races.
   - `{ force: true }` on browser-automation clicks; `page.reload()` to "recover" from app state; retry loops around assertions.
   - `.catch(() => {})` / `.catch(e => console.warn(...))` — swallows assertion failures. The linter's `no-silent-catch` rule covers both. **Fix by removing the catch entirely.** Use `isVisible()` branching if the element is genuinely optional.
   - Throw-away subclasses with empty bodies just to make a private method callable.
   - Tests asserting trivially-true conditions (`Assert.True(items.Any() || !items.Any())`).
   - Tests that "filter" by constructing a `List<T>` in `Arrange`, calling `items.Where(...)` in `Act`, and asserting the count in `Assert` — **these test that LINQ exists, not your code**. Coverage on the actual data-loading path: zero.
   - Tests that pass without exercising the new behaviour they were ostensibly added for. Mutate the production code mentally — does the test still pass? If yes, it tests nothing.
   - Audit fields (`CreatedBy`, `UpdatedBy`, `TenantId`) sourced from request DTOs in test setup. If a security fix would break every test by changing the source to the authenticated principal, that's the smell — the tests baked in a vulnerability.
   - "Flakiness" is not a diagnosis. Every test failure is a bug — in the app or in the test. Find it.

12. **Missing `sealed` / `final` / `@frozen`.** Public classes/types not designed for inheritance should be sealed. Check every new type the diff adds.

13. **`Try*` method names that don't actually try.** If the method now propagates exceptions, drop the `Try` prefix — the name implies semantics it no longer has. Same for `Maybe*`, `Optional*`, `Safe*` wrappers that aren't safe.

14. **Tooling-generated artifacts hand-edited.** Migrations (`Migrations/*.cs` + snapshots), lockfiles (`package-lock.json`, `Cargo.lock`, `poetry.lock`, `Gemfile.lock`), generated OpenAPI/gRPC/protobuf clients, code-gen output. Check every diff hunk in these is *generated*, not edited. Snapshot drift breaks every subsequent migration. **One bad migration silently destroys production data**; the `Down()` path drops the new columns and recreates the old ones empty.

15. **Useless using directives / sloppy imports.** LSP's unused-import warnings — clean while you're in the file. Same for unused npm/pip dependencies added in this diff.

16. **Security checklist** (always, but mandatory when the diff touches auth / input handling / DB / file system / external API / crypto / payment):
   - **Authorization is not UI-only.** If the Razor/page/component gates a destructive action with `user.IsAdmin`, the service and the API controller below it must also gate. UI-only authorization = any authenticated user can hit the endpoint by guessing IDs. **This is the #1 failure pattern in offshore-delivered features. Always check the service + controller, not just the page.**
   - No hardcoded secrets (keys, passwords, tokens, connection strings).
   - User inputs validated at the boundary.
   - SQL via parameterized queries (EF, Dapper, ADO.NET parameters) — never string concatenation.
   - XSS: no `innerHTML` / `dangerouslySetInnerHTML` / Razor `@Html.Raw()` on unsanitized input.
   - **File upload validation must use magic bytes + extension whitelist + sanitized filename.** Browser-supplied `Content-Type` is attacker-controlled. User-supplied filename concatenated into a blob path = path traversal (`../../leak.pdf` works). Flag every upload that trusts the header.
   - **Audit fields (`CreatedBy`, `UpdatedBy`) must come from the authenticated principal**, not from request DTOs. A DTO-supplied audit field is a compliance failure waiting to happen — the audit log becomes whatever the most recent caller said it was.
   - **Tenant/company-scoped data must filter by the principal's scope**, ideally via a global query filter on the `DbContext`. A new entity added without the global filter is silently cross-tenant accessible.
   - **Endpoint authorization policy is more than `RequireAuthenticatedUser`** when the endpoint exposes per-company data. Add `RequireClaim("<company-id-claim>")` and where appropriate `RequireRole(...)` or `RequireScope(...)`. A policy that *only* requires authentication moves the entire access-control surface into ad-hoc query filters.
   - CSRF protection on state-changing forms.
   - **Migrations don't silently destroy data.** A migration that moves a column from table A to table B without backfill is a data-loss event the moment it runs. Same for `Down()` paths that drop new columns. Read every migration end-to-end; check `Up()` *and* `Down()*.
   - Rate limiting on user-input endpoints.
   - Error messages don't leak sensitive data (stack traces, SQL, filesystem paths).
   - Logs don't include raw tokens, passwords, or PII.
   - **Parallel-instance config drift** (hunt #5a) specifically for auth schemes — silent role bypass.

   **If the diff touches any of the above**, dispatch the `security-reviewer` subagent in parallel with your pass.

17. **Leftover artifacts.** Things that should never reach review but routinely do:
   - **Debug print statements** in non-debug code: `console.log`, `Console.WriteLine`, `print()`, `dump()`, `pp`, `dd()`, `var_dump`, `println!`, `eprintln!`. Replace with proper structured logging or delete.
   - **`TODO` / `FIXME` / `XXX` / `HACK` without owner *and* date.** They rot into permanent fixtures. Rule: fix now, file an issue and link it (`// TODO(#1234, alice, 2026-05): …`), or delete. An undated TODO is a lie about future work.
   - **Disabled tests** (`.skip`, `xit`, `it.todo`, `[Ignore]`, `[Skip]`, `@pytest.mark.skip`, `@Disabled`, `t.Skip()`) without a justification comment naming the bug/issue. A silently-skipped test is a test you don't have — and the next reader has no way to know whether it's safe to re-enable.
   - **OS / IDE / editor artifacts** committed: `.DS_Store`, `Thumbs.db`, `desktop.ini`, `.idea/`, personal `.vscode/settings.json`, `*.swp`, `*.bak`, `*.orig` (the latter often a leftover from a merge tool). Move to `.gitignore` and delete from the tree.
   - **Hardcoded local-only values**: `localhost`, `127.0.0.1`, personal email addresses, personal absolute paths (`/Users/jane/…`, `/home/alice/…`, `C:\Users\…`), personal API keys/tokens (those also fail hunt #16).
   - **Misleading file/class/function names** that no longer match contents. The feature got renamed; the identifier didn't follow. Rename in the same diff, or open a follow-up issue and link it from a comment.
   - **Case-drift imports.** `import './Foo'` referencing a file actually named `foo.ts`. Works on macOS/Windows case-insensitive filesystems; breaks Linux CI. Walk imports against the actual filenames.
   - **Empty modules / projects / packages** added "as scaffolding for later." Either ship them with content or don't ship them. Empty `.csproj` files, empty `__init__.py` modules with no exports, empty React component files, an empty crate in a Cargo workspace — all become copy-paste targets that future contributors mimic without checking what they should actually contain.

18. **Architecture documentation that contradicts the code.** If the diff adds a SAD / "solution architecture" / "codebase overview" / C4 diagram, read it end-to-end and grep the code for every claim:
   - Pattern names ("Repository Pattern (Generic + Specific)") — does that pattern actually exist?
   - Library versions (`Rebus 8.4.1`) — match `Directory.Packages.props` / `package.json` / `pyproject.toml`?
   - Identity provider (`ASP.NET Core Identity` vs `Auth0`) — match the actual auth wiring?
   - Table count, service count, integration count — match reality?
   - Existing canonical doc says X; the new doc says Y. **Two architecture-of-record sources = zero architecture-of-record sources.** Either delete the new one or rewrite both to agree.

## Process

1. **Scope.** `git fetch origin && git diff origin/<base>...HEAD --stat`. If reviewing a PR by number: `gh pr view <n> --json title,body,labels,comments` for the business context — external-tool reviewers (Codex/Gemini/OpenCode if you fan out to them) can't read the repo, so the PR title/body is their only intent signal.
1a. **Hard preconditions — fail fast.** Before walking anything, run the bundled conflict-marker scan against the base ref:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/conflict-marker-scan.sh <base-ref>
   # e.g. ${CLAUDE_PLUGIN_ROOT}/scripts/conflict-marker-scan.sh origin/master
   ```

   Any non-zero exit = **hard stop**. Return immediately with the offending paths the script printed; refuse to proceed. Reviewing a diff that contains conflict markers is reviewing nothing — the code in the diff doesn't compile, doesn't run, and any further finding is downstream of an unresolved merge.
2. **Read every changed file end-to-end, not just the diff hunks.** The diff hides context. The 1,000-line god component shows itself only in the full file.
3. **Decide which pre-flight skills + subagents to fan out to** (security-review when auth touched; finding-duplicate-functions when new services; insecure-defaults when config; semgrep when multi-language). Run in parallel where possible — single message, multiple `Agent`/`Skill` invocations.
3a. **Sibling pairwise diff — when the diff adds N near-identical things.** Eight MCP tools, five route handlers, four migration files, three new background services, six new test classes. Don't read them all front-to-back and call it done — put them side-by-side and diff their structure. Differences between siblings are *either intentional (need a comment) or unintentional (the bug)*. Specifically compare across the set:
   - **Query options**: `AsNoTracking()`/`AsTracking()`, `AsSplitQuery()`, `IgnoreQueryFilters()`, command timeout, retry policy.
   - **Input validation**: empty/null/whitespace handling, length caps, value clamping (`Math.Clamp`), allowlist/denylist, type coercion (`int.TryParse`).
   - **Scope predicates**: number of fields in the WHERE clause, soft-delete/status filters, cross-account grants — *if one sibling has 5 fields and another has 3, that's a finding, not a coincidence.*
   - **Error / not-found shape**: same response payload, same HTTP status, same logging level, same exception type.
   - **Authorization gates**: same `[Authorize]` policy, same role check, same claim requirement.
   - **Logging**: same scope, same correlation-id propagation, same redaction.

   The fastest way: open the N files in a tiled view (or `diff -y file1 file2`) and walk top-to-bottom. Anything that doesn't line up is a finding candidate.
4. **For each finding, log concretely**: `file:line — problem — fix`. Group by file so you can edit each once. Tag severity per the project's review rule file.
4a. **Procedural checklist sweep — don't trust memory of the hunt list.** Before declaring the finding set complete, walk every *new type* the diff introduces and check explicitly:
   - **Sealing**: `sealed` / `final` / `@frozen` on every public class/type not designed for inheritance (hunt #12).
   - **Mutability**: `readonly` on every constructor-assigned field; `private set` or init-only on every property not externally mutated.
   - **Visibility**: `internal` (or stricter) on anything not consumed across the assembly boundary; `private` on anything not consumed across the type boundary.
   - **Static**: every method that doesn't read `this` should be `static`.
   - **Async**: every `Task`/`Task<T>`-returning method takes a `CancellationToken`; every `await` has `.ConfigureAwait(false)` in library code (or the project's documented convention).
   - **Disposability**: every `IDisposable`/`IAsyncDisposable` consumer either `using`s or registers ownership.

   Do this as an explicit sweep, not from memory. Hunt items rot in the head; the diff doesn't lie.
5. **Apply the fixes.** Don't ask permission for mechanical cleanups — the user wants to see the result. Do ask for design-level changes (HIGH-or-above architectural calls).
6. **Build the affected project**, e.g. `dotnet build <project>.csproj --nologo` / `npm run build` / `cargo check`. Resolve real errors. LSP staleness errors after a fresh merge usually resolve after a `dotnet restore --force-evaluate` / `npm ci` / `cargo clean && cargo build`.
7. **Run tests touching the changed code**, e.g. `dotnet test --filter "FullyQualifiedName~<TestClassYouAffected>"` / `npx playwright test tests/<file>.spec.ts`. Must be green. If you changed a behaviour test, the test needs to change with it — and the new test must actually exercise the new behaviour (see hunt #11).
8. **Stage the result with `git add`. Do NOT commit.** The user reviews staged diffs before they land. Committing eagerly turns review into post-mortem.

## Output

Two sections, in this order — the compressed block first so it is paste-ready into a PR comment without scrolling.

- **§1 — Paste-ready PR comment block (always first).** Lead with a count-shape summary (`**N findings** — X to add to this PR, Y to file as separate issues, Z blockers.`). Then one numbered line per finding: `N. <file>:L<lines>: <severity-emoji> <severity-word>: <problem>. <imperative-fix>.`. Severity: 🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 LOW. Imperative verbs in the fix half (`Add`, `Move`, `Delete`, `Extract`, `Replace`, `Reject`, `File issue`, `Revert`, etc.). No throat-clearing, no `Hunt #N`, no opaque prefixes (`F1`, `CR1`, `R-001`). Plain English `Pattern` labels.
- **§2 — Full review (verbose, below the compressed block).** Pre-flight notes (warnings + skipped checks only, omit if everything passed), findings table grouped by file with plain-integer numbering, unfixed CRITICAL/HIGH listed for the author's decision, considered-but-left with one-sentence reasons each, three-bucket Skills + tools table mirroring the pre-flight banner, exact build + test commands with pass/fail, trajectory note when the diff establishes a compounding pattern.

→ Full spec including the vocabulary-to-avoid catalog, the §2 findings-table column rules, and a worked example: [`references/output-format.md`](references/output-format.md). Load it before producing the final output.

## The iron law

The hunt list above explains the *why* behind every category. This block is the summary of non-negotiables — the punchline you can paste into a PR review without losing the body's reasoning. Each line maps back to a hunt item you've already walked:

```
NO UNJUSTIFIED ADDITIONS. NO SILENT CATCHES. NO HAND-WRITTEN MIGRATIONS. NO UI-ONLY AUTHZ.
NO EAGER COMMIT — STAGE ONLY.
```

If you can't defend a line in one sentence, drop it. If a test passes without exercising the new code, it doesn't exist. If authorization is in the UI but not the service, the feature is open to anyone with `curl`. If a migration moves data without backfilling, you just shipped a data-loss event. If you committed before the author saw the staged diff, you turned review into post-mortem.

## Red flags — STOP

If you catch yourself thinking any of these, you're doing a current-check, not a future-check:

- "It's only a small addition — fine to merge."
- "The tests are green, ship it."
- "External reviewer agreed, must be right." (Three LLMs sharing the same blind spot is not consensus.)
- "I'll fix it in a follow-up." (No, you won't. Nobody does. Fix it now or open the issue now.)
- "The author is more senior than me." (Not relevant. The diff stands on its own.)
- "Pre-existing code is worse." (Pre-existing code isn't in *this* diff.)
- "Adding a comment would explain it." (If it needs a comment to be defensible, it needs a refactor.)
- "It's the offshore team's convention." (The codebase's convention overrides every team's local one.)
- "Time-pressured release, accept it for now." (The trajectory cost compounds; the schedule pressure doesn't.)

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "Code review passed, build is green, tests pass." | A reviewed-and-green diff can still ship the wrong thing — tests can assert that LINQ exists, builds compile around UI-only authz, reviewers can rubber-stamp 200-file PRs. Pass means nothing without the second optimisation. |
| "We can clean it up later." | Six months later, migration #6 is migration #36, half of them defensive raw SQL. The clean-up cost compounds; the dirty-add cost is one PR. Fix now is cheaper than fix later, always. |
| "AI generated it, that's the new normal." | AI optimises for the current check. You're the second optimisation. If you abdicate, the file becomes the file nobody dares touch. |
| "The author already pushed back on review." | Push back again. Push back with file:line and the rule it violates. Politeness isn't the goal; the codebase is. |
| "Style isn't worth blocking on." | Selective styleguide bypass is how inconsistency compounds. Same diff, two patterns, no consistency — the next contributor copies whichever they happened to land on. |
| "It works in the demo / local / staging." | "It works" is the cheapest claim in software. Show it works under concurrent writes, on the cold path, with the wrong claims, with a malformed upload. |
| "Authorization is enforced by the UI." | Authenticated user + curl = pwn. Always check the service + controller. UI-only authz is the #1 failure pattern in outsourced features. |
| "The reviewer's nitpicks are slowing us down." | The reviewer's nitpicks are the only thing keeping the 11x year from inverting into the cleanup year. Slowing down is the work. |

## Required reading order (recap)

1. `CLAUDE.md` and any per-area `CLAUDE.md` extensions, plus `AGENTS.md`/`GEMINI.md` if present.
2. `.claude/rules/common/code-review.md`, `security.md`, `post-review-agent.md` (silent-failure scan).
3. `.claude/rules/<stack>/*.md` for the diff's primary language.
4. `docs/agents/ef-migrations.md` (or equivalent migrations doc) if migrations touched.
5. Project styleguide / Storybook / playground page if UI touched.
6. Existing helpers in `src/.../Services/` (or equivalent) before writing new ones for claim-reading, user-context, DB access.
7. Existing tests for the test-pattern conventions before writing new ones.

## Out of scope

- Pre-existing code outside the diff, unless it's truly load-bearing for the cleanup.
- Refactors for personal preference where the codebase already has a consistent convention.
- Adding features. Reformatting unchanged files. Renaming public API surfaces that aren't in the diff.
- Drive-by upgrades of dependencies, SDK versions, or agent frameworks bundled into an unrelated feature PR. **"While I'm here" is how a 5,000-line feature becomes an 80,000-line commit nobody can review.**

## The bottom line

Every diff is on a trajectory. The current check asks *does it work today?* The future check asks *what does this lock the team into for the next six months?* v-review is the second question, asked with the same tools the first one had — minus the deference, minus the schedule pressure, plus the willingness to say no.
