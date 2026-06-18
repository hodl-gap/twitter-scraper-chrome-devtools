#!/usr/bin/env bash
#
# scan-twitter.sh — significance-filtered X/Twitter monitor + engagement (M1+M2).
#
#   CAPTURE -> JUDGE -> (ENGAGE) -> PERSIST + REPORT
#
# CAPTURE  incremental (dedup vs raw store) + thread-expand.
# JUDGE    SIG/INSIG/SKIP via shared rubric + people-db entity-context.
# ENGAGE   (opt-in) on SIG posts: like the post + follow its author (incl. the
#          original author of a reshared/quoted SIG post). One bar: SIG = like+follow.
# REPORT   one synthesized summary PER PERSON of significant activity.
#
# Engagement is OFF unless --engage. Use --dry-run the first time (logs intended
# actions, no clicks). Caps + idempotency + an action log keep it safe.
#
# Usage:
#   ./scan-twitter.sh                              # monitor only (no engagement)
#   ./scan-twitter.sh karpathy bcherny             # ad-hoc handles
#   ./scan-twitter.sh --engage --dry-run           # log what it WOULD like/follow
#   ./scan-twitter.sh --engage                     # LIVE like/follow on SIG
#   ./scan-twitter.sh --engage --max-likes 20 --max-follows 8
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

NPOSTS=15; HANDLES_FILE="handles.txt"
PEOPLE_DB="${PEOPLE_DB:-$DIR/../people-db/people.json}"
RUBRIC="${RUBRIC:-$DIR/../people-db/judge_prompt.md}"
STORE_DIR="$DIR/store/raw"; ACT_DIR="$DIR/store/actions"; DIGEST_DIR="$DIR/digests"
ENGAGE=0; DRYRUN=0; MAXL=25; MAXF=12
HANDLES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NPOSTS="$2"; shift 2 ;;
    -f) HANDLES_FILE="$2"; shift 2 ;;
    --engage) ENGAGE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    --max-likes) MAXL="$2"; shift 2 ;;
    --max-follows) MAXF="$2"; shift 2 ;;
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
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

mkdir -p "$STORE_DIR" "$ACT_DIR" "$DIGEST_DIR"
[[ -f "$RUBRIC" ]] || { echo "Missing rubric: $RUBRIC" >&2; exit 1; }
[[ -f "$PEOPLE_DB" ]] || echo "WARN: people-db not found at $PEOPLE_DB (entity-context degraded)" >&2

DATE="$(date +%Y-%m-%d)"; RUNID="$(date +%Y%m%d-%H%M%S)"; STAMP="$(date '+%Y-%m-%d %H:%M %Z')"
RAWFILE="$STORE_DIR/twitter-$RUNID.jsonl"
DIGEST="$DIGEST_DIR/twitter-$DATE.md"
SEEN="$STORE_DIR/.seen_ids.txt"
ACTFILE="$ACT_DIR/twitter-$RUNID.jsonl"

if   [[ $ENGAGE -eq 0 ]]; then ENGAGE_DESC="OFF"
elif [[ $DRYRUN -eq 1 ]]; then ENGAGE_DESC="DRY-RUN (record intended actions only, NO clicks)"
else ENGAGE_DESC="LIVE (actually like + follow)"; fi

python3 - "$STORE_DIR" > "$SEEN" <<'PY'
import sys, glob, json, os
seen=set()
for fp in glob.glob(os.path.join(sys.argv[1],"twitter-*.jsonl")):
    for line in open(fp,encoding="utf-8"):
        line=line.strip()
        if not line: continue
        try: seen.add(json.loads(line)["id"])
        except Exception: pass
print("\n".join(sorted(seen)))
PY
SEEN_COUNT=$(grep -c . "$SEEN" || true)
HANDLE_LINES="$(printf '  - @%s\n' "${HANDLES[@]}")"
echo ">> Scanning ${#HANDLES[@]} handle(s); $NPOSTS new/handle; $SEEN_COUNT seen; engagement: $ENGAGE_DESC"
echo ">> Raw: $RAWFILE  Digest: $DIGEST  Actions: $ACTFILE"

PROMPT=$(cat <<EOF
You are an unattended X/Twitter intelligence agent using the chrome-devtools MCP
tools (browser already logged in). Goal: surface what AI leaders are doing/thinking.
Work human-paced. Stages: CAPTURE -> JUDGE -> ENGAGE (inline) -> PERSIST + REPORT.

Read first (Read tool):
- Rubric: $RUBRIC  (apply exactly, incl. edge-case tie-breakers)
- People/entity context: $PEOPLE_DB  (match author for role_org + notes)
- Already-seen ids (DO NOT re-capture): $SEEN

Handles:
$HANDLE_LINES

== CAPTURE (incremental) ==
For each handle, navigate https://x.com/<handle> (timeout 60000; a reported
timeout is usually false — snapshot anyway; login wall -> record logged-out, skip).
Read newest downward; STOP at a seen id or after ~$NPOSTS new posts. Timeline is
virtualised — read each snapshot as you scroll. Expand self-reply THREADS and
capture the whole chain as one item. Capture per post: stable id (status
permalink; else "<handle>:<date>:<first40>"), author, date, type, verbatim text
(expand "Show more"), links, engagement counts. Skip ads/"who to follow".

== JUDGE ==
For each new post, use the entity-context, then apply the rubric -> label
(SIG|INSIG|SKIP) + <=12-word reason.

== ENGAGE (mode: $ENGAGE_DESC) ==
Do this INLINE — the moment you judge a post SIG, act while it's on screen
(before scrolling past). Caps this run: max $MAXL likes, max $MAXF follows.
- If mode is OFF: do nothing here; never like or follow.
- Otherwise, for each SIG post:
  * LIKE the post (its Like control). Skip if already liked.
  * FOLLOW its author if not already following. If the SIG post is a
    reshare/quote of a DIFFERENT account, also FOLLOW that original author if not
    already following.
  * Respect caps; once a cap is hit, stop that action type and note it.
  * If mode is DRY-RUN: DO NOT click anything — only record what you WOULD do.
  * Append each action to "$ACTFILE" as JSONL:
    {"action":"like"|"follow","post_id":"...","target":"@handle or url","author":"...","dry_run":$( [[ $DRYRUN -eq 1 ]] && echo true || echo false ),"ts":"$STAMP"}
  Never like/follow INSIG or SKIP posts.

== PERSIST + REPORT ==
A) Write ALL new posts (every label) to "$RAWFILE" as JSONL, keys: id, platform
   ("x"), handle, author, date, type, text, links[], engagement{}, thread_ids[],
   label, reason, scraped_at ("$STAMP").
B) Write digest to "$DIGEST": "# X digest — $DATE" + one-line counts; then one
   "## <Author> (@handle)" section PER PERSON with >=1 new SIG post — a synthesized
   2-4 sentence summary of what they're doing/thinking (rolled up, NOT per-post) +
   "_sources: ..._". Omit people with nothing significant. Footer: nothing-significant
   handles, logged-out/empty handles, and engagement summary (likes/follows done or,
   in dry-run, intended).

Finally print one line per handle: new captured / significant / engaged counts.
EOF
)

claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --mcp-config "$DIR/.mcp.json" \
  --allowedTools "mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__evaluate_script,mcp__chrome-devtools__click,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__new_page,Read,Write" \
  2>&1 | tee "$DIGEST_DIR/run-$RUNID.log"

echo ">> Done. Digest: $DIGEST  Raw: $RAWFILE  Actions: $ACTFILE (engagement: $ENGAGE_DESC)"
