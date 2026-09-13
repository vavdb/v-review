# False positives and human details to keep

Read before flagging anything. The patterns in `patterns-core.md` are clues, not proof. Two or more in one paragraph, or an exact "words to watch" phrase, is a real tell. One isolated signal is not.

## Not a tell on its own

- **Perfect grammar and consistent style.** Professionals and edited writers produce this. Polish is not AI.
- **Mixed casual and formal register.** Common in technical writers, young writers, neurodivergent writers.
- **Bland or dry prose.** AI has *specific* tells. Dryness without them is dry writing.
- **Formal or academic vocabulary.** Only the words in `banned-words.md` are over-used by AI. Do not flatten "ostensibly" or "constituent" because they sound clever.
- **A salutation or sign-off.** Predates chatbots by centuries.
- **One transition word.** "Additionally", "moreover", "consequently" are tells when piled up. One "however" is not.
- **Curly quotes alone.** macOS, Word, Google Docs and most CMSes auto-curl.
- **Em dashes alone.** Many editors and journalists use them. Evidence only alongside sales rhythm. (This is a detection rule; the output rule in pattern 14 still strips them unless the sample uses them.)
- **One short sentence for emphasis.** Flag staccato drama only when several fragments run in a row.
- **Deliberate repeated openings.** "She came. She saw. She conquered." Change only when the repetition adds nothing.
- **"Honestly" or "look" mid-sentence.** Ordinary in casual writing. The tell is the standalone theatrical opener.
- **Real limits and disclaimers.** Scope statements, legal and safety notices, corrections, named objections, FAQ answers stay.
- **Real alternatives.** Options a reader would actually weigh, in a design doc or tutorial, stay. Only the strawman that is dismissed and never mentioned again goes.
- **Unsourced claims.** Most of the web is unsourced. Lack of citations proves nothing. Vague-authority phrasing ("experts argue") is still a tell.
- **Correct, complex formatting.** Templates and visual editors produce this without AI.
- **Secondhand text.** Do not rewrite watched phrases inside quotations, titles, proper names, code, or examples where the phrase is discussed rather than used.
- **A single bullet list in a doc.** Lists are fine when the items are parallel and there are four or more. The tell is bullets where two sentences of prose would read better, or bold-label-colon on every item.

## Human details to keep

These carry the writer. Leave them unless they damage meaning.

- **Specific, odd, hard-to-fabricate detail.** A real address, a weird quote, "the lawyer who used to work upstairs from my dentist". Models round off specifics; people hoard them.
- **Mixed feelings and unresolved tension.** "Mostly good, but it bothers me and I can't say why." Models default to clean takes.
- **Era-bound references.** Slang, memes, in-jokes tied to a year and subculture. Models lag.
- **First-person choices the writer can defend.** If they can say *why* that word, it stays.
- **Uneven sentence length.** Real writing alternates. AI drifts to an even, mid-length cadence.
- **Genuine asides, parentheticals, self-corrections.** "(I keep wanting to write 'almost' here, but it really was certain.)" One aside is voice. Four in a paragraph is performance.
- **Profanity, bluntness, humour, admissions.** Do not launder them into safer wording.
- **Text dated before 30 November 2022.** ChatGPT's public launch. Older text is almost never AI. Applies only when the input carries a date.

## Cluster versus isolated, worked

**Leave it.** "Honestly, the launch was rough, but we shipped on the 14th and the team was proud of it." One casual opener, one short aside, a real date, a real feeling. No cluster.

**Fix it.** "In today's fast-paced landscape, this pivotal solution stands as a testament to innovation, seamlessly empowering teams to unlock their full potential." Filler opener, AI vocabulary ×4, copula avoidance, sales tone, generic flourish. Rewrite.
