# Modern C# / .NET — version-gated review reference

Load this when the diff's primary language is C#. It exists so the reviewer
stops flagging against a stale mental model (C# 12 / .NET 8) and stops
suggesting syntax the project can't compile.

## Read the target first — this is not optional

Before flagging *anything* as "should use the modern form", establish what
the project can actually compile:

```bash
grep -rn "TargetFramework\|LangVersion\|Nullable\|TreatWarningsAsErrors\|AnalysisLevel\|EnforceCodeStyleInBuild" \
  Directory.Build.props **/*.csproj 2>/dev/null
```

- `<TargetFramework>` / `<TargetFrameworks>` — which BCL surface exists.
- `<LangVersion>` — which syntax compiles. Absent means the SDK default for
  the TFM (`net10.0` → C# 14, `net9.0` → C# 13, `net8.0` → C# 12).
- `<Nullable>` — whether NRT findings are enforceable or advisory.

**A "use `field`" finding on a `net8.0` project is a false positive and
costs you the reviewer's trust for the rest of the review.** Every row in
the tables below carries the version that introduced it. Check it.

## Language features by version

| Feature | Since | Flag when you see |
|---|---|---|
| `field` keyword | C# 14 | Hand-written backing field whose only job is a trivial validation or normalisation setter |
| Extension members (extension blocks: properties, static members, operators) | C# 14 | A `static` helper class of `this`-parameter methods that wants to be an extension *property* or *static member* |
| Null-conditional assignment (`x?.Y = z`, `x?.Y += z`) | C# 14 | `if (x is not null) x.Y = z;` boilerplate. Note `++`/`--` are still **not** allowed |
| User-defined compound assignment operators | C# 14 | Hand-rolled `Add`-then-reassign on a mutable value type in a hot path |
| Partial constructors / partial events | C# 14 | Source-generator-adjacent code that hand-writes what a partial member would let the generator supply |
| `nameof` on unbound generics (`nameof(List<>)`) | C# 14 | A hardcoded generic type-name string |
| `params` collections (`params ReadOnlySpan<T>`, `params IEnumerable<T>`) | C# 13 | `params T[]` on a hot path, forcing an array allocation per call |
| `\e` escape sequence | C# 13 | `""` / `"\x1b"` for ESC |
| `System.Threading.Lock` | .NET 9 | `private readonly object _lock = new();` + `lock (_lock)` — the dedicated type is faster and cannot be accidentally locked on elsewhere |
| `Guid.CreateVersion7()` | .NET 9 | `Guid.NewGuid()` used as a **clustered PK** — random v4 guids fragment the index. Pairs with `database-schema-reviewer` |
| `SearchValues<T>` | .NET 8 | `char[]` + `IndexOfAny` / repeated `Contains` on a hot path |
| `FrozenDictionary` / `FrozenSet` | .NET 8 | A `static readonly Dictionary` built once at startup and only ever read |
| `.GetAlternateLookup<...>()` | .NET 9 | `dict[span.ToString()]` — allocating a string purely to do a lookup |
| `[GeneratedRegex]` | .NET 7 | `new Regex(...)` constructed inside a method body |
| `DateOnly` / `TimeOnly` | .NET 6 | `DateTime` carrying a date-only or time-only value, guarded by `.Date` discipline |
| `IAsyncEnumerable<T>` | C# 8 | `Task<List<T>>` that buffers an unbounded read into memory |
| Primary constructors, collection expressions, `required`, file-scoped namespaces | C# 11–12 | Already the baseline. Flag the verbose form only when the file's neighbours use the modern one |

## Platform features with review consequences (.NET 10)

- **Minimal API built-in validation** — `AddValidation()` + DataAnnotations
  validates body, query, route, and header values natively. On `net10.0`, a
  diff that adds FluentValidation / MiniValidation / a hand-rolled validator
  for ordinary `[Required]`/`[Range]`/`[EmailAddress]` shapes is **hunt #8**
  (framework re-implementation). It is *not* a finding when the project
  already standardises on FluentValidation — consistency beats novelty.
- **EF Core 10 `LeftJoin` / `RightJoin`** — first-class LINQ operators.
  `GroupJoin` + `SelectMany` + `DefaultIfEmpty` gymnastics is now the legacy
  shape; flag it in new code on EF 10.
- **EF Core 10 named query filters** — multiple filters per entity type,
  each independently disableable. This **raises the severity of blanket
  `IgnoreQueryFilters()`**: on EF 10 the tenant filter no longer has to be
  collateral damage when you want to bypass the soft-delete filter. Blanket
  bypass on EF 10 = HIGH, not MEDIUM.
- **EF Core 10 JSON column updates** (SQL Server 2025 / Azure SQL) — complex
  properties mapped to JSON columns are now updatable. Hand-rolled
  serialize-whole-document-and-overwrite patterns are re-implementations.
- **OpenAPI 3.1 is the default document version** — full JSON Schema
  2020-12. Nullable types no longer emit `nullable: true`; they emit a
  `type` array including `"null"`. Any downstream Swagger UI, client
  code-gen, or contract test pinned to 3.0 breaks. If the diff upgrades the
  TFM and the repo has generated clients or contract tests, that's a
  **contract-drift finding**, not a footnote.
- **ASP.NET Core Identity passkeys** — `SignInManager` / `UserManager`
  methods plus an Identity schema table. Hand-rolled WebAuthn on `net10.0`
  is a re-implementation. Caveat: it is deliberately scoped to
  authentication, *not* a general-purpose WebAuthn library — don't flag a
  genuine general-purpose WebAuthn need as duplicate.

## Breaking changes to hunt in the diff (C# 13 → C# 14 / .NET 10)

These compile-or-behaviour changes bite on TFM upgrades. If the diff bumps
`<TargetFramework>`, walk all three:

1. **Span overload resolution.** New built-in span conversions and type
   inference rules mean a call site can bind to a *different overload* than
   it did on C# 13 — or become ambiguous and fail to compile. Any
   `Span<T>`/`ReadOnlySpan<T>`/array/`string` overload set touched by an
   upgrade diff needs its binding confirmed, not assumed.
2. **Attribute target validation is now enforced.** Attributes that were
   previously accepted-but-silently-ignored now error. A build that suddenly
   fails here is surfacing a latent bug: that attribute was never doing
   anything.
3. **`scoped` is always a lambda parameter modifier.** Code that used
   `scoped` as a type name in a lambda parameter position no longer compiles.

## Analyzer suppression — the top agent tell

None of the above matters if the diff turns the analyzers off. Grep every
diff for the silence-instead-of-fix moves:

```bash
git diff <base>...HEAD | grep -nE '^\+.*(#pragma warning disable|SuppressMessage|<NoWarn>|dotnet_diagnostic\..*severity *= *none|GenerateDocumentationFile>false|TreatWarningsAsErrors>false)'
```

- `#pragma warning disable` added without a same-line justification comment
  naming *why the warning is wrong here* → finding.
- `[SuppressMessage]` with a `Justification` of `"<Pending>"` → finding. That
  string is the IDE's placeholder; nobody came back.
- `.editorconfig` severity downgraded (`warning` → `suggestion`/`none`) in a
  feature diff → finding. Rule changes belong in their own commit with a
  stated reason, not smuggled inside a feature.
- `<NoWarn>` entries added to a `.csproj` → finding.
- `<TreatWarningsAsErrors>` removed or flipped to `false` → **HIGH**. That's
  a project-wide quality gate being disabled to land one diff.
- `<Nullable>` downgraded from `enable` to `annotations`/`disable` → HIGH.
- `!` (null-forgiving operator) added anywhere the nullability can't be
  proven by a preceding check → finding. `!` is an assertion, and an
  unproven assertion is a `NullReferenceException` with extra steps.

## Build-step additions for C# projects

Add these to the Process build/test step when the diff is C#:

```bash
dotnet format --verify-no-changes          # style gate, no excuses
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated
```

`--include-transitive` is the one that matters — the direct dependency list
is rarely where the CVE lives. A diff that adds a package reference without
this check is untested surface.
