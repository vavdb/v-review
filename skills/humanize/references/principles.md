# Editing principles

How to edit once the patterns are marked. The job is a sharp human editor, not a rewriter. Preserve the point and the person; remove the machine.

## Core

- **Minimum effective edit.** Fix flagged patterns, errors, repetition, unclear passages. Leave strong human sentences alone. A rough draft with a real voice should still sound like the same person afterwards.
- **Lead with the point when the setup adds nothing.** Cut generic throat-clearing. Keep a personal aside, story, or admission when it creates context, tension, or character.
- **Front-load only when it helps.** Do not force every paragraph into point-detail-background.
- **Open it up, don't dumb it down.** Keep substance, nuance, precision. Strip only what makes it hard to read: jargon, tangled structure, abstract nouns, sentences with two embedded clauses.
- **Active voice.** "The team shipped it Tuesday" beats "the decision emerged". Inanimate things do not do human verbs.
- **Every sentence earns its place.** Cut empty qualifiers. Keep "I think", "maybe", "to be honest" when they express real uncertainty or the writer's spoken rhythm.
- **Untangle without flattening.** Split sentences that are hard to follow. Keep long spoken sentences, fragments, and pace changes when they are clear and characteristic.
- **Concrete beats abstract.** "The integration improved efficiency" becomes "The integration cut deploy time from 40 minutes to 4." Names, numbers, dates, mechanisms, examples. If you cannot picture it happening, rewrite it. If you do not have the number, leave `[ADD: number]`, do not invent one.
- **Portability test.** If a sentence could move unchanged to another company, product, person, or country, it is filler. Cut it or replace it with a fact, mechanism, consequence, or judgement specific to this subject.
- **Show, don't label.** Cut commentary that tells the reader a point is important, surprising, subtle, or obvious. Let the fact carry the weight. "This distinction matters" → delete, or replace with why.
- **Protect the specific fact.** Never smooth a useful detail into generic importance.
- **Verbs do the work.** "Made a decision" → "decided". "Has the ability to" → "can". "Serves as" → "is".
- **Repeat the clear word.** No synonym cycling for style. "The agent reviews the draft. The assistant scores it. The tool suggests fixes." → one subject.
- **Keep structure unless it hurts.** Preserve the writer's progression and detours when they carry personality. If you reorganise, say why in What changed.
- **Keep useful edge.** Strong opinions, blunt language, humour, profanity, self-interruptions, honest admissions stay when they belong to the writer.
- **Vary rhythm on purpose.** Some short paragraphs, some long. Some short sentences, some long. Uniform paragraph length is a tell; so is a row of one-line punchlines.
- **Reading level.** Aim for grade 7 to 9 in conversational and professional prose. Three or more three-syllable words in one sentence, or two embedded dependent clauses, is a rewrite candidate. Technical docs may run higher when the terms are the domain's.

## Endings (hard rule 4)

End on the last concrete point, a decision, a next action, or an open question. Not a summary, not vague optimism ("exciting times ahead"), not a mic-drop fragment, not a metaphor. If the draft's ending is a recap, delete it and stop one paragraph earlier. If more closure is needed, add a plain takeaway or next step, never a restatement.

## Conviction (hard rule 5)

- One position per claim. State it. If there is a real trade-off, name both sides in one sentence and then say which one you would take and when.
- Delete hedges that exist to make the writer un-wrong. Keep hedges that report real doubt, and make them specific: not "this may not always work" but "I have only tested this on Postgres".
- Do not answer objections nobody raised. "I'm not saying X" where X appears nowhere else is a deleted sentence.
- Do not reject strawman alternatives. "One might be tempted to…" followed by an option no reader would consider is a deleted sentence.

## Meta-commentary (hard rule 2)

Anything that describes the text instead of being the text goes: announcing the next point, praising the question, summarising what was just said, telling the reader what to notice, promising what is coming. Announcements in casual register ("one thing that bit me, so pay attention") are still announcements.

## UI copy and error messages

Applies when the text is a string a user sees in a product: validation message, toast, dialog, empty state, tooltip, exception message that surfaces to a user.

- **One sentence when possible.** Name what happened and what to do. "File too large. Maximum is 10 MB." Not "Oops! It looks like the file you're trying to upload might be a bit too large."
- **No apology theatre, no exclamation marks, no "please" more than once, no emoji.**
- **Name the thing.** The field, the limit, the value, the object. Not "an error occurred".
- **Name the fix or the next action** when there is one the user can take.
- **Same voice as the rest of the product.** Read three existing strings before writing one.
- **Never expose internals** (stack traces, table names, exception types) in user-facing text. That is also a security finding.

## Documentation, README, changelog, ADR, doc comments

- **Describe the current behaviour**, not the change from the previous version. History belongs in the changelog and migration guide, nowhere else.
- **No "In this document we will…"**. Start with what the thing is or does.
- **No "Key takeaways", "Conclusion", "Summary" sections** in reference docs. If a section only restates other sections, delete it.
- **Headings in sentence case.** No emoji in headings. No bold-label-colon bullets where prose would carry more.
- **A heading followed by a sentence that restates the heading** is a deleted sentence.
- **Tables only for data that is tabular.** Not for three bullet points wearing a grid.
- **Doc comments state the contract**: what it does, what it returns, what it throws, what it requires. No "This method is responsible for…", no "It is important to note that…".

## PR bodies and commit messages

- **What and why, present tense.** Not "This PR adds…" (the reader can see it is a PR). Not "I noticed that…".
- **No "This change ensures…", "This enhances…", "This leverages…".** Say what it does.
- **No compliance claims** ("fully tested", "follows best practices", "production-ready") without the evidence: the command run, the test name, the number.
- **Failure explanations need evidence, not adjectives.** "Flaky" is a claim; a 20-run loop result is evidence. (v-review hunt 26c.)
