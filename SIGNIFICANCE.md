# Significance Filter — spec (v1, 2026-06-18)

Shared filter logic for both scrapers (`twitter-scraper-chrome-devtools`,
`linkedin-scraper`). Splits scraped posts into **significant** (goes in the
report) vs **insignificant** (recorded only, for dedup). The same flag will
later gate auto-like / auto-follow for feed-discovery tuning.

> Status: v1, induced from a 37-post hand-labeled corpus (below). A good
> starting point, not yet fully what we want — expected to sharpen as the
> labeled set grows.

## Goal

**Catch up with AI industry trends — what the leaders are doing, thinking, and building.**

## Decision: SIG / INSIG / SKIP

**→ SIG** — reveals a leader's actual AI work / thinking / attention:
- Their own builds, results, launches, substantive ideas, or stated positions —
  *even if PR-flavored, if they are an insider on it*.
- Amplifying/curating substantive content (a repost) — signals *what they're
  paying attention to*, even with no added commentary.
- An insider amplifying their own org's concrete product/feature launch.

**→ INSIG:**
- Low-information: hype, pure sentiment, engagement bait, celebration.
- Hype testimonials / capability-demo anecdotes — flashy, thin on substance.
- Bare news-echo from a *non-insider* with no added insight.
- Off-topic to AI: history, economics, science, personal milestones.

**→ SKIP (undeterminable — cannot judge from available data):**
- No extractable text (media-only repost).
- Substance locked in unreachable media (e.g. a podcast/video) with no text and
  no outside knowledge to judge by.

### Sub-tiers (for later weighting)
- **Depth:** insight (understanding / trend) > tip (practical how-to).
- **Category:** core technical / research / product / leader-thinking is the
  target; market-adoption stats are sig-but-peripheral.
- (Deferred: a possible second axis — "report-worthy" vs "amplify/like-worthy" —
  may diverge; see project notes.)

## What the judge needs beyond the post text

The labels repeatedly proved the post text alone is insufficient. The judge needs:
1. **Entity-context layer** — a known people/orgs/projects map (see the human-DB).
   You cannot tell #17/#20 are AI-related without knowing what Marin / Bouncer are.
2. **Link-following** — for link-bearing posts, read the linked artifact
   (repo/article); significance often lives there, not in the tweet (#6).
3. **Insider-vs-outsider awareness** — flips the call (#3 insig vs #24/#30 sig).
4. **World knowledge** — virality / real-world impact context (#6).

## Separate mechanical gates (not significance judgments)

- **Recency** — live runs surface only recent posts; significance is judged
  *as if seen fresh*, independent of date.
- **Dedup** — topic-level: cluster same-topic posts across days, don't re-report
  (#6/#7/#8 = one `autoresearch` topic).
- **Thread-merge** — detect self-reply chains (even multi-day) and merge into one
  article *before* judging (#16 = 7 tweets; #26 = 3 tweets incl. a next-day
  correction). The scraper currently captures per-post and missed 6 of 7 tweets
  on #16 — thread detection is a real build item.

## Labeled corpus v1 — 2026-06-18

37 posts from @karpathy, @dwarkesh_sp, @percyliang, @merettm (Pachocki),
@bcherny (Cherny). Hand-labeled by the owner. Serves as both the rubric's
worked examples and a validation set for the judge. (Full verbatim texts are
reproducible via `scan-twitter.sh`; truncated ones were re-fetched in full.)

| # | Account | Date | Label | Reason |
|---|---------|------|-------|--------|
| 1 | karpathy | Jan'23 | INSIG | engagement-farming one-liner, no substance |
| 2 | karpathy | Jun 13 | INSIG | pure sentiment ("in awe of SpaceX"), no info |
| 3 | karpathy | Jun 10 | INSIG | bare release-echo (Fable 5), outsider, no added insight |
| 4 | karpathy | Jun 3 | SKIP | no extractable text (media repost) |
| 5 | karpathy | Jun 1 | SIG (borderline) | repost of info-dense medicine news — leader's attention; partly AI |
| 6 | karpathy | Mar 10 | SIG | autoresearch repo link; sig via repo context (first mention) |
| 7 | karpathy | Mar 9 | SIG | substantive idea — async massively-collaborative agents |
| 8 | karpathy | Mar 8 | SIG | originating autoresearch announcement, technical |
| 9 | dwarkesh_sp | Apr 16 | SKIP | podcast promo; episode content unreachable |
| 10 | dwarkesh_sp | Jun 17 | INSIG | history (Giordano Bruno), off-topic |
| 11 | dwarkesh_sp | Jun 17 | INSIG | history (Machiavelli), off-topic |
| 12 | dwarkesh_sp | Jun 4 | INSIG | economics (Rogoff), off-topic |
| 13–15 | dwarkesh_sp | Jun 3–4 | (unlabeled) | skipped — same off-topic pattern |
| 16 | percyliang | May'25 | SIG | Marin open-lab launch (thread, merged); leader doing |
| 17 | percyliang | Jun 6 | SIG (borderline) | R&D insight; only AI via knowing Marin (entity context) |
| 18 | percyliang | Jun 4 | SIG | amplifying technical detail on own lab — current work |
| 19 | percyliang | Jun 3 | SIG | repost of a model release (MiniMax-M3) — what he's looking at |
| 20 | percyliang | Apr 10 | SIG | repost endorsing AI feed tool (Bouncer); entity-context dependent |
| 21 | percyliang | Apr 2 | SIG | own lab result — Delphi 1e23 hit preregistered loss |
| 22–23 | percyliang | Apr 2 / Mar 28 | (unlabeled) | skipped — personal / process-sentiment |
| 24 | merettm | Jun 9 | SIG | insider leadership positioning (OpenAI north stars) |
| 25 | merettm | May 21 | SIG | amplifying lab research breakthrough (Erdős problem) |
| 26 | merettm | Feb 14–15 | SIG | First Proof thread (internal model on frontier math + honest correction); merges 27, 28 |
| 27, 28 | merettm | Feb 14–15 | (merged) | self-reply continuations of #26 |
| 29 | merettm | Sep'25 | SIG | amplifying alignment-frontier substance |
| 30 | bcherny | Jun 17 | SIG (borderline) | insider amplifying own org launch (Claude Design) |
| 31 | bcherny | Jun 12 | INSIG | pure hype ("/goooooal") |
| 32 | bcherny | Jun 11 | INSIG | hype testimonial / demo anecdote ("solved CAD") |
| 33 | bcherny | Jun 11 | SIG | industry adoption data (Ramp AI Index); peripheral category |
| 34 | bcherny | May 26 | SIG | interpretability findings (introspection / internal states) |
| 35 | bcherny | May 24 | SIG (borderline) | firsthand tip (auto mode / multi-clauding); tip < insight |
| 36 | bcherny | May 23 | INSIG | aspirational hype ("expand access"), low-info |
| 37 | bcherny | May 27 | SIG (borderline) | insider amplifying own org feature launch (security plugin) |

**Tally:** SIG 19 · INSIG 9 · SKIP 2 · unlabeled-skipped 5 · merged 2.

### Per-account signal (observed)
- **@percyliang, @merettm** — ≈ all sig; post their own AI work. High-signal.
- **@karpathy** — mixed; excellent when substantive, noisy viral one-liners otherwise.
- **@bcherny** — mixed; insider launches + real insight, but also hype.
- **@dwarkesh_sp** — ≈ all insig on X; history/science clips, off the AI-trend goal.

## Open items
- Not many posts were *genuinely* what the owner ultimately wants — v1 baseline.
- Decide the second axis (report-worthy vs amplify-worthy) before wiring like/follow.
- Build: thread-merge + topic-dedup + link-following + entity-context join.
