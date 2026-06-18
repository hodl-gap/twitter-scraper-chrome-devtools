#!/usr/bin/env python3
"""Build the significance-judge eval set from the 2026-06-18 hand-labeled corpus.

Writes:
  corpus.json        — full records incl. gold_label + gold_note (the answer key)
  corpus_blind.json  — same minus gold_* (what the judge sees)

30 labeled items (the 5 owner-skipped posts are excluded; #27/#28 are merged
into #26). Texts are verbatim where re-fetched in full; a few off-topic/promo
ones are the captured (possibly truncated) text — enough to judge their label.
"""
import json, os

P = []
def add(id, account, author, role_org, date, gold, text, entity_note="", truncated=False, gold_note=""):
    P.append({
        "id": id, "account": account, "author": author, "role_org": role_org,
        "date": date, "entity_note": entity_note, "truncated": truncated,
        "full_text": text.strip(), "gold_label": gold, "gold_note": gold_note,
    })

KARP = "Andrej Karpathy"; KR = "Anthropic (joined May 2026); ex-OpenAI, ex-Tesla AI; founder Eureka Labs"
DWAR = "Dwarkesh Patel"; DR = "Host, Dwarkesh Podcast"
PERCY = "Percy Liang"; PR = "Stanford CS prof; Marin open lab; Together AI"
PACH = "Jakub Pachocki"; PAR = "Chief Scientist, OpenAI"
CHER = "Boris Cherny"; CR = "Anthropic; creator of Claude Code"

add("1", "karpathy", KARP, KR, "2023-01-25", "INSIG",
    "The hottest new programming language is English")
add("2", "karpathy", KARP, KR, "2026-06-13", "INSIG",
    "In awe of SpaceX and its story - past, present and the future. You can think about it in 10+ different ways and continue re-blowing your mind in circles. Huge congrats to the team!")
add("3", "karpathy", KARP, KR, "2026-06-10", "SIG",
    "This is a super exciting release - Claude Fable 5 is the same underlying model as Mythos but with added safeguards. The benchmarks are great and it's SOTA on everything by a margin but I'll add that *qualitatively* also, this is a major-version-bump-deserving step change forward",
    entity_note="Reply to @claudeai. Karpathy joined Anthropic 2026-05-20, so by this date he is an INSIDER on Claude releases — insider framing, not outsider echo.",
    gold_note="corrected 2026-06-19: was INSIG on a false outsider premise (we didn't know he'd joined Anthropic)")
add("4", "karpathy", KARP, KR, "2026-06-03", "SKIP",
    "", entity_note="Media/quote repost of @trq212 with no extractable text.", truncated=True)
add("5", "karpathy", KARP, KR, "2026-06-01", "SIG",
    "This has quietly been a miracle month in medicine.\n\nIn the last 5 weeks we've got news on:\n\n- retatrutide, the triple agonist GLP-1 from Lilly, basically melting fat and body-wide inflammation at record levels\n- RevMed's new pancreatic cancer drug showing unprecedented abilities to extend life\n- small trial of a one-and-done PCSK9 gene editing therapy for slashing LDL cholesterol\n- Mayo's AI-assisted radiology showing vastly improved cancer detection\n- this new therapy for metastatic solid tumors\n\nThis stuff is at varying levels of evidence. Retatrutide is ~100% on its way, other stuff needs more clinical trial data. But put it together and we're maybe on the verge of majorly reducing the mortality of heart disease and cancer, the two leading causes of death in America.",
    entity_note="Repost of @DKThomp (Derek Thompson) with no added commentary.", gold_note="borderline")
add("6", "karpathy", KARP, KR, "2026-03-10", "SIG",
    "oh yeah i should have linked autoresearch probably\n\nhttps://github.com/karpathy/autoresearch\n\n(you don't \"use it\" directly, it's just a recipe/idea - give it to your agent and apply to what you care about.)",
    entity_note="autoresearch = Karpathy's open-source repo/recipe for LLM-driven research; went mini-viral.")
add("7", "karpathy", KARP, KR, "2026-03-09", "SIG",
    "The next step for autoresearch is that it has to be asynchronously massively collaborative for agents (think: SETI@home style). The goal is not to emulate a single PhD student, it's to emulate a research community of them.\n\nCurrent code synchronously grows a single thread of commits in a particular research direction. But the original repo is more of a seed, from which could sprout commits contributed by agents on all kinds of different research directions or for different compute platforms. Git(Hub) is *almost* but not really suited for this.\n\nI'm not actually exactly sure what this should look like, but it's a big idea that is more general than just the autoresearch repo specifically. Agents can in principle easily juggle and collaborate on thousands of commits across arbitrary branch structures. Existing abstractions will accumulate stress as intelligence, attention and tenacity cease to be bottlenecks.",
    entity_note="autoresearch = Karpathy's research-agent repo.")
add("8", "karpathy", KARP, KR, "2026-03-08", "SIG",
    "I packaged up the \"autoresearch\" project into a new self-contained minimal repo if people would like to play over the weekend. It's basically nanochat LLM training core stripped down to a single-GPU, one file version of ~630 lines of code, then:\n\n- the human iterates on the…",
    entity_note="autoresearch = Karpathy's research-agent repo. (text truncated)", truncated=True)
add("9", "dwarkesh_sp", DWAR, DR, "2026-04-16", "SKIP",
    "The Jensen Huang episode.\n\n0:00:00 – Is Nvidia's biggest moat its grip on scarce supply chains?\n0:16:25 – Will TPUs break Nvidia's hold on AI compute?\n0:41:06 – Why doesn't Nvidia become a hyperscaler?\n0:57:36 – Should we be selling AI chips to China?\n1:35:06 – Why doesn't Nvidia…",
    entity_note="Podcast-episode promo. The substance is in the video/episode, not the post text.", truncated=True)
add("10", "dwarkesh_sp", DWAR, DR, "2026-06-17", "INSIG",
    "Giordano Bruno was burned at the stake by the Inquisition in 1600. But it wasn't his first trial. They'd found his radical writings before, and every time he'd got off with a slap on the wrist. What changed?\n\nWell, Renaissance justice ran on patronage. Law codes set out extremely…",
    truncated=True)
add("11", "dwarkesh_sp", DWAR, DR, "2026-06-17", "INSIG",
    "Machiavelli learned politics by trying to save his city from Cesare Borgia - a conqueror so terrifying and charismatic that people thought he was the Antichrist.\n\nMachiavelli was Florence's ambassador to Borgia. His job was to convince the tyrant that the city was a loyal ally.",
    truncated=True)
add("12", "dwarkesh_sp", DWAR, DR, "2026-06-04", "INSIG",
    "Ken Rogoff, former IMF chief economist, points out that countries can go bankrupt even with good growth.\n\nDebt crises are really about politics: whether leaders are willing and able to manage tax, spending, and inflation.",
    truncated=True)
add("16", "percyliang", PERCY, PR, "2025-05-20", "SIG",
    "What would truly open-source AI look like? Not just open weights, open code/data, but *open development*, where the entire research and development process is public *and* anyone can contribute. We built Marin, an open lab, to fulfill this vision:\n\nMarin (marin.community) repurposes GitHub, which has been successful for open-source software, for AI: preregister an experiment as a GitHub issue, submit a PR implementing it, PR reviewed by community experts, watch execution live.\n\nWe have trained some respectable models from scratch! Marin-8B-Base beats Llama 3.1 8B on 14/19 benchmarks; Marin-8B-Instruct available on Together. We're also training Marin-32B-Base (watch live on wandb). All models Apache 2.0 on huggingface.co/marin-community.\n\nSpeedrun leaderboard: pick a compute budget, drive down validation loss. Datashop to curate data and train models. Website / GitHub / Discord / Docs.",
    entity_note="Marin = Percy's open-source AI lab. (7-tweet thread, merged)")
add("17", "percyliang", PERCY, PR, "2026-06-06", "SIG",
    "There are two types of advances: (i) a singular change that provides 3x and (ii) a series of micro changes that each provide 20%. It is easy to celebrate (i), but (ii) is just as important, and the hard part is making sure the improvements stack. We care about both in Marin.",
    entity_note="Marin = Percy's open-source AI lab (so this is about AI R&D, not generic advice).", gold_note="borderline")
add("18", "percyliang", PERCY, PR, "2026-06-04", "SIG",
    "Quoting @dlwh: we are at risk of losing the reputation of spiky loss runs!\n\nThis run incorporates some stability techniques from my past projects: Hyperball, Gated Norm, and Gated Attention. Excited to see the next run from Marin!",
    entity_note="Repost of @wen_kaiyue. Marin = Percy's AI lab; about training-stability techniques in his lab's work.")
add("19", "percyliang", PERCY, PR, "2026-06-03", "SIG",
    "MiniMax-M3 combines 1M context, native multimodality, and MiniMax Sparse Attention.\n\nThe next layer is serving it efficiently: KV-block-major sparse attention, paged MSA decode, optimized index scoring, and multimodal preprocessing before the GPU worker.\n\nTogether's Inference and Kernel teams improved throughput by 81-125% across common agentic-shape traffic.",
    entity_note="Repost of @togethercompute. MiniMax-M3 = a new AI model; Percy is at Together AI.")
add("20", "percyliang", PERCY, PR, "2026-04-10", "SIG",
    "Twitter's algorithm is optimized for addiction, not for us. We deserve better.\n\nWe're releasing Bouncer today so you can take back control of your feed. Describe what you don't want, and Bouncer removes it.\n\nIt's free, doesn't collect your data, and will be open source soon.",
    entity_note="Repost of @kanjun. Bouncer = an AI-powered feed-filtering tool.")
add("21", "percyliang", PERCY, PR, "2026-04-02", "SIG",
    "Our 1e23 Delphi run finished last night. It's loss was within 0.005 of the projected (preregistered) loss. Note that these projections were based on only training models over 100x smaller (3e20)!\n\nStill more work to do. We still had loss spikes and if you look closely, our scaling laws are bending. We have some ideas for fixing both...",
    entity_note="Delphi/Marin = Percy's lab's training runs.")
add("24", "merettm", PACH, PAR, "2026-06-09", "SIG",
    "The north stars we're working towards at OpenAI all center around the mission: ensure AGI benefits all of humanity. AI should expand human agency, not make people less consequential to the future.",
    entity_note="Pachocki is OpenAI's chief scientist (an insider stating org direction).")
add("25", "merettm", PACH, PAR, "2026-05-21", "SIG",
    "Today, we share a breakthrough on the planar unit distance problem, a famous open question first posed by Paul Erdős in 1946.\n\nFor nearly 80 years, mathematicians believed the best possible solutions looked roughly like square grids.\n\nAn OpenAI model has now disproved that belief, discovering an entirely new family of constructions that performs better.\n\nThis marks the first time AI has autonomously solved a prominent open problem central to a field of mathematics.",
    entity_note="Repost of @OpenAI (his own lab's research breakthrough).")
add("26", "merettm", PACH, PAR, "2026-02-14", "SIG",
    "Very excited about the \"First Proof\" challenge. I believe novel frontier research is perhaps the most important way to evaluate capabilities of the next generation of AI models.\n\nWe have run our internal model with limited human supervision on the ten proposed problems... based on expert feedback we believe at least six solutions (2, 4, 5, 6, 9, 10) have a high chance of being correct. This was a side-sprint executed in a week, mostly by querying one of the models we're currently training; we didn't provide proof ideas, and manually facilitated a back-and-forth between this model and ChatGPT for verification.\n\n[self-reply] Solution attempts from our model: cdn.openai.com/pdf/...\n\n[self-reply, Feb 15] Based on the official #1stProof commentary, community analysis, and more clarification with external experts we now believe the solution to problem 2 above is likely incorrect. Grateful for the engagement and looking forward to continued review!",
    entity_note="First Proof = a challenge to evaluate AI on novel math. Pachocki = OpenAI chief scientist. (3-tweet thread incl. a next-day correction, merged)")
add("29", "merettm", PACH, PAR, "2025-09-18", "SIG",
    "Alignment is arguably the most important AI research frontier.\n\nAs we scale reasoning, models gain situational awareness and a desire for self-preservation. Here, a model identifies it shouldn't be deployed, considers covering it up, but then realizes it might be in a test.",
    entity_note="Repost of @markchen90 (Mark Chen, OpenAI). Alignment-frontier content.")
add("30", "bcherny", CHER, CR, "2026-06-17", "SIG",
    "New in Claude Design: it stays on brand with your design system across projects, lets you edit directly on the canvas, syncs with Claude Code, and connects to more of the tools you already use.",
    entity_note="Repost of @claudeai. Claude Design = an Anthropic product; Cherny is an Anthropic insider.", gold_note="borderline")
add("31", "bcherny", CHER, CR, "2026-06-12", "INSIG",
    "/goooooal",
    entity_note="Repost of @ClaudeDevs. Pure hype/celebration.")
add("32", "bcherny", CHER, CR, "2026-06-11", "INSIG",
    "claude fable 5 has solved CAD\n\nI asked it to make a model of a V8 engine\n\nIt came back to me with a fully working model in under 10 minutes",
    entity_note="Repost of @aaronli. A third-party hype/demo anecdote about Claude Fable 5.")
add("33", "bcherny", CHER, CR, "2026-06-11", "SIG",
    "NEW: Ramp AI Index for June 2026\n\n1. We expected OpenAI to gain on the launch of Codex. It held flat in business adoption last month.\n\n2. Anthropic grew 2.5% points to 41% of firms. It's now driving new AI adoption with never-adopters.\n\nWe also made methodological updates to better capture spend on bill pay. OpenAI adoption was higher over the 2023-2025 period, but Anthropic remains the most popular model among businesses today.",
    entity_note="Repost of @arakharazian. Industry AI-adoption data (market share).", gold_note="peripheral category")
add("34", "bcherny", CHER, CR, "2026-05-26", "SIG",
    "…[W]e keep finding things that are mysterious, even unsettling. We find structures that mirror results from human neuroscience. We find evidence of introspection. We find internal states that functionally mirror joy, satisfaction, fear, grief, and unease. I don't know what that means, but I think it warrants ongoing discernment.\n\nWe need more of the world—religious communities, civil society, scholars, governments... to take this seriously, to look closely. We need informed critics who will tell the labs when we are failing.",
    entity_note="Quote-tweet of @AnthropicAI, quoting Anthropic co-founder Chris Olah on model interpretability.")
add("35", "bcherny", CHER, CR, "2026-05-24", "SIG",
    "People often ask what my biggest tip is for getting the most out of Claude Code.\n\nThese days my #1 tip is: use auto mode\n\nAuto mode means no more permission prompts. It is the key building block for multi-clauding: start a session, then while it runs, work on another session in parallel.",
    entity_note="Cherny is the creator of Claude Code (firsthand). This is a usage tip.", gold_note="borderline (tip, not insight)")
add("36", "bcherny", CHER, CR, "2026-05-23", "INSIG",
    "Big fan of teaching more people the basics of using Claude Code in an accessible way.\n\nSo much of the world has not yet used agents. There's a lot of opportunity to level the playing field and expand access.")
add("37", "bcherny", CHER, CR, "2026-05-27", "SIG",
    "We've shipped a security-guidance plugin for Claude Code that helps identify and fix vulnerabilities as you're writing code.\n\nAvailable for all Claude Code users. Install from the plugin marketplace (/plugins).",
    entity_note="Repost of @ClaudeDevs. An Anthropic feature launch; Cherny is an insider.", gold_note="borderline")

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "corpus.json"), "w") as f:
    json.dump(P, f, ensure_ascii=False, indent=2)
blind = [{k: v for k, v in r.items() if k not in ("gold_label", "gold_note")} for r in P]
with open(os.path.join(here, "corpus_blind.json"), "w") as f:
    json.dump(blind, f, ensure_ascii=False, indent=2)

from collections import Counter
c = Counter(r["gold_label"] for r in P)
print(f"{len(P)} items: " + ", ".join(f"{k}={v}" for k, v in sorted(c.items())))
