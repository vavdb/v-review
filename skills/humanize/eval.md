# humanize: self-check before returning

Run on every text you produce (edit, review, file, embedded). Every item must pass. Fix and re-run until it does. If an item cannot pass without changing meaning, leave the original wording and say so in the hard-rule check line.

## Hard rules (report these five by number)

1. **Direct.** Does every paragraph open on its point or on a concrete detail? Is the majority of sentences under 20 words? Is the voice active except where the actor is unknown or irrelevant?
2. **No meta-commentary.** Grep the output for: "interesting", "let's dive", "let's explore", "in this article", "in this post", "worth noting", "as you can see", "great question", "important to note", "let me explain", "here's what", "in other words" (redundant), "the key point is". Zero hits, or each one is inside a quotation.
3. **Tier-1 banned words.** Grep for: `delve`, `tapestry`, `crucial`, `furthermore`, `shifting landscape`, `worth noting`. Zero hits outside quotations, titles, and code.
4. **No recap ending.** Read the last paragraph. Does it introduce nothing new? Does it start with "In conclusion", "To sum up", "Ultimately", "Overall", "In short", "So,"? Does it restate the opening? Any yes: delete it and end one paragraph earlier, or replace with a next action or open question.
5. **Conviction.** Grep for: "on the other hand", "that said", "some may argue", "it depends", "arguably", "perhaps", "somewhat", "to some extent", "could potentially", "might arguably", "both sides". Each hit is either deleted or followed within one sentence by the writer's pick. No paragraph states a claim and its opposite without choosing.

## Meaning

6. Every fact, name, number, date, quote, citation, and ranking in the source is in the output. None appear in the output that were not in the source or supplied by the user. Placeholders `[ADD: …]` mark gaps instead of inventions.
7. Every argument in the source is still made. Structure may change; substance may not.
8. Nothing inside quotations, code, proper names, or titles was rewritten.

## Patterns

9. No em dashes or en dashes (search `—` and `–`, plus ` -- ` and spaced ` - ` used as a dash) unless the voice sample uses them, in which case the rate matches the sample.
10. No "not X but Y" / "it's not about X, it's about Y" constructions. No "not only … but also".
11. No forced groups of three where two or four is what the content has.
12. No trailing `-ing` clause pretending to explain significance ("highlighting", "underscoring", "showcasing", "reflecting").
13. No "serves as / stands as / marks / represents / boasts" where "is" or "has" works.
14. No colon reveal ("The best part: it learns."), no self-answered question ("Why? Because…"), no "X. And Y. And Z." fragment chains, no standalone hype fragment ("Game changer.").
15. No vague authority ("experts agree", "studies show", "industry reports") without a named source.
16. No bold sprinkled mid-sentence for emphasis, no emoji in headings, no bold-label-colon bullets, no Title Case Headings.
17. No chatbot residue: "I hope this helps", "Certainly!", "Would you like me to…", "Here is a…", knowledge-cutoff disclaimers.
18. No placeholder scaffolding (`[Your Name]`, `TODO`, `Lorem ipsum`), no leaked markup (`###`, `**`, `oaicite`, `turn0search0`, `utm_source=chatgpt.com`), no truncation artifacts, no compliance boasts ("fully compliant", "well-sourced").

## Voice and rhythm

19. Sentence lengths vary. Paragraph lengths vary. No three consecutive sentences start with the same word (unless deliberate and kept from the source).
20. No synonym cycling: the same thing has the same name throughout.
21. The writer's distinctive lines, humour, profanity, asides, and admissions survived where they were clear.
22. Register matches the channel: a Slack message does not read like a README; a README does not read like a LinkedIn post.

## Channel (when applicable)

23. **LinkedIn:** no engagement-bait closer, no one-sentence-per-line throughout, no hashtag stack, no arrow chains, no ALL-CAPS words, no external link in the body, under 3,000 characters.
24. **Email:** one ask, stated in the first two sentences; one greeting, one sign-off; no "hope this finds you well"; subject line names the content; a specific CTA with a time or a yes/no.
25. **Slack:** ask first, five sentences max, no greeting or sign-off, under three emoji.
26. **UI copy:** one or two sentences; names the thing and the fix; no exclamation marks; no internals exposed.
27. **Docs / doc comments / PR body:** present tense, describes current behaviour, no "In this document", no recap section, no compliance claims without evidence.

## Output shape

28. Detection line present. What-changed list present (edit/review). Hard-rule check line present. Closing sentence is one sentence.
