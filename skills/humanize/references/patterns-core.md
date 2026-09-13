# Core AI-writing patterns

Load on every run. Numbering is stable so findings can cite it (`core 9`, `core S3`). Patterns 1 to 35 follow Wikipedia's *Signs of AI writing* as carried by blader/humanizer; S1 to S8 are slopornot's artifact tells; 36 to 44 are additions from no-ai-slop and "The Humanizer". Each entry: words to watch, the problem in one line, a before/after where it helps. Weigh clusters, not single hits (see `false-positives.md`).

## Content

### 1. Inflated importance and legacy
**Watch:** stands/serves as, is a testament/reminder, a vital/significant/crucial/pivotal/key role/moment, underscores/highlights its importance, reflects broader, symbolising its ongoing/enduring/lasting, setting the stage for, marks a shift, key turning point, evolving landscape, focal point, indelible mark, deeply rooted
**Problem:** Ordinary details are dressed up as major turning points or broad trends.
> Before: The institute was officially established in 1989, marking a pivotal moment in the evolution of regional statistics.
> After: The institute was established in 1989 as part of a wider decentralisation of statistics in Spain.

### 2. Name-dropping to prove importance
**Watch:** independent coverage, national media outlets, written by a leading expert, active social media presence, cited in [list of outlets]
**Problem:** A list of publications or follower counts in place of what the person actually said or did. Keep the citation only when it says what and where.

### 3. Shallow analysis with -ing phrases
**Watch:** highlighting…, underscoring…, emphasising…, ensuring…, reflecting…, symbolising…, contributing to…, fostering…, encompassing…, showcasing…
**Problem:** A trailing participle phrase bolted on to make a plain fact sound deep.
> Before: The launch adds file search, highlighting the team's commitment to better workflows.
> After: The launch adds file search, so users can find old drafts without leaving the editor.

### 4. Sales language
**Watch:** see `banned-words.md` § Sales language. Also: boasts, vibrant, rich (figurative), profound, nestled, in the heart of, groundbreaking, renowned, stunning, must-visit
**Problem:** Reads like an advert, especially about places, products, culture, organisations.
> Before: Nestled in the breathtaking Gonder region, the town stands as a vibrant hub with a rich heritage.
> After: The town is in the Gonder region of Ethiopia.

### 5. Vague sources
**Watch:** industry reports, observers have cited, experts argue/agree/believe, some critics argue, studies show, several sources, widely regarded as, many argue
**Problem:** A claim pinned on nobody. Name the source from the text, or cut the claim. Never invent one.

### 6. Formulaic challenges and outlook sections
**Watch:** Despite its… faces several challenges…, Despite these challenges, Challenges and Legacy, Future Outlook, Key takeaways, Conclusion (in reference prose)
**Problem:** Stock sections that repeat vague claims instead of adding facts. Cut, or keep only the specific facts.

## Language and grammar

### 7. Overused AI vocabulary
**Watch:** `banned-words.md` Tier 1 and Tier 2 AI vocabulary. High-signal cluster: delve, tapestry, testament, pivotal, crucial, landscape, showcase, underscore, foster, leverage, intricate, vibrant, enduring, garner, interplay
**Problem:** These appear far more often post-2023 and travel in groups. One is noise; three in a paragraph is a tell.

### 8. Avoiding "is" and "are"
**Watch:** serves as, stands as, marks, represents [a], boasts, features, offers [a], functions as, acts as
**Problem:** Elaborate verbs standing in for the copula.
> Before: Gallery 825 serves as the exhibition space and boasts four rooms.
> After: Gallery 825 is the exhibition space and has four rooms.

### 9. Not X but Y, negative parallelism, tailing negation
**Watch:** not only… but also, it's not just X, it's Y, this isn't about X, it's about Y, not X. Not Y. Z., no guessing / no fuss / no wasted motion (as a tacked-on fragment)
**Problem:** Manufactured contrast; the sentence exists to knock down something nobody proposed. State Y.
> Before: It's not just a song, it's a statement. The options come from the selected item, no guessing.
> After: The song makes a statement. The options come from the selected item, so the user does not have to guess.

### 10. Forced groups of three
**Problem:** Ideas jammed into triplets to sound complete. If the content has two, write two; if four, write four.
> Before: Attendees can expect innovation, inspiration, and industry insights.
> After: The event has talks and panels, with time to talk between sessions.

### 11. Synonym cycling and repeated openings
**Problem:** The same thing renamed each sentence ("the protagonist… the main character… the central figure… the hero"), or several sentences opening on the same subject. Use one name. Merge sentences or start with the action. Do not ban the repeated word; fix the pattern.

### 12. False "from X to Y" ranges
**Problem:** X and Y are not ends of a scale. "From the Big Bang to the cosmic web, from stars to dark matter" → "The book covers the Big Bang, star formation, and dark matter."

### 13. Passive voice and missing subjects
**Watch:** No configuration needed. Results are preserved automatically. The decision was made.
**Problem:** The actor is hidden or dropped. Use active when it makes actor and action clearer.

## Style

### 14. Em and en dashes
**Rule:** The output contains no `—` or `–`, no ` -- `, no spaced hyphen used as a dash, unless the writer's sample uses them, in which case match the sample's rate. Replace with period, comma, colon, or parentheses, or rewrite. Search the output before returning.

### 15. Too much bold
**Problem:** Words bolded mid-sentence for emphasis with no reason. Remove.

### 16. Lists with bold mini-headings
**Problem:** Every bullet starts `**Label:**`. Unless documenting a real framework, write prose.
> Before: - **Performance:** Load time improved through optimised algorithms.
> After: The update speeds up load times and adds end-to-end encryption.

### 17. Title Case In Headings
**Problem:** Every main word capitalised. Use sentence case.

### 18. Emoji as decoration
**Problem:** Emoji in headings and list items. Remove; keep only emoji that carries meaning in a channel where emoji is native (Slack, sometimes LinkedIn).

### 19. Curly quotes
**Problem:** Curly quotes where the target format uses straight. Fix only when the target format is plain text or code; leave in docs that auto-curl. Not a tell on its own.

## Chatbot residue

### 20. Chatbot text left in
**Watch:** I hope this helps, Of course!, Certainly!, You're absolutely right, Would you like…, Want me to…, Should I continue?, let me know, here is a…, Sure! Here's…
**Problem:** The assistant's greeting, offer, or close survived into standalone text. Delete.

### 21. Knowledge-cutoff disclaimers and gap-filling guesses
**Watch:** as of [date], up to my last training update, while specific details are limited, based on available information, not publicly available, maintains a low profile, likely [grew up / studied], it is believed that
**Problem:** The model explains it could not find a source, then guesses. State what the source does not show, or cut. Never present a guess as fact.

### 22. Over-agreeable tone
**Watch:** Great question, You're absolutely right, That's an excellent point, What a thoughtful…
**Problem:** Praise before the answer. Delete.

## Filler and hedging

### 23. Filler phrases
in order to → to · due to the fact that → because · at this point in time → now · in the event that → if · has the ability to → can · it is important to note that → (delete) · a number of → some/[the number] · in terms of → (rewrite) · with regard to → about

### 24. Qualifier stacking
**Watch:** to be fair, it's also possible, could potentially, might arguably, in some cases it may, this is an inference
**Problem:** Every claim wrapped in caveats until nothing is asserted. Keep a qualifier only when the source supports it and the meaning needs it. (Hard rule 5.)

### 25. Generic positive endings
**Watch:** the future looks bright, exciting times ahead, continues its journey toward excellence, a major step in the right direction, only time will tell
**Problem:** Vague optimism instead of the last useful fact. Cut the paragraph; end on the last concrete point. (Hard rule 4.)

### 26. Hyphenated pair overuse
**Watch:** third-party, cross-functional, client-facing, data-driven, decision-making, high-quality, real-time, long-term, end-to-end
**Problem:** Hyphenated everywhere. Keep the hyphen before a noun (`a high-quality report`), drop it after (`the report is high quality`).

### 27. Pretending to reveal a deeper truth
**Watch:** the real question is, at its core, in reality, what really matters, fundamentally, the deeper issue, the heart of the matter, at the end of the day
**Problem:** An ordinary point framed as a hidden one. State the point.

### 28. Announcing the next point
**Watch:** let's dive in, let's explore, let's break this down, here's what you need to know, now let's look at, without further ado, heads up, quick note, before I forget, here's a breakdown, below is…
**Problem:** Announces instead of states. Casual register ("one thing that bit me, so pay attention") is still an announcement. Delete the announcement. (Hard rule 2.)

### 29. Heading repeated in the first sentence
**Problem:** `## Performance` followed by "Speed matters." Delete the restating sentence.

### 30. Writing about the previous version
**Problem:** Docs and comments describe the change ("this replaces the old loop") instead of the current behaviour ("uses a hash map for O(1) lookup"). History goes in the changelog. (v-review hunt 22.)

### 31. Forced punchlines and dramatic fragments
**Watch:** X. And Y. And Z. · That's it. That's the whole thing. · This is big. · Game changer. · Every. Single. Day.
**Problem:** Every sentence a mic-drop. One short sentence lands; a row of fragments is theatre. Rewrite as sentences.

### 32. Formulaic sayings
**Watch:** X is the Y of Z, X becomes a trap, X is not a tool but a mirror, the language of, the currency of, the architecture of, an execution problem dressed up as a leadership problem
**Problem:** A pithy formula in place of the specific claim. State the claim.

### 33. Fake-candid openings
**Watch:** Honestly?, Look, Here's the thing, The thing is, Let's be honest, Real talk, And honestly?, I'll be honest, Can I be real, I wasn't going to share this but
**Problem:** A staged pause or claim of honesty before a routine point. State the point. Real candour does not announce itself.

### 34. Answering objections no one raised
**Watch:** This isn't (mainly/really) about, I'm not saying/arguing, To be clear, Don't get me wrong, This is not to say, Some might say… but
**Problem:** Defending against an objection that appears nowhere in the text. Remove the defence; if it hides a real claim, state the claim. Keep an objection when the text names its source or answers it in full.

### 35. Rejecting strawman alternatives
**Watch:** A tempting approach would be, One might be tempted to, An obvious approach would be, You might think… but, It would be easy to just, Some would suggest
**Problem:** An option no reader would consider is introduced, dismissed in a clause, and never mentioned again. Usually a leftover drafting idea. Remove it; state the real constraint. Keep real alternatives a reader would weigh.

## Structure (additions)

### 36. Generic opening
**Problem:** Opens with a claim anyone could make ("In today's fast-moving world, communication is key") instead of a specific story, number, example, or contrarian claim with evidence. Also: triple rhetorical question hook, stat-bomb opener (three statistics in a row as fragments), cliché proverb opener ("Work smarter, not harder"), credential stacking ("After 15 years and 3 exits…") before the point.
**Fix:** Start with the specific thing that happened, or the claim itself.

### 37. Template shape
**Problem:** Intro → three bullet points → conclusion. Hook → list → mic-drop. Every paragraph the same length. Label-colon framework packaging observations as a methodology. Recognisable at a glance as generated.
**Fix:** Let the content decide the shape. Vary paragraph length. Prose where prose carries more.

### 38. Colon reveal and self-posed question
**Watch:** The best part: it learns. · The answer is straightforward: · Why? Because… · The skill that separates them? Critical thinking.
**Problem:** Fake drama via punctuation. Rewrite as a plain sentence. Colons are for lists, labels, quotes.

### 39. Adverb-stacking pivot
**Watch:** X matters. Y matters. But that's not the point. The point is Z.
**Fix:** "Z." One declarative sentence.

### 40. Runway sentences and product-tagline phrasing
**Watch:** a vague hype line before the actual detail ("This changes how teams work. Here's how:"); compact feature-copy phrasing in non-product prose ("Hands-free until review", "Built for scale")
**Fix:** Cut the runway; start with the substance. Write like a person talking, not a landing page.

### 41. Stacked abstract nouns
**Watch:** creativity, passion, joy and drive · trust, transparency and accountability
**Problem:** Three or more abstract nouns for emotional weight. Replace with one concrete claim, or keep one noun.

### 42. Interpretive metadiscourse
**Watch:** That last part matters more than it sounds. The key point is. As you can see. This distinction matters. Read that again. Let that sink in. In other words (when nothing is rephrased).
**Problem:** Steps outside the subject to tell the reader what to notice or how much weight to give it. If the point is clear, delete. Otherwise replace with support. (Hard rule 2.)

### 43. Reading-complexity creep
**Problem:** Clusters of three-syllable words and nested dependent clauses push a conversational piece past grade 10. Rewrite with shorter words and sentences. Technical reference docs may run higher when the terms are the domain's.

### 44. Fake dialogue format
**Watch:** CEO: … CMO: … · Founder: … Investor: … · Me: … Also me: …
**Problem:** An opinion laundered as a scripted conversation to simulate authority. Rewrite as direct prose with the argument up front.

## Artifact tells (from slopornot, language-agnostic)

### S1. Placeholder scaffolding
`[Your Name]`, `[Date]`, `[Insert source]`, `<title here>`, `TODO`, `Lorem ipsum`, instruction text left in a paragraph. Remove or fill from the source; never fill from imagination.

### S2. Markup leakage
Stray `###`, `**bold**` in plain text, bullet markers inside paragraphs, unrendered tables, HTML fragments, `contentReference`, `oaicite`, `oai_citation`, `attached_file`, `attributableIndex`. Strip.

### S3. Search and citation leakage
`turn0search0`, `turn1view2`, `utm_source=chatgpt.com`, links to search-result pages, references declared but unused, links that do not support the sentence. Strip the token; keep the claim only if the source supports it. This is a source-integrity problem, not just style.

### S4. Unrequested structured summaries
A table, scorecard, checklist, or "Key takeaways" block added where prose was asked for, repeating what the prose already said. Delete the duplicate structure.

### S5. Correspondence wrappers
`Subject:`, `Dear`, `I hope this email finds you well`, `Best regards`, signature blocks, when the target is not an email. Remove.

### S6. Abrupt generation artifacts
Unfinished sentences, duplicated trailing phrases, refusal remnants ("I cannot assist with that"), "I don't have access to current information" inside usable prose. Remove without removing meaning.

### S7. Compliance and quality performance claims
"meets all guidelines", "fully compliant", "well-sourced", "high-quality sources", "production-ready", "thoroughly tested", "follows best practices". Replace with the evidence (what was cited, what was run) or delete.

### S8. Register or dialect discontinuity
Plain prose suddenly promotional; US and UK spellings mixed; formality jumping between paragraphs; a paragraph that reads as pasted from elsewhere. Smooth toward the writer's register and the requested dialect; keep facts.
