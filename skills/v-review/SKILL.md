---
name: v-review
description: Use when reviewing a branch, commit, PR, or staged+uncommitted diff before it merges or ships — the "future-check" review pass. Triggers on requests like "review this branch", "review my PR", "look at the diff", "is this ready to merge", and on pre-merge/pre-push gates. Catches what current-check reviews miss: silent failures, cargo additions, duplicate helpers, framework re-implementations, parallel-instance config drift, and dead abstractions. Not for personal-style nits or generated-file-only diffs.
---

# v-review

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
| `claude-mem:mem-search` | **First.** Was this work attempted before? Prior decisions, abandoned approaches, known landmines? Search before forming opinions. |
| `superpowers:systematic-debugging` | If the diff is a fix — was the root cause actually identified, or was a symptom patched? |
| `differential-review:differential-review` | Non-trivial diff. Security-focused review with blast-radius scoring, git-history context, test-coverage check. |
| `superpowers-lab:finding-duplicate-functions` | New helpers/services/domain logic added. Catches functions that do the same thing under different names — *exactly* the "re-implementation instead of reuse" case. Especially important for LLM-generated code. |
| `insecure-defaults:insecure-defaults` | Diff touches config, env vars, secrets, auth setup, service registration. Catches fail-open patterns. |
| `static-analysis:semgrep` | Multi-language diffs or pre-protected-branch merges. |
| `static-analysis:codeql` | Deeper interprocedural taint/dataflow on security-sensitive code (auth, payments, user-input handling). |

### Subagents to dispatch in parallel (if installed)

These `subagent_type` names are **common in the third-party-plugin ecosystem (superpowers, Cursor, marketplace plugins, per-repo `.claude/agents/` files) but are NOT bundled with anything by default.** Run the availability check above before assuming any of them exist. If absent in this session: fall back to the `Explore` or `general-purpose` subagent with an explicit prompt that pins down what you want it to check (or invoke the closest skill-tool equivalent — `differential-review:differential-review` substitutes for `code-reviewer`/`security-reviewer` in most cases).

- **`code-reviewer`** — general code quality, an independent second opinion after your own pass. (Skill substitute: `differential-review:differential-review`.)
- **`security-reviewer`** — OWASP, injection, hardcoded secrets, auth bypasses. **Mandatory pass** when the diff touches anything security-sensitive (see hunt-list #16) — if the subagent is absent, the pass must happen via a Skill invocation or via Explore with a security-focused prompt.
- **Language-specific reviewer** — `csharp-reviewer`, `typescript-reviewer`, `python-reviewer`, etc. Match the diff's primary language.
- **`database-reviewer`** — migrations, schema mods, query changes.
- **`aws-reviewer`** / **`gcp-reviewer`** — CDK/CloudFormation/Terraform, IAM, deploy config.

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
   - `catch (Exception) { LogWarning(...); /* swallow */ }` — narrow to specific exceptions, propagate, or escalate to `LogError` with telemetry. Warning-level on a swallowed exception is the cargo-cult "I caught it but didn't really handle it" pattern.
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

3. **Cargo additions.** Buffers, retries, timeouts, defaults added without a stated reason — `ThrottleWindow + TimeSpan.FromMinutes(1)`, "extra 30s just in case", `try {} catch { return null; }` "for safety", `if (x is not null && x.Value is not null && x.Value.Length > 0)` chains that mirror nothing the API actually returns. **If you can't defend it in one sentence, drop it.**

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

5a. **Parallel-instance configuration drift.** When the diff adds a *second* instance of a framework primitive the codebase already configures elsewhere — a second auth scheme, a second `HttpClient`, a second `DbContext` registration, a second `JsonSerializerOptions`, a second logger sink, a second Polly/resilience pipeline, a second CORS policy, a second rate-limiter partition, a second FluentValidation registration — **the new instance must mirror every option the first instance sets that affects shared framework behaviour**. Anything set on one and not on the other is silent divergence the framework will not warn about.

   How to catch it:
   - **Find the existing instance.** `grep -rn "Add<Same>"` for the same registration method. Read its options block in full.
   - **Diff options field-by-field** against the new instance. Common categories:
     - **Claim/identity mapping** (auth schemes): `RoleClaimType`, `NameClaimType`, `MapInboundClaims`, `TokenValidationParameters`, `Events.OnTokenValidated`.
     - **Wire protocol** (HTTP clients): `BaseAddress`, `Timeout`, `DefaultRequestHeaders`, handler chain, retry/circuit-breaker policies.
     - **Serialization**: naming policy, null handling, custom converters, max-depth, reference-handling.
     - **Database**: connection string source, query splitting behaviour, lazy loading, command timeout, retry-on-failure.
     - **Logging**: minimum level, enrichers, output template, scope handling.
     - **Validation**: severity defaults, language manager, cascade mode.
   - **Tell-tale: a hand-rolled helper appears alongside the new instance** that re-implements something the framework would normally do (manual claim string-matching instead of `User.IsInRole`, manual JSON parsing instead of model binding, manual log enrichment, manual retry loop). That helper exists *because* the new instance is mis-configured and the standard mechanism returned nothing useful. **Don't accept the helper — fix the instance's options to match its sibling.**
   - **Severity minimum HIGH for auth/identity drift** (silent role bypass when a future caller adds `[Authorize(Roles=...)]`); **MEDIUM for behaviour drift** (HTTP/serialization/DB instances that disagree under edge conditions).

   **Cascade analysis — required when the missing/divergent option is identity-mapping or framework behaviour the codebase reads via a shared abstraction.** When you find that a new instance is missing an option, the local workaround is the tip; the cascade through dependent middleware, interceptors, audit-field providers, cache services, and provisioning hooks is the iceberg. **Grep every consumer of the affected primitive and check whether each one survives the new scheme.**

   Concrete examples of what to grep when the missing option is:
   - **`RoleClaimType` / `NameClaimType` / `MapInboundClaims`** → grep `IsInRole(`, `Identity.Name`, `Identity?.Name`, `User.FindFirst(ClaimTypes.Role)`, audit-field providers (`ICurrentUser*`, `*UserContext`, `*Principal*`), any DB interceptor that reads the principal, any `ISkin*UserService` / `ICurrentUser*` / `IAuditContext` consumer. Each one breaks on the new scheme.
   - **`Events.OnTokenValidated`** (user provisioning, role sync, account creation) → the new scheme that lacks the hook means JWT-only callers never get an `ApplicationUser`/`AspNetUsers` row, never have roles synced to local Identity tables, and never have downstream foreign-key fields (e.g. `CompanyId` on the local user row) populated. Latent asymmetry — works in dev, breaks the first time a write tool hits the schema.
   - **`HttpClient` handler chain / Polly resilience pipeline** → grep for the existing `AddHttpClient<T>().AddHttpMessageHandler<X>()` registration; if the new client doesn't replicate the chain, retries/circuit-breakers/correlation-id propagation silently disappear on the new path.
   - **`JsonSerializerOptions`** → grep `JsonSerializer.Deserialize`/`Serialize` call sites and any model-binding configuration. A new options instance with different naming policy means the same payload deserializes differently depending on which call site reads it.

   The pattern: if a hand-rolled workaround appears alongside the new instance, that workaround is the *visible* symptom of a cascade. Find the rest before signing off.

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
   - **Empty modules / projects / packages** added "as scaffolding for later." Either land them with content or don't land them. Empty `.csproj` files, empty `__init__.py` modules with no exports, empty React component files, an empty crate in a Cargo workspace — all become cargo-cult targets that future contributors copy-paste into.

18. **Architecture documentation that contradicts the code.** If the diff adds a SAD / "solution architecture" / "codebase overview" / C4 diagram, read it end-to-end and grep the code for every claim:
   - Pattern names ("Repository Pattern (Generic + Specific)") — does that pattern actually exist?
   - Library versions (`Rebus 8.4.1`) — match `Directory.Packages.props` / `package.json` / `pyproject.toml`?
   - Identity provider (`ASP.NET Core Identity` vs `Auth0`) — match the actual auth wiring?
   - Table count, service count, integration count — match reality?
   - Existing canonical doc says X; the new doc says Y. **Two architecture-of-record sources = zero architecture-of-record sources.** Either delete the new one or rewrite both to agree.

## Process

1. **Scope.** `git fetch origin && git diff origin/<base>...HEAD --stat`. If reviewing a PR by number: `gh pr view <n> --json title,body,labels,comments` for the business context — external-tool reviewers (Codex/Gemini/OpenCode if you fan out to them) can't read the repo, so the PR title/body is their only intent signal.
1a. **Hard preconditions — fail fast.** Before walking anything, scan the diff for unresolved git conflict markers:
   ```bash
   git diff origin/<base>...HEAD | grep -nE '^\+(<{7}|={7}|>{7})( |$)' && echo "CONFLICT MARKERS PRESENT"
   ```
   Any hit = **hard stop**. Return immediately with the list of offending files; refuse to proceed. Reviewing a diff that contains conflict markers is reviewing nothing — the code in the diff doesn't compile, doesn't run, and any further finding is downstream of an unresolved merge.
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

Two sections, in this order — the compressed block first so it's paste-ready into a PR comment without scrolling.

### 1. Paste-ready PR comment block (always first, always at the top)

A `caveman-review`-style compressed block. Two parts:

**Lead line — count-shape summary.** Tell the reader the *shape* of the review in one line, with concrete numbers. Pattern: `**N findings** — X to add to this PR, Y to file as separate issues, Z blockers.` (If `Z = 0`, write "no blockers" rather than "0 blockers".) Reader knows what they're in for within one line, without scanning the list.

**Then one numbered line per finding.** Format: `N. <file>:L<lines>: <severity-emoji> <severity-word>: <problem>. <imperative-fix>.` Plain integers — never opaque prefixes like `F1`/`CR1`/`R-001`. Severity emoji: 🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🔵 LOW. Same numbers as the §2 findings table so the two sections cross-reference.

**Every fix half must start with an imperative verb** so the reader sees the action immediately. Catalog: `Add`, `Move`, `Delete`, `Extract`, `Inline`, `Rename`, `Mark`, `Replace`, `Reject`, `File issue`, `Revert`, `Wrap`, `Split`, `Combine`. Avoid passive prescriptions like "Pick one layer", "Let X own", "Consider refactoring", "Maybe rework".

**No throat-clearing, no prose, no per-line "consider" or "you might want to".** Designed to paste directly into a GitHub PR review comment without editing.

**Vocabulary to avoid (jargon that reads as opaque to non-reviewers):** `fold in` (write `add to this PR`); `land` (write `merge`); `ship it` (write `merge`); `site` to mean "place in code" (write `place` or `call site`); `bucket` to mean "group" or "category" (write the plain word); `dispatched` / `dispatch` (write `ran` or `invoked`); `registered` / `registry` (write `installed` / `list of installed X`); `mandated` (write `required`); `ecosystem` (write `plugins` or `set of tools`); `dish` / `meatball` / `cargo` as standalone framings (name the underlying symptom directly). Also: never write `Hunt #N` or `step Na` in output — those are skill-internal references, not for the reader. **And: do not apply this same jargon in the prose around the output.** If the skill body itself slips into jargon, fix it.

If `caveman:caveman-review` is installed (see availability check), you *may* dispatch it to do the compression; otherwise apply these rules inline. The block must exist either way.

Example:
```
**8 findings** — 3 to add to this PR, 5 to file as separate issues. No blockers.

1. PR-wide: 🟡 MEDIUM: no tests for silent bug fix + new region picker. Add a bUnit or Playwright case before merge.
2. ProductDialog.razor:L296-302: 🔵 LOW: 4th place in the codebase loading company-with-countries (also EditCompany:L639, AddNewRequest:L153, CreateNewProject:L509). Extract `CompanyQueries.GetWithCountriesAsync(ids)`.
3. ProductDialog.razor:L296-304, L334: 🔵 LOW: duplicated dedup — runs 2-3× across server query + `AddCountries` filter. Delete server `GroupBy`; let `AddCountries` handle uniqueness alone.
…
```

Then a horizontal rule (`---`), then §2.

### 2. Full review (verbose, below the compressed block)

Everything below is for the author/reviewer dialogue — not the PR comment. Order:

- **Pre-flight notes — warnings and skipped checks only.** Do *not* list every passing precondition (clean conflict scan, passing sibling diff, passing procedural sweep) — that's noise the reader has to skim past to reach the findings. List only items that are warnings, skipped checks, missing tooling, or otherwise required the reviewer to do something the reader needs to know about. If every pre-flight item passed, **omit the section entirely**. Example of what *to* surface: `⚠️ subagents differential-review and security-reviewer not registered in this session — walked their hunt-list items manually; coverage is thinner than with them available.` Example of what *not* to surface: `✅ conflict-marker scan: clean`.
- **Findings table** covering every cleanup, with severity per finding. One row per finding, grouped by file. Severity per the project's rule file (CRITICAL / HIGH / MEDIUM / LOW or equivalent). **Number findings plainly: `1`, `2`, `3`, …** so later sections (trajectory note, follow-up issues, §1 PR comment) can cite them. Do *not* invent opaque prefixes like `F1`, `CR1`, `R-001` — they look like project-specific tracker IDs and confuse the reader. Plain integers, nothing else.
  - **Columns**: `#`, `File:line`, `Severity`, `Pattern`, `Finding`.
  - **`Pattern` column uses plain-English labels**, not the skill's internal hunt numbers. Catalog: `missing tests`, `duplicated query`, `redundant code`, `silent failure`, `framework drift`, `cascading drift`, `dead code`, `cargo addition`, `UI-only authz`, `hand-edited generated file`, `unsafe migration`, `leftover artifact`, `architecture drift`, `code sweep` (for procedural-sweep catches), `sibling mismatch` (for pairwise-diff catches). Pick the closest label; coin a new plain-English one if none fits. Never write `Hunt #N` or `step Na` in this column — those are internal-to-the-skill, not for the reader.
  - **Findings copy uses imperative verbs in the fix half** (`Add`, `Move`, `Delete`, `Extract`, `Inline`, `Rename`, `Mark`, `Replace`, `Reject`, `File issue`, `Revert`, `Wrap`, `Split`, `Combine`). Same rule as §1.
- **Unfixed CRITICAL/HIGH** listed separately for the user's decision (design-level concerns, architectural calls, risky migrations).
- **Considered-but-left**, with a one-sentence reason each (e.g. "`DateTime.UtcNow` vs injected `TimeProvider` — codebase uses `DateTime.UtcNow` everywhere; introducing a new abstraction for one file is inconsistent"). This is the future-check operator's signature — the things you *didn't* change tell the reader what the codebase's actual posture is.
- **Skills + tools used** — a three-bucket table mirroring the pre-flight banner: `subagents dispatched`, `skills invoked` (with one-line headline output each), `skills available but not invoked` (with one-phrase skip reason each). `not-installed` subagents go in a fourth row only if their absence materially limited the review. Never collapse the categories.
- **Exact build + test commands** you ran, with pass/fail.
- **Trajectory note** when applicable: if the diff establishes a pattern that will compound (e.g. "this is the third hand-rolled retry loop in the codebase — Polly is already configured, recommend a follow-up to consolidate"), call it out. Trajectory is the future-check signal.

## The Iron Law

```
NO CARGO ADDITIONS. NO SILENT CATCHES. NO HAND-WRITTEN MIGRATIONS. NO UI-ONLY AUTHZ.
NO EAGER COMMIT — STAGE ONLY.
```

If you can't defend a line in one sentence, drop it. If a test passes without exercising the new code, it doesn't exist. If authorization is in the UI but not the service, the feature is open to anyone with curl. If a migration moves data without backfilling, you just shipped a data-loss event.

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
