# Test integrity — reference

Backs hunt #26. Load it whenever the diff adds or changes tests, and whenever
the PR body, a commit message, or a session transcript explains away a
failure.

Three failure classes, in ascending order of damage:

1. **Tests that assert nothing about your code** — coverage theatre.
2. **Failure paths never exercised** — the happy path is the only path tested.
3. **Excuse-making about failures** — the worst, because it converts a real
   bug into a closed ticket.

## 1. Tests that test the language, not your code

The tell: **mentally mutate the production code. If the test still passes, it
tests nothing.** Apply this to every test in the diff. It is the single
highest-yield question in test review, and it takes five seconds.

### The language-feature test

The test exercises the runtime, the standard library, or the compiler —
never the code under review:

```csharp
// Tests that LINQ exists.
var items = new List<Order> { new() { Status = "Open" }, new() { Status = "Closed" } };
var open = items.Where(i => i.Status == "Open").ToList();
Assert.Single(open);
```

Nothing here calls production code. The `Arrange` builds the data, the `Act`
calls `System.Linq`, and the `Assert` checks that `Where` works. Coverage on
the actual query path: **zero**. Variants:

- Building a `List<T>` and asserting `.Count` after `.Add`.
- Constructing a `record` and asserting its properties round-trip — that
  tests the compiler's generated constructor.
- Asserting `JsonSerializer.Serialize(x)` round-trips to `x` with default
  options and no custom converter — that tests `System.Text.Json`.
- Asserting a `DateTime` arithmetic result — that tests the BCL.
- Asserting an enum's `ToString()` equals its member name.
- Mapping a DTO by hand in `Arrange` and asserting the hand-mapping matched.

### The maths-without-a-reason test

Arithmetic asserted for its own sake, with no domain rule behind it:

```csharp
Assert.Equal(4, 2 + 2);
Assert.Equal(100m, 50m * 2);
Assert.Equal(0.3, 0.1 + 0.2, precision: 10);
```

The question that separates a real test from this one: **which rule breaks
if this assertion fails?** `Assert.Equal(21m, CalculateVat(100m))` encodes a
domain rule — the VAT rate. `Assert.Equal(21m, 100m * 0.21m)` encodes
nothing; it asserts that multiplication works, and it will keep passing after
someone changes the real VAT rate to 19%.

Same test for a rounding assertion: if the production code doesn't do the
rounding, the test isn't testing rounding.

### Other shapes of the same failure

- **Trivially-true assertions** — `Assert.True(items.Any() || !items.Any())`,
  `Assert.NotNull(new Foo())`, `Assert.Equal(x, x)`.
- **Asserting on the mock, not the code** — `mock.Verify(m => m.Save(...))`
  when `Save` is the only thing the method does and the mock was configured
  to accept anything. That asserts you wrote the line you just wrote.
- **Asserting the fixture** — `Assert.Equal(3, _seededOrders.Count)` where
  the seed is three rows the test itself inserted.
- **Snapshot/approval tests regenerated in the same commit as the behaviour
  change**, with the snapshot diff unreviewed. The snapshot is supposed to be
  the assertion; regenerating it turns the test into a rubber stamp.
- **A test named for behaviour it doesn't exercise** —
  `Returns403WhenUserLacksRole` that never sets up a user without the role.
  The name is the claim; check the body honours it.

**Fix**: delete, or rewrite so the `Act` calls production code and the
`Assert` encodes a rule someone could get wrong. A deleted worthless test is
strictly better than a kept one — the kept one costs maintenance and buys
false confidence, and it will be cited as "covered" in the next review.

## 2. Failure paths never exercised

Agent-written suites skew hard to the happy path. For each new behaviour,
check whether these exist — and flag the ones that should and don't:

- **Malformed / unparseable input** at the boundary.
- **Empty and null** — empty collection, null optional, empty string,
  whitespace-only string.
- **Boundary values** — zero, negative, max length, off-by-one around any
  limit the code enforces.
- **Permission denied** — the authorization branch. If hunt #16 says the
  service must gate, there must be a test proving it gates.
- **Not found** — the 404 path, and specifically that it is *not* confused
  with the forbidden path (returning 404 for forbidden is a deliberate
  choice; returning 403 for missing leaks existence).
- **Downstream failure** — the HTTP call fails, the DB times out, the queue
  is unavailable. Whatever the retry/fallback logic claims to do, exercise it.
- **Cancellation** — if the method takes a `CancellationToken`, one test
  should pass an already-cancelled one.
- **Concurrency** — where the code claims to be safe under it.

The asymmetry to call out: **error handling is the code least likely to be
tested and most likely to be wrong**, because it's the code that doesn't run
during manual verification. A diff that adds a `catch` block and no test for
the caught path has tested the part that already worked.

## 3. Excuse-making — claims that deflect a failure away from the code

**This is the highest-severity item in this file.** A test that is wrong is a
bug. A test that is *explained away* is a bug plus a false all-clear, and the
all-clear is what lets it ship.

Watch for these claims in PR descriptions, commit messages, code comments,
test annotations, and in the session transcript if you have it:

| Claim | What it usually means |
|---|---|
| "This test is known flaky" | Nobody diagnosed the race |
| "Flaky in CI, passes locally" | A real environment-dependent bug — usually timing, ordering, or shared state |
| "Network error, unrelated to my change" | An unmocked external call in a test that shouldn't make one |
| "Pre-existing failure, not from this PR" | Sometimes true. Verify by checking out the base ref and running it |
| "Environment issue" / "CI is being weird" | A diagnosis-shaped phrase containing no diagnosis |
| "Test infrastructure problem" | Same |
| "Intermittent, will fix in a follow-up" | There is no follow-up |
| "The test was wrong, so I updated it" | Sometimes right, often the fastest way to make a real regression disappear |
| "Timing issue — added a wait" | A race, now hidden and slower |
| "Works on my machine" | Machine-dependent state the test depends on and doesn't control |

### How to handle each one

**Do not accept any of these at face value.** Each is a *hypothesis*, and
every one is cheap to test:

- **"Pre-existing failure"** → check out the base ref, run that exact test.
  If it passes there, the claim is false and the diff broke it. This takes
  one command and settles the question completely.
- **"Known flaky"** → run it in a loop (`--filter`, `--repeat`, or a shell
  `for` loop, 20+ iterations). Flakiness that reproduces is diagnosable:
  shared state between tests, dependence on execution order, a real race, a
  clock or timezone assumption, a fixed test-data id that another test
  mutates. **Flakiness that reproduces is not flakiness, it is a bug with a
  bad name.**
- **"Network error"** → find the call. A unit test making a real network call
  is the finding, independent of whether it passed today. An integration test
  is allowed to, but then the failure is real and needs a real cause.
- **"Unrelated to my change"** → grep the failing test's subject for anything
  the diff touches, including transitively through DI registrations and
  shared fixtures. "Unrelated" is a conclusion, not a starting assumption.
- **"I updated the test to match"** → the load-bearing question is **which
  changed first, the behaviour or the test?** If the production change was
  intentional, the test must change *and the PR must say what behaviour
  changed and why*. If the test was updated to make a red bar green, that's a
  regression with a passing suite on top of it. Read the test's old assertion
  and ask what it was protecting.

### The rule

**A failing test is a finding until proven otherwise, and the proof is
evidence, not narration.** Acceptable evidence: the base-ref run, a
root-cause explanation naming the specific shared state or race, a linked
issue with a diagnosis in it. Not acceptable: an adjective.

Escalate to **HIGH** when a test was disabled, retried, or had its assertion
weakened in the same diff that changed the behaviour the test covered. That
combination — behaviour changed, test silenced, explained as flake — is how
regressions ship with a green pipeline.

### Related silencing moves

These usually travel with the excuse, so check for them together:

- `[Fact(Skip = "flaky")]`, `test.skip`, `@pytest.mark.skip`, `t.Skip()`
  without an issue link *and* a diagnosis.
- Retry attributes or CI-level retries added to a specific test.
- A timeout raised on the failing test only.
- `continue-on-error: true` added to the test step (hunt #24).
- An assertion loosened rather than the code fixed — `Assert.Equal` becoming
  `Assert.Contains`, an exact count becoming `Assert.True(count > 0)`,
  a strict comparison gaining a tolerance nobody justified.
- A test moved out of the default suite into a manually-triggered one.
