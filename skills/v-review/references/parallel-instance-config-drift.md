# Parallel-instance configuration drift

> Reference loaded by the `v-review` skill (hunt #5a). When a diff adds a *second* instance of a framework primitive the codebase already configures elsewhere — a second auth scheme, a second `HttpClient`, a second `DbContext` registration, a second `JsonSerializerOptions`, a second logger sink, a second Polly/resilience pipeline, a second CORS policy, a second rate-limiter partition, a second FluentValidation registration — **the new instance must mirror every option the first instance sets that affects shared framework behaviour**. Anything set on one and not on the other is silent divergence the framework will not warn about.

## How to catch it

- **Find the existing instance.** `grep -rn "Add<Same>"` for the same registration method. Read its options block in full.
- **Diff options field-by-field** against the new instance. Common categories:
  - **Claim/identity mapping** (auth schemes): `RoleClaimType`, `NameClaimType`, `MapInboundClaims`, `TokenValidationParameters`, `Events.OnTokenValidated`.
  - **Wire protocol** (HTTP clients): `BaseAddress`, `Timeout`, `DefaultRequestHeaders`, handler chain, retry/circuit-breaker policies.
  - **Serialization**: naming policy, null handling, custom converters, max-depth, reference-handling.
  - **Database**: connection string source, query splitting behaviour, lazy loading, command timeout, retry-on-failure.
  - **Logging**: minimum level, enrichers, output template, scope handling.
  - **Validation**: severity defaults, language manager, cascade mode.
- **Tell-tale: a hand-rolled helper appears alongside the new instance** that re-implements something the framework would normally do (manual claim string-matching instead of `User.IsInRole`, manual JSON parsing instead of model binding, manual log enrichment, manual retry loop). That helper exists *because* the new instance is mis-configured and the standard mechanism returned nothing useful. **Don't accept the helper — fix the instance's options to match its sibling.**

## Cascade analysis

**Cascade analysis — required when the missing/divergent option is identity-mapping or framework behaviour the codebase reads via a shared abstraction.** When you find that a new instance is missing an option, the local workaround is the tip; the cascade through dependent middleware, interceptors, audit-field providers, cache services, and provisioning hooks is the iceberg. **Grep every consumer of the affected primitive and check whether each one survives the new scheme.**

## Concrete examples — what to grep when the missing option is:

- **`RoleClaimType` / `NameClaimType` / `MapInboundClaims`** → grep `IsInRole(`, `Identity.Name`, `Identity?.Name`, `User.FindFirst(ClaimTypes.Role)`, audit-field providers (`ICurrentUser*`, `*UserContext`, `*Principal*`), any DB interceptor that reads the principal, any `ISkin*UserService` / `ICurrentUser*` / `IAuditContext` consumer. Each one breaks on the new scheme.
- **`Events.OnTokenValidated`** (user provisioning, role sync, account creation) → the new scheme that lacks the hook means JWT-only callers never get an `ApplicationUser`/`AspNetUsers` row, never have roles synced to local Identity tables, and never have downstream foreign-key fields (e.g. `CompanyId` on the local user row) populated. Latent asymmetry — works in dev, breaks the first time a write tool hits the schema.
- **`HttpClient` handler chain / Polly resilience pipeline** → grep for the existing `AddHttpClient<T>().AddHttpMessageHandler<X>()` registration; if the new client doesn't replicate the chain, retries/circuit-breakers/correlation-id propagation silently disappear on the new path.
- **`JsonSerializerOptions`** → grep `JsonSerializer.Deserialize`/`Serialize` call sites and any model-binding configuration. A new options instance with different naming policy means the same payload deserializes differently depending on which call site reads it.

## Severity guidance

**Severity minimum HIGH for auth/identity drift** (silent role bypass when a future caller adds `[Authorize(Roles=...)]`); **MEDIUM for behaviour drift** (HTTP/serialization/DB instances that disagree under edge conditions).

---

The pattern: if a hand-rolled workaround appears alongside the new instance, that workaround is the *visible* symptom of a cascade. Find the rest before signing off.
