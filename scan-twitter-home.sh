#!/usr/bin/env bash
#
# scan-twitter-home.sh — read your X HOME feed as a source (vector C).
#
#   CAPTURE (home feed) -> JUDGE -> (ENGAGE) -> DISCOVER -> PERSIST + REPORT -> GROW
#
# Three roles (all on): REPORT significant feed posts, ENGAGE (like/follow) them,
# and DISCOVER untracked authors — but a new person is added to people-db ONLY if
# (post is SIG) AND (the author reads as a genuine AI person/operator from their bio).
#
# Engagement rule (one bar, but split on the feed): LIKE any SIG post; FOLLOW only
# the AI-person authors being added (don't follow randos). Engagement is OFF unless
# --engage; --dry-run logs intent. people-db grows (working copy) regardless.
#
# BOUNDED by design (no endless scroll / endless adds):
#   -n  posts to read          (default 30)
#   --max-new  new people/run  (default 10)
#   --max-likes / --max-follows
#
# Usage:
#   ./scan-twitter-home.sh                 # read home, report + discover (no engage)
#   ./scan-twitter-home.sh --engage --dry-run
#   ./scan-twitter-home.sh -n 40 --max-new 8
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

NPOSTS=30; MAXNEW=10; MAXL=25; MAXF=12; ENGAGE=0; DRYRUN=0
PEOPLE_DB="${PEOPLE_DB:-$DIR/../people-db/people.json}"
RUBRIC="${RUBRIC:-$DIR/../people-db/judge_prompt.md}"
PDB_DIR="$(dirname "$PEOPLE_DB")"; UPDATE_TOOL="$PDB_DIR/tools/update_people_db.py"
STORE_DIR="$DIR/store/raw"; ACT_DIR="$DIR/store/actions"; DISC_DIR="$DIR/store/discoveries"; DIGEST_DIR="$DIR/digests"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NPOSTS="$2"; shift 2 ;;
    --max-new) MAXNEW="$2"; shift 2 ;;
    --max-likes) MAXL="$2"; shift 2 ;;
    --max-follows) MAXF="$2"; shift 2 ;;
    --engage) ENGAGE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$STORE_DIR" "$ACT_DIR" "$DISC_DIR" "$DIGEST_DIR"
[[ -f "$RUBRIC" ]] || { echo "Missing rubric: $RUBRIC" >&2; exit 1; }

DATE="$(date +%Y-%m-%d)"; RUNID="$(date +%Y%m%d-%H%M%S)"; STAMP="$(date '+%Y-%m-%d %H:%M %Z')"
RAWFILE="$STORE_DIR/twitter-home-$RUNID.jsonl"
DIGEST="$DIGEST_DIR/twitter-home-$DATE.md"
SEEN="$STORE_DIR/.seen_ids.txt"
ACTFILE="$ACT_DIR/twitter-home-$RUNID.jsonl"
DISCFILE="$DISC_DIR/twitter-home-$RUNID.jsonl"

if   [[ $ENGAGE -eq 0 ]]; then ENGAGE_DESC="OFF"
elif [[ $DRYRUN -eq 1 ]]; then ENGAGE_DESC="DRY-RUN (record intent, NO clicks)"
else ENGAGE_DESC="LIVE"; fi

python3 - "$STORE_DIR" > "$SEEN" <<'PY'
import sys, glob, json, os
seen=set()
for fp in glob.glob(os.path.join(sys.argv[1],"twitter*.jsonl")):
    for line in open(fp,encoding="utf-8"):
        line=line.strip()
        if not line: continue
        try: seen.add(json.loads(line)["id"])
        except Exception: pass
print("\n".join(sorted(seen)))
PY
SEEN_COUNT=$(grep -c . "$SEEN" || true)
echo ">> Reading X home feed: up to $NPOSTS posts; add up to $MAXNEW new AI-people; engagement: $ENGAGE_DESC; $SEEN_COUNT seen."

PROMPT=$(cat <<EOF
You are reading the X HOME feed (vector C) via chrome-devtools MCP (logged in).
Goal: surface what AI leaders are doing/thinking AND discover new AI people the
algorithm shows you. Stages: CAPTURE -> JUDGE -> ENGAGE -> DISCOVER -> REPORT.
Work human-paced and BOUNDED — do not endlessly scroll.

CAPS ARE CEILINGS, NOT TARGETS: stop as soon as you are caught up (you hit a run
of already-seen posts) or run out of genuinely new material — whichever comes
before the cap. Never scroll past already-seen content to reach the cap; an empty
or near-empty run is correct when little is new. Likewise the new-people cap is a
ceiling — only add people who genuinely qualify, never to "fill" it.

Read first (Read tool):
- Rubric: $RUBRIC   (apply exactly)
- People/entity context: $PEOPLE_DB  (entity-context AND the set of ALREADY-TRACKED handles)
- Already-seen post ids (DO NOT re-report): $SEEN

== CAPTURE (bounded) ==
Navigate https://x.com/home (timeout 60000; ignore a false timeout). Read newest
downward and STOP after ~$NPOSTS posts — do NOT keep scrolling past that. Skip
promoted/ads and "who to follow". For each post capture: id (status permalink),
author handle + display name + their one-line bio/headline if visible, date, type,
verbatim text, engagement, and (if a reshare/quote) the original author. Skip any
post whose id is already-seen.

== JUDGE ==
Apply the rubric -> SIG | INSIG | SKIP (+ <=12-word reason), using entity-context.

== ENGAGE (mode: $ENGAGE_DESC) ==
Only for SIG posts. Caps: max $MAXL likes, max $MAXF follows.
- LIKE the SIG post (the most direct algorithm signal). Skip if already liked.
- FOLLOW the author ONLY if that author is being ADDED as a new AI-person below
  (do NOT follow people you're not tracking). Skip if already following.
- If mode OFF: do nothing. If DRY-RUN: record intent, do not click.
- Log each action to "$ACTFILE": {"action":"like"|"follow","post_id":"...","target":"@handle","author":"...","dry_run":$( [[ $DRYRUN -eq 1 ]] && echo true || echo false ),"ts":"$STAMP"}

== DISCOVER (bounded: add at most $MAXNEW new people this run) ==
A candidate = the author of a SIG post who is NOT among the already-tracked handles.
Process candidates newest-first; STOP once $MAXNEW are added (and don't evaluate many
more than that — bound the cost). For each candidate:
  1. OPEN their profile — navigate to https://x.com/<handle>, read their BIO + ~3 recent
     posts. The X feed shows NO bio, so you MUST check the profile; never judge from the
     handle alone. (READ-ONLY — do not like/follow/reply on the profile.)
  2. DECIDE: are they a GENUINE AI person/operator (founder / researcher / builder / exec
     in AI, or consistently posts substantive AI work) — NOT a generic influencer, rando,
     or non-AI account?
  3. If YES, append to "$DISCFILE":
     {"platform":"x","handle":"<handle>","name":"<display name>","kind":"person","role_org":"<from their actual bio>"}
One record per new handle. A SIG author judged NOT an AI-person is reported but not added
(and not followed).

== PERSIST + REPORT ==
A) Write ALL captured posts (every label) to "$RAWFILE" as JSONL (keys: id, platform
   "x", handle, author, date, type, text, links[], engagement{}, label, reason,
   source "home", scraped_at "$STAMP").
B) Write the digest "$DIGEST": "# X home digest — $DATE" + counts; then a
   "## From your feed" section grouping the SIG posts by author with a 1-2 line gist
   each; then a "## New AI people discovered" list (handle — role) for those added.
   Footer: posts read, significant, engaged, new people (and if a cap was hit).

Finally print one line: posts read / significant / engaged / new-people.
EOF
)

claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --mcp-config "$DIR/.mcp.json" \
  --allowedTools "mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__evaluate_script,mcp__chrome-devtools__click,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__new_page,Read,Write" \
  2>&1 | tee "$DIGEST_DIR/run-home-$RUNID.log"

if [[ -f "$PEOPLE_DB" && -f "$UPDATE_TOOL" ]]; then
  echo ">> Adding discovered AI-people to people-db..."
  python3 "$UPDATE_TOOL" --people "$PEOPLE_DB" --platform x --today "$DATE" --raw "$RAWFILE" --disc "$DISCFILE" || echo "WARN: people-db update failed" >&2
fi
echo ">> Done. Digest: $DIGEST  Raw: $RAWFILE  (engagement: $ENGAGE_DESC)"
