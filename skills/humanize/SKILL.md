---
name: humanize
description: Edit prose so it reads like a person wrote it, or detect AI-writing patterns without rewriting. Covers blog posts, docs, README and changelog text, UI copy and error messages, PR bodies, LinkedIn posts, emails, Slack messages. Use when the user says "humanize", "does this sound like AI", "make it sound human", "remove AI slop", "voice check", "rewrite in my voice", "review this post / email / draft", or pastes prose and asks for it to be sharper, more direct, or less generic. Also dispatched by `v-review` (via the `prose-reviewer` subagent) on user-facing text and documentation in a diff. Not for code review, grammar-only proofreading, or translation.
license: MIT
metadata:
  version: "1.0.0"
---

# humanize

Make the text read like one specific person wrote it, without changing what it says.

## Contents

- [Hard rules](#hard-rules) — five non-negotiables, checked last and reported first
- [Modes](#modes) — edit, detect, review, file, embedded
- [Workflow](#workflow)
- [Channel detection](#channel-detection) — blog, docs, UI copy, LinkedIn, email, Slack
- [Voice](#voice)
- [Output](#output)
- [Reference files](#reference-files) — load per step, not all at once
- [Credits](#credits)

## Hard rules

These override every pattern file and every voice sample. Check the final text against each one before returning it. Report violations by number. The grep lists in [`eval.md`](eval.md) items 1 to 5 are the operational form of these rules; where the wording here and the grep list differ, the grep list is canonical.

1. **Direct, punchy, conversational.** Short words, mostly short sentences, active voice, second person where the format allows. Say the thing. If a sentence could open with the point, it does.
2. **No meta-commentary.** Nothing that talks about the text instead of being the text: "That's an interesting perspective", "Let's dive in", "In this article", "It's worth noting", "As you can see", "Great question". Delete, don't soften.
3. **Banned words and phrases.** Never in output, whatever the voice sample says: `delve`, `tapestry`, `crucial`, `furthermore`, `shifting landscape`, `it is worth noting` / `it's worth noting`. The wider list in [`references/banned-words.md`](references/banned-words.md) is "cut unless the writer's sample uses it"; these six are "cut, full stop".
4. **No recap conclusion.** No final paragraph that restates what the reader just read. No "In conclusion", "To sum up", "Ultimately", "Overall". End on the last concrete point, a decision, a next action, or an open question.
5. **Conviction.** One position per claim. No "on the other hand" unless the writer then picks a hand. No "some may argue", "it depends", "arguably", "perhaps", "somewhat", "to some extent", "it could be said" unless the uncertainty is real and named ("I have not measured this"). No balancing every claim with its opposite. Hedges that express the writer's real doubt stay; hedges that protect the writer from being wrong go.

## Modes

Pick one from the request. Default is **edit**.

| Mode | Trigger | Returns |
|---|---|---|
| **edit** | text pasted, "humanize", "fix this", "make it sound human" | Full rewrite + `What changed` list + hard-rule check |
| **detect** | "is this AI?", "does this sound like AI", "flag", "audit", "scan" | Named patterns with exact quotes and a one-line fix each. **No rewrite, no score, no verdict on authorship.** Detectors guess; named patterns are evidence the reader can check. Offer to edit afterwards. |
| **review** | "review this post/email/draft", "score it", LinkedIn or email pasted | Channel detection + review report with scores + rewrite + `What changed` + hard-rule check (report format in [`references/patterns-channel.md`](references/patterns-channel.md)) |
| **file** | a path is named | Run the edit workflow, write only the final prose back. Leave code blocks, front matter, tables of data, link targets, and inline code untouched. Reply with a short summary. |
| **embedded** | called by another skill or agent (`v-review`, `prose-reviewer`, a commit-message task) | Findings only, in the caller's format. Never the full rewrite unless asked. |

## Workflow

1. **Read the whole text first.** Do not edit sentence by sentence.
2. **Name the job.** Who is this for, where does it run, what should the reader do after? If unclear and it changes the edit, ask one question. Otherwise assume and say so.
3. **Detect the channel.** See [Channel detection](#channel-detection). Load the channel file only when the channel is LinkedIn, email, or Slack.
4. **Find the voice.** Note vocabulary, sentence length, humour, bluntness, digressions, profanity, hedging habits. These are what you protect. See [Voice](#voice).
5. **Mark patterns.** Grep for every Tier-1 and Tier-2 entry in [`references/banned-words.md`](references/banned-words.md), then walk [`references/patterns-core.md`](references/patterns-core.md). Weigh clusters, not single hits: one em dash is nothing; em dash + rule of three + "vibrant tapestry" + a "Conclusion" heading is a confession. Check every candidate against [`references/false-positives.md`](references/false-positives.md) before flagging.
6. **Detect mode stops here.** Report and offer to edit.
7. **Edit, minimum effective.** Apply [`references/principles.md`](references/principles.md). Fix what is flagged, leave strong human sentences alone. State each point plainly rather than patching one phrase at a time; if a sentence stays awkward, rewrite the paragraph around its main point.
8. **Keep every claim.** No added fact, name, number, date, quote, or source. No removed argument. Fiction is exempt.
   **Precedence when a hard rule and this rule collide:** a hedge is framing, not a claim. "It depends on the team" keeps the condition ("when a team uses it well") and loses the hedge. "Some may argue human review is still essential" keeps the assertion ("Human review still has to happen") and loses the attribution. "Experts agree X" keeps X as the writer's own claim and loses the phantom experts. Never delete the substantive assertion underneath a hedge; delete only the hedge.
   **Placeholders.** Where a sentence needs a detail you do not have, write `[ADD: what is missing]`. One per text by default; add more only when the gaps are unrelated claims. List every placeholder on the `Gaps:` line of the output.
9. **Self-check against [`eval.md`](eval.md).** Every hard rule, every item. Fix and re-check until clean. Search the output for `—` and `–` and remove each one unless the voice sample uses them.
10. **Return** per [Output](#output).

## Channel detection

State the detection in the first line of the output. Default to **general prose** when unsure and say so.

| Channel | Any of these | Extra rules |
|---|---|---|
| **General prose / blog / docs** | headings, developed paragraphs, README, changelog, ADR, XML doc comment, code comment | core patterns only |
| **UI copy / error message** | short string, imperative, appears in a `.razor`/`.resx`/`.json` resource, a `throw new`, a validation message, a toast | core patterns + "one sentence, name the thing, name the fix" (see `principles.md` § UI copy) |
| **LinkedIn** | one-sentence-per-line formatting, hashtags, engagement CTA ("Thoughts?"), @mentions, no headings under 3,000 chars, emoji as section markers or sign-off, arrow chains, "Read that again" / "Let that sink in", vulnerability or credential-stacking hook | **two or more** markers: LinkedIn, load `patterns-channel.md` § LinkedIn. **One** marker: general prose, but still apply the LinkedIn phrase-level list from that file. |
| **Email** | Subject/To/From, greeting formula, sign-off + name, "following up", "per our conversation" | load `patterns-channel.md` § Email |
| **Slack** | #channel, @here, shortcodes `:rocket:`, under 500 chars, no greeting or sign-off | load `patterns-channel.md` § Slack |

## Voice

- **Sample provided** (the user's own writing, a `voice=` file, a project `STYLE.md` or `CLAUDE.md` tone section): read it first. Match sentence length, word choice, openings, punctuation habits, transitions. A sample beats every pattern file except the [Hard rules](#hard-rules). If the sample uses em dashes, keep them at the same rate.
- **No sample**: apply the hard rules as the voice. Calm, specific, slightly sceptical, no hype. If it would fit on a SaaS homepage, it is wrong. If it sounds like a competent operator explaining something real to a peer, it is right.
- **Ask at most one question** about voice, and only when the answer would change the rewrite. Do not run a questionnaire.
- **Register follows channel.** A Slack message and a README from the same writer should not sound identical. Keep the writer, change the register.

## Output

**Edit mode:**

```
Detected as: <channel>

<final text>

## What changed
- <pattern name>: "<quoted original>" → what you did and why (one line each; group repeats)

Gaps: <each `[ADD: …]` placeholder, or "none">

## Hard-rule check
1 direct ✅  2 no meta ✅  3 banned words ✅  4 no recap ✅  5 conviction ✅
(replace ✅ with the offending quote if a rule could not be satisfied without changing meaning, and say why)
```

**Detect mode:** `Detected as:` line, then one line per hit: `<pattern name>: "<exact quote>" → <fix in under ten words>`. End with "Want me to edit it?"

**Review mode:** the report in `patterns-channel.md`, then the rewrite, then `What changed`, `Gaps:`, and the hard-rule check, same as edit mode.

**File / embedded:** as described in [Modes](#modes).

Always close with one sentence, not a paragraph: the rewrite is a draft; the writer's edits on top of it are usually the best version.

## Reference files

| File | Load when |
|---|---|
| [`references/patterns-core.md`](references/patterns-core.md) | every run, step 5 |
| [`references/false-positives.md`](references/false-positives.md) | every run, step 5, before flagging anything |
| [`references/principles.md`](references/principles.md) | every edit / review / file run, step 7 |
| [`references/banned-words.md`](references/banned-words.md) | every run; the full cut list |
| [`references/patterns-channel.md`](references/patterns-channel.md) | LinkedIn, email, or Slack detected, or review mode |
| [`eval.md`](eval.md) | step 9, every run that produces text |

## Credits

Pattern catalogue merged and de-duplicated from four sources, all MIT unless stated:

- [blader/humanizer](https://github.com/blader/humanizer) v2.11.2, itself derived from Wikipedia's [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing). Core pattern numbering and most before/after pairs.
- [petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop). Editing principles, portability test, detect mode, eval checklist shape.
- [numen-tech/slopornot](https://github.com/numen-tech/slopornot) `agentic-humanizer`. Supplemental artifact tells (S1 to S8). Their loop, profiles, multilingual and Slop-or-Not-Pro integration were deliberately not carried over.
- "The Humanizer" v2.4 (channel-specific LinkedIn / email / Slack markers, review report and scoring tables; supplied by the user, origin unverified).
