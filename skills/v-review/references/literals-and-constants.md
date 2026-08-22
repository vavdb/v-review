# Literals where a constant already exists — reference

Backs hunt #21. Load it when the diff adds string literals, or when
`scripts/literal-scan.sh` returns candidates.

## The rule

A literal is a finding when **any** of these is true:

1. The platform already names the value (`"application/json"` →
   `MediaTypeNames.Application.Json`).
2. This repo already names it (`const`, `static readonly`, enum member).
3. It is typed in 2+ places — a de-facto constant nobody extracted.
4. It sits in a position that takes a *member* name (`nameof` territory).

A literal used exactly once, in one place, with no platform equivalent and
no repo constant, is **fine**. Do not manufacture a `Constants` class for a
single call site — that trades one problem for another and is its own smell.

## Why this category matters more than it looks

The damage isn't ugliness, it's **drift**. Two copies of a value that must
agree, with nothing forcing them to. The literal is fine on the day it is
typed and wrong the day someone changes one copy. The authorization case is
the sharp end: `[Authorize(Policy = "Admin")]` against
`AddPolicy("Administrator", ...)` compiles, deploys, and fails closed for
everyone — or, with the roles inverted, fails open. Neither shows up in a
test that only exercises the happy path with a seeded admin.

## Standards with a BCL home

| Literal shape | Use instead | Notes |
|---|---|---|
| `"nl"`, `"en"`, `"de"` | `CultureInfo` / `.TwoLetterISOLanguageName` | ISO 639-1. A bare two-letter string is a *language*, not a culture — mixing the two is the actual bug |
| `"nl-NL"`, `"en-US"` | `CultureInfo.GetCultureInfo(...)` | BCP-47. Never `new CultureInfo(...)` in a loop — `GetCultureInfo` is cached |
| `"NL"`, `"DE"` (country) | `RegionInfo.TwoLetterISORegionName` | ISO 3166-1 alpha-2 |
| `"EUR"`, `"USD"` | `RegionInfo.ISOCurrencySymbol` | ISO 4217 |
| `"W. Europe Standard Time"` / `"Europe/Amsterdam"` | `TimeZoneInfo.FindSystemTimeZoneById(...)` | .NET 6+ accepts **both** Windows and IANA ids on all platforms. Hardcoding one form is a portability bug that only shows up on the other OS |
| `"application/json"`, `"text/csv"` | `System.Net.Mime.MediaTypeNames.*` | |
| `"Authorization"`, `"Content-Type"` | `Microsoft.Net.Http.Headers.HeaderNames.*` | |
| `"GET"`, `"POST"` | `HttpMethods.*` (ASP.NET Core) / `HttpMethod.*` (client) | |
| `200`, `"OK"` | `StatusCodes.Status200OK` / `HttpStatusCode.OK` | |
| `"Bearer"`, `"Cookies"` | `JwtBearerDefaults.AuthenticationScheme`, `CookieAuthenticationDefaults.AuthenticationScheme` | Scheme-name typos fail *silently* — the scheme just never matches |
| `"sub"`, `"role"`, `"email"` | `ClaimTypes.*` / `JwtRegisteredClaimNames.*` | Which one depends on `MapInboundClaims`. Pairs with the parallel-instance config-drift reference |
| `"utf-8"` | `System.Text.Encoding.UTF8` | Watch the BOM difference vs `new UTF8Encoding(false)` |
| `"yyyy-MM-dd"` repeated | one named const, or `"o"` / `"R"` / `"s"` round-trip specifiers | A scattered custom format string is a serialization bug waiting for one copy to change |
| `typeof(X).Name` used as a key | a const | Refactor-fragile in the other direction: renaming the type silently changes the key |

## Project-owned values that belong in constants

These have no BCL home, so the repo has to name them. Each one is a
drift-pair waiting to happen:

- **Authorization policy + role names** — `[Authorize(Policy = "…")]`,
  `AddPolicy("…")`, `RequireRole("…")`, `IsInRole("…")`. **HIGH minimum.**
- **Configuration keys** — `Configuration["Foo:Bar"]` literals. Prefer
  `IOptions<T>` binding with a const section name over indexer access.
- **Cache keys**, **feature-flag names**, **queue / topic / subscription
  names**, **blob container names**, **HTTP client names** (the string
  passed to `AddHttpClient("name")` and `CreateClient("name")` must match —
  a mismatch silently yields a default-configured client with none of the
  handlers).
- **Log message property names** used for structured-log queries.
- **`data-testid` values** duplicated between a `.razor` component and its
  `.spec.ts` test. Pairs with `playwright-test-reviewer` — this is the
  selector-consistency check from the test side. Note the scan only sees the
  `.razor` half (it is C#-scoped); the `.spec.ts` half is that reviewer's job,
  which is why the two agents pair-flag this rather than either owning it.

## `nameof` positions

A member name written as a string breaks silently on rename:

- `ArgumentNullException` / `ArgumentException` / `ArgumentOutOfRangeException`
  parameter names → `nameof(param)` (or `ArgumentNullException.ThrowIfNull`,
  which supplies it via `CallerArgumentExpression`).
- EF Core `.Property("X")`, `.Include("Nav")`, `.HasIndex("Col")`,
  `.OwnsOne("…")`, `.Ignore("…")`.
- `OnPropertyChanged("X")` / `INotifyPropertyChanged` — or
  `[CallerMemberName]`.
- `[Display(Name = "…")]` when the value is a member name rather than
  user-facing copy.

## Strings where an enum exists

- `status == "Active"` where a `Status` enum exists → compare the enum.
- A new string parameter or property with 3–5 known values → it is an enum.
  "We might add more later" is an argument *for* the enum, not against it.
- `Enum.Parse` on external input → `Enum.TryParse(..., ignoreCase: true, out …)`
  with an explicit failure path. `Enum.Parse` throws on anything unexpected;
  `Enum.TryParse` succeeding does **not** mean the value is defined —
  `Enum.IsDefined` is the check for that, and it's the one people skip.
- Enum persisted as a string without an agreed `HasConversion` /
  `[JsonStringEnumConverter]` → the storage format is now an accident.
  Changing a member name later becomes a data migration.

## Running the scan

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/literal-scan.sh <base-ref>
```

**Scope: C#/.NET source only** — `.cs`, `.csx`, `.razor`, `.cshtml`, `.aspx`, `.ascx`, `.asax`, `.ashx`, `.asmx`, `.master`, `.xaml`, `.axaml`. The markup dialects are in scope on purpose: a magic string in a `.razor` is the same finding as one in a `.cs`. Generated output (`.Designer.cs`, `.g.cs`, `*ModelSnapshot.cs`, `obj/`, `bin/`) is excluded on both the diff side and the search side — nobody hand-wrote it, so a literal in it isn't a review finding. A diff with no C# in it exits 0 with a message.

Four passes: BCL-equivalent literals, repo-named literals (const / static
readonly / enum member), `nameof` positions, and policy/role drift. Output
is a **candidate list**. Read each hit before writing it up — the script
cannot tell a genuine duplicate from a coincidence, and a review full of
false positives gets ignored wholesale.
