#!/usr/bin/env bash
#
# scan-twitter.sh — significance-filtered X/Twitter monitor (Milestone 1).
#
# Pipeline (one headless `claude -p` agent drives the whole thing):
#   CAPTURE  -> for each handle, fetch posts NEW since last run (incremental),
#               expand threads, store verbatim + metadata.
#   JUDGE    -> label each new post SIG/INSIG/SKIP via the rubric + entity-context
#               from people-db.
#   REPORT   -> one synthesized summary PER PERSON who had >=1 new significant
#               post, with source links. (Per-person, not per-post.)
#
# Artifacts:
#   store/raw/twitter-<runid>.jsonl  — every post seen this run (+ label/reason).
#                                      Append-only memory: dedup + re-judge + corpus.
#   digests/twitter-<date>.md        — the human deliverable (per-person summaries).
#
# Engagement (like/follow) is NOT here yet — that's Milestone 2.
#
# Usage:
#   ./scan-twitter.sh                      # handles.txt
#   ./scan-twitter.sh karpathy percyliang  # ad-hoc handles
#   ./scan-twitter.sh -n 15                # cap new posts/handle this run
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

NPOSTS=15
HANDLES_FILE="handles.txt"
PEOPLE_DB="${PEOPLE_DB:-$DIR/../people-db/people.json}"
RUBRIC="$DIR/eval/judge_prompt.md"
STORE_DIR="$DIR/store/raw"
DIGEST_DIR="$DIR/digests"
HANDLES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NPOSTS="$2"; shift 2 ;;
    -f) HANDLES_FILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) HANDLES+=("${1#@}"); shift ;;
  esac
done

if [[ ${#HANDLES[@]} -eq 0 ]]; then
  [[ -f "$HANDLES_FILE" ]] || { echo "No handles file: $HANDLES_FILE" >&2; exit 1; }
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs)"; line="${line#@}"
    [[ -n "$line" ]] && HANDLES+=("$line")
  done < "$HANDLES_FILE"
fi
[[ ${#HANDLES[@]} -gt 0 ]] || { echo "No handles to scan." >&2; exit 1; }

mkdir -p "$STORE_DIR" "$DIGEST_DIR"
[[ -f "$RUBRIC" ]] || { echo "Missing rubric: $RUBRIC" >&2; exit 1; }
[[ -f "$PEOPLE_DB" ]] || echo "WARN: people-db not found at $PEOPLE_DB (entity-context degraded)" >&2

DATE="$(date +%Y-%m-%d)"
RUNID="$(date +%Y%m%d-%H%M%S)"
STAMP="$(date '+%Y-%m-%d %H:%M %Z')"
RAWFILE="$STORE_DIR/twitter-$RUNID.jsonl"
DIGEST="$DIGEST_DIR/twitter-$DATE.md"
SEEN="$STORE_DIR/.seen_ids.txt"

# Build the set of already-seen post ids (dedup / incremental boundary).
python3 - "$STORE_DIR" > "$SEEN" <<'PY'
import sys, glob, json, os
seen = set()
for fp in glob.glob(os.path.join(sys.argv[1], "twitter-*.jsonl")):
    with open(fp, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: seen.add(json.loads(line)["id"])
            except Exception: pass
print("\n".join(sorted(seen)))
PY
SEEN_COUNT=$(grep -c . "$SEEN" || true)

HANDLE_LINES="$(printf '  - @%s\n' "${HANDLES[@]}")"
echo ">> Scanning ${#HANDLES[@]} handle(s); up to $NPOSTS new posts each; $SEEN_COUNT ids already seen."
echo ">> Raw -> $RAWFILE   Digest -> $DIGEST"

PROMPT=$(cat <<EOF
You are an unattended X/Twitter intelligence agent using the chrome-devtools MCP
tools (browser already logged in). Goal: surface what AI leaders are doing/thinking.
Work human-paced. Run three stages in order: CAPTURE -> JUDGE -> REPORT.

First read these (use the Read tool):
- Significance rubric: $RUBRIC  (apply it exactly, including the edge-case tie-breakers)
- Entity / people context: $PEOPLE_DB  (per-person role_org + notes; use as entity-context when judging)
- Already-seen post ids (one per line; DO NOT re-capture these): $SEEN

Handles to scan:
$HANDLE_LINES

== STAGE 1: CAPTURE (incremental) ==
For each handle, navigate to https://x.com/<handle> (navigate_page timeout 60000;
if it reports a timeout, ignore it and snapshot anyway; if you hit a login wall,
record the handle as logged-out and move on).
- Scroll and read posts from newest downward. STOP for that handle once you reach
  posts whose id is in the already-seen list, or after ~$NPOSTS new posts, whichever first.
- The X timeline is virtualised — read each snapshot as you scroll.
- THREADS: if a post is the head of the author's self-reply thread, expand it
  ("Show this thread" / open it) and capture the WHOLE chain as ONE item.
- For each new post capture: stable id (from its status permalink; else synthesize
  "<handle>:<date>:<first40chars>"), author, date (ISO if possible else relative),
  type (original|reply|repost|quote|thread), verbatim text (expand "Show more"),
  links, and engagement counts. Skip promoted/ads and "who to follow".

== STAGE 2: JUDGE ==
For every newly captured post, look up the author in the people context for
role_org + notes (entity-context), then apply the rubric to assign
label = SIG | INSIG | SKIP and a <=12-word reason.

== STAGE 3: PERSIST + REPORT ==
A) Write ALL newly captured posts (every label) to "$RAWFILE" as JSONL — one JSON
   object per line, no array wrapper. Each object MUST have keys:
   id, platform ("x"), handle, author, date, type, text, links (array),
   engagement (object), thread_ids (array, may be empty), label, reason,
   scraped_at ("$STAMP").
B) Write the human digest to "$DIGEST" (Markdown). Structure:
   - Title: "# X digest — $DATE" and a one-line header with counts
     (new posts captured, significant count, people covered).
   - Then ONE section PER PERSON who had >=1 new SIG post:
       "## <Author> (@<handle>)"
       a synthesized 2-4 sentence summary of *what that person is doing/thinking*
       right now, rolled up across their significant posts (NOT one blurb per post),
       followed by a line "_sources: <dates/ids or short refs>_".
     Omit people with no new significant posts.
   - End with a short footer: people scanned with nothing significant, and any
     logged-out/empty handles.

When done, print a one-line summary: per handle, how many new posts captured and
how many were significant.
EOF
)

claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --mcp-config "$DIR/.mcp.json" \
  --allowedTools "mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__evaluate_script,mcp__chrome-devtools__click,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__new_page,Read,Write" \
  2>&1 | tee "$DIGEST_DIR/run-$RUNID.log"

echo ">> Done. Digest: $DIGEST   Raw: $RAWFILE"
