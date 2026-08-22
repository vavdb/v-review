# Dependency provenance + hallucinated APIs — reference

Backs hunt #25. Load it whenever the diff adds a package reference, or calls
an API you can't immediately place.

## Why this is a distinct hunt

Hunt #3 asks *should this dependency exist at all* — the justification
question. This one asks something the justification question never reaches:
**is this package the package you think it is, and does this API exist?**

The base rate is not negligible. Current frontier models hallucinate package
names in roughly **4.6%–6.1%** of package-bearing answers (open-source models
reach 21.7%), and — the part that turns a mistake into an attack — **~43% of
hallucinated names recur across queries**. A name that a model invents
repeatably is a name an attacker can register in advance and wait on. The
attack has a name: **slopsquatting**.

The trap for reviewers: **`dotnet restore` succeeding proves nothing.** A
slopsquatted package restores perfectly. That's its entire purpose. Build-green
is not provenance.

## Running the scan

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/package-scan.sh <base-ref>
# --offline to skip the nuget.org lookups (then do them by hand — say so in the review)
```

Extracts every `<PackageReference>` / `<PackageVersion>` added in `.csproj`,
`.props`, `.targets`, and checks each against nuget.org: existence, download
count, owners, verified prefix, whether the pinned version is actually
published, and whether a far-more-popular package has a near-identical id.
Offline it still catches wildcard/range versions and Central Package
Management overrides.

## What to check per new package

1. **Does it exist on nuget.org?** If not: CRITICAL, and the *only* two
   innocent explanations are a private feed or a typo. Both are answerable in
   one sentence — and if a private feed supplies it, **the PR must say so**,
   because a reviewer cannot distinguish "internal package" from "invented
   package" by reading the diff.
2. **Is it the canonical id?** Compare against the popular package it
   resembles. `Newtonsofte.Json`, `Serilogg`, `Microsoft.Extensions.Loging` —
   one character, total compromise. The scan flags a near-identical id with a
   small fraction of the reach; a legitimate sibling (`Newtonsoft.Json.Bson`)
   won't trip it.
3. **Owner and verified prefix.** `Microsoft.*`, `System.*`, and other
   reserved prefixes are enforced by nuget.org — a package claiming that
   shape without the verified marker is a red flag by itself.
4. **Download count and age.** Low downloads are not damning alone (new and
   niche packages are legitimate), but *low downloads plus a name resembling
   a popular package* is the slopsquat signature. Weight them together.
5. **License.** Present, and compatible with the project's policy. An
   unlicensed dependency is a legal problem regardless of code quality.
6. **Deprecated / unlisted / vulnerable.** `dotnet list package --deprecated`
   and `dotnet list package --vulnerable --include-transitive`.
7. **Pinned.** A wildcard (`Version="*"`, `6.*`) or a range (`[6.0,7.0)`)
   means a future publish lands in your app with no diff and no review. Pin
   it. If the repo uses Central Package Management, the version belongs in
   `Directory.Packages.props` — a `Version=` on the `PackageReference`
   silently overrides the central pin for that project only, which is
   parallel-instance drift wearing a different hat (see §5a).
8. **Is it justified?** Only after the above. A real, popular, well-licensed
   package that duplicates something already in the dependency tree, or
   replaces six lines of BCL code, is still hunt #3's problem.

## Transitive surface

The direct dependency is rarely where the CVE lives:

```bash
dotnet list package --vulnerable --include-transitive
dotnet list package --deprecated
```

A diff that adds a package reference without this check has added untested
surface. `--include-transitive` is the flag that matters.

## Hallucinated APIs — the compiled and uncompiled halves

For C#, the compiler catches most invented methods and overloads. **What it
does not catch is everything that is a string or a convention:**

- **Configuration keys** — `Configuration["Foo:Bar"]`, `appsettings.json`
  sections, environment variable names. A wrong key silently binds to
  `null`/default and the feature quietly does nothing. Grep the key against
  where it is *bound*, not just where it is read.
- **MSBuild properties** — an invented `<SomeProperty>` in a `.csproj` is
  silently ignored. It looks configured. It isn't.
- **Analyzer / diagnostic ids** — `#pragma warning disable CS9999` or a
  `.editorconfig` entry for a rule id that doesn't exist. Disables nothing,
  reads as if it does. (Pairs with hunt #24 — an invented suppression is a
  suppression that *looks* deliberate.)
- **EF Core conventions** — a `[Table]`/`[Column]` name that doesn't match
  the schema, a navigation property name in a string-based `.Include("...")`
  that doesn't exist (use `nameof` — hunt #21).
- **Package-specific option names** in a fluent configuration chain where the
  builder accepts `Action<TOptions>` and the property is just wrong-but-real
  on a different type.
- **CLI flags** in scripts, Dockerfiles, and CI YAML — `dotnet test
  --some-flag` that doesn't exist fails loudly, but a flag that exists and
  means something *else* does not.
- **Docs and READMEs** the diff adds that describe APIs the code doesn't have
  (hunt #18 covers architecture docs; this is the API-level version).

For any of these, verify against the pinned version — not against memory, and
not against the latest docs, which may describe a version the project isn't
on. If `microsoft-docs:microsoft-docs` is available, use it and cite the page
in the finding.

## Non-.NET ecosystems

The script is NuGet-only, but the hunt isn't. `package.json`, `requirements.txt`,
`pyproject.toml`, `go.mod`, `Cargo.toml` all have the same exposure, and npm
and PyPI are where the published hallucination research was done. Same
questions: exists, canonical name, owner, downloads, pinned, licensed.
