# v-review

The future-check code review skill for Claude Code.

A current-check review asks *does it work today?* — builds, tests, demo. A future-check review asks *what does this lock the team into for the next six months?* This skill is the second question, asked with the same tools the first one had — minus the deference, minus the schedule pressure, plus the willingness to say no.

## What it does

Activated when you ask Claude to **review a branch, PR, commit, or staged diff**. v-review then:

1. Reads the project's `CLAUDE.md`, `AGENTS.md`, and any `.claude/rules/` files so project conventions override anything in the skill.
2. Dispatches the right specialist subagents in parallel — `security-reviewer` when auth is touched, `code-reviewer` as an independent second opinion, language-specific reviewers (`csharp-reviewer`, `typescript-reviewer`, etc.), `database-reviewer` for migrations, and chains `differential-review`, `finding-duplicate-functions`, `insecure-defaults`, `semgrep`, `codeql` where the diff signals warrant it.
3. Walks a 17-item hunt list — silent catches, cargo additions, boolean-flag API smells, redundant DI registrations, parallel-instance configuration drift, duplicated/re-invented helpers, semantic duplicate functions, framework-primitive re-implementations, domain-language drift, dead code, test smells (force-clicks, retry loops, swallowed assertions, tests that assert LINQ exists), missing `sealed`, mis-named `Try*` methods, hand-edited generated artifacts (migrations, lockfiles), useless imports, the full security checklist, and architecture-doc/code contradictions.
4. Applies mechanical fixes, runs build + targeted tests, then **stages the result with `git add` and stops**. The author reviews staged diffs before they land — committing eagerly turns review into post-mortem.
5. Returns a `Was → Now` table per finding, severity tags (CRITICAL/HIGH/MEDIUM/LOW), unfixed-but-flagged issues, considered-but-deliberately-left calls with one-sentence reasoning, the skills + subagents invoked with headline outputs, and the exact build + test commands run with pass/fail.

The skill is **opinionated**. It refuses cargo additions, calls out UI-only authorization, flags any migration that moves data without backfill as a data-loss event, and rewrites domain-language drift (e.g. "tenant" terminology in single-instance codebases) without ceremony. If you can't defend a line in one sentence, it goes.

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

After install, restart Claude Code and the skill registers as `v-review`. Trigger it with any of:

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

v-review **suggests but does not auto-install** these. At pre-flight time it checks which are available in your session, prints a `using: … / missing: …` banner, and gracefully degrades on the missing ones. Install them up-front if you want full coverage.

### Skills

| Skill | Plugin/source | What v-review uses it for |
|---|---|---|
| `claude-mem:mem-search` | [claude-mem](https://github.com/thedotmack/claude-mem) | First-pass: was this work attempted before? Prior decisions, abandoned approaches, known landmines. |
| `superpowers:systematic-debugging` | [superpowers](https://github.com/obra/superpowers) | When the diff is a fix — was the root cause identified, or was a symptom patched? |
| `superpowers-lab:finding-duplicate-functions` | [superpowers-lab](https://github.com/obra/superpowers-lab) | Catches semantic duplicates with different names — the LLM-generated "re-implementation instead of reuse" case. |
| `differential-review:differential-review` | trailofbits plugin | Non-trivial diff — blast-radius scoring, git-history context, test-coverage check. |
| `insecure-defaults:insecure-defaults` | trailofbits plugin | Diff touches config, env vars, secrets, auth setup, service registration. |
| `static-analysis:semgrep` | trailofbits plugin | Multi-language diffs or pre-protected-branch merges. |
| `static-analysis:codeql` | trailofbits plugin | Deeper interprocedural taint/dataflow on security-sensitive code. |

### Subagents

Subagent availability depends on your setup — they're typically defined in `~/.claude/agents/` or `.claude/agents/` in the project.

| Subagent | What v-review dispatches it for |
|---|---|
| `code-reviewer` | General code quality — independent second opinion after the skill's own pass. |
| `security-reviewer` | OWASP, injection, hardcoded secrets, auth bypasses. Mandatory when the diff touches anything security-sensitive. |
| `csharp-reviewer` / `typescript-reviewer` / `python-reviewer` / etc. | Stack-specific anti-patterns matched to the diff's primary language. |
| `database-reviewer` | Migrations, schema mods, query changes. |
| `aws-reviewer` / `gcp-reviewer` | IaC, IAM, deploy configs. |

If a recommended subagent doesn't exist in your environment, v-review walks the corresponding hunt-list item manually — you just lose the parallel-second-opinion benefit.

## When NOT to use

- Single-line typo, README polish, dependency bump with no code change.
- Diff is generated files only (model snapshots, lock files, designer.cs, code-gen output).
- Personal-style preference where the codebase already has a consistent convention.

## License

MIT — see [LICENSE](LICENSE).
