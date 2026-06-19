#!/usr/bin/env bash
#
# scan-twitter.sh — significance-filtered X monitor + engagement + people-db grow.
#
#   CAPTURE -> JUDGE -> (ENGAGE) -> PERSIST + REPORT -> GROW people-db
#
# Watchlist == people-db (policy D): with no args, scans every person in
# people-db that has an X handle (status active|dormant|unknown). Discovered
# reshared authors are written back to people-db, so they're scanned next run.
#
# Engagement OFF unless --engage; --dry-run logs intended like/follow without
# clicking. people-db is grown every run (independent of engagement).
#
# Usage:
#   ./scan-twitter.sh                       # watchlist from people-db, monitor only
#   ./scan-twitter.sh karpathy bcherny      # ad-hoc handles override
#   ./scan-twitter.sh --engage --dry-run    # log intended like/follow
#   ./scan-twitter.sh --engage              # LIVE like/follow on SIG
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

NPOSTS=15; HANDLES_FILE="handles.txt"
PEOPLE_DB="${PEOPLE_DB:-$DIR/../people-db/people.json}"
RUBRIC="${RUBRIC:-$DIR/../people-db/judge_prompt.md}"
PDB_DIR="$(dirname "$PEOPLE_DB")"
LIST_TOOL="$PDB_DIR/tools/list_watchlist.py"; UPDATE_TOOL="$PDB_DIR/tools/update_people_db.py"
STORE_DIR="$DIR/store/raw"; ACT_DIR="$DIR/store/actions"; DISC_DIR="$DIR/store/discoveries"; DIGEST_DIR="$DIR/digests"
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
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) HANDLES+=("${1#@}"); shift ;;
  esac
done

# Watchlist: explicit args win; else derive from people-db (policy D); else handles.txt.
if [[ ${#HANDLES[@]} -eq 0 ]]; then
  if [[ -f "$PEOPLE_DB" && -f "$LIST_TOOL" ]]; then
    while IFS= read -r h; do [[ -n "$h" ]] && HANDLES+=("${h#@}"); done \
      < <(python3 "$LIST_TOOL" --people "$PEOPLE_DB" --platform x)
    echo ">> Watchlist from people-db: ${#HANDLES[@]} handle(s)."
  elif [[ -f "$HANDLES_FILE" ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"; line="$(echo "$line" | xargs)"; line="${line#@}"
      [[ -n "$line" ]] && HANDLES+=("$line")
    done < "$HANDLES_FILE"
  fi
fi
[[ ${#HANDLES[@]} -gt 0 ]] || { echo "No handles to scan." >&2; exit 1; }

mkdir -p "$STORE_DIR" "$ACT_DIR" "$DISC_DIR" "$DIGEST_DIR"
[[ -f "$RUBRIC" ]] || { echo "Missing rubric: $RUBRIC" >&2; exit 1; }
[[ -f "$PEOPLE_DB" ]] || echo "WARN: people-db not found at $PEOPLE_DB (entity-context degraded)" >&2

DATE="$(date +%Y-%m-%d)"; RUNID="$(date +%Y%m%d-%H%M%S)"; STAMP="$(date '+%Y-%m-%d %H:%M %Z')"
RAWFILE="$STORE_DIR/twitter-$RUNID.jsonl"
DIGEST="$DIGEST_DIR/twitter-$DATE.md"
SEEN="$STORE_DIR/.seen_ids.txt"
ACTFILE="$ACT_DIR/twitter-$RUNID.jsonl"
DISCFILE="$DISC_DIR/twitter-$RUNID.jsonl"

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
echo ">> Raw: $RAWFILE  Digest: $DIGEST  Disc: $DISCFILE"

PROMPT=$(cat <<EOF
You are an unattended X/Twitter intelligence agent using the chrome-devtools MCP
tools (browser already logged in). Goal: surface what AI leaders are doing/thinking.
Work human-paced. Stages: CAPTURE -> JUDGE -> ENGAGE (inline) -> PERSIST + REPORT.

CAPS ARE CEILINGS, NOT TARGETS: stop as soon as you are caught up (you reach
already-seen content) or run out of genuinely new material — whichever comes
before the cap. Never scroll/dig/reach to fill a cap; an empty or near-empty run
is correct when little is new (e.g. a handle with no new posts: capture nothing, move on).

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
capture the whole chain as one item. Capture per post: stable id (status permalink;
else "<handle>:<date>:<first40>"), author, date, type, verbatim text (expand
"Show more"), links, engagement counts, and — if it is a reshare/quote — the
ORIGINAL author's handle + display name. Skip ads/"who to follow".

== JUDGE ==
For each new post, use the entity-context, then apply the rubric -> label
(SIG|INSIG|SKIP) + <=12-word reason.

== ENGAGE (mode: $ENGAGE_DESC) ==
Inline — act the moment you judge a post SIG. Caps: max $MAXL likes, max $MAXF follows.
- If mode is OFF: do nothing here.
- Else for each SIG post: LIKE it (skip if already liked); FOLLOW its author if not
  already following, and if it reshares/quotes a DIFFERENT account, also FOLLOW that
  original author if new. FOLLOW only PEOPLE — never follow org/product/company accounts
  (e.g. @OpenAI, @claudeai): like their posts, but do not follow them. Respect caps.
  If DRY-RUN: record only, do NOT click.
  Append each action to "$ACTFILE" as JSONL:
  {"action":"like"|"follow","post_id":"...","target":"@handle/url","author":"...","dry_run":$( [[ $DRYRUN -eq 1 ]] && echo true || echo false ),"ts":"$STAMP"}
  Never like/follow INSIG or SKIP.

== PERSIST + REPORT + DISCOVER ==
A) Write ALL new posts (every label) to "$RAWFILE" as JSONL, keys: id, platform
   ("x"), handle, author, date, type, text, links[], engagement{}, thread_ids[],
   label, reason, scraped_at ("$STAMP").
B) DISCOVERIES (always, regardless of engagement): for each SIG post that
   reshares/quotes an author who is NOT one of the scanned handles above, append
   to "$DISCFILE" a JSONL record:
   {"platform":"x","handle":"<handle>","name":"<display name>","kind":"person"|"organization","role_org":"<short affiliation if visible>"}
   Mark company/product accounts (e.g. @OpenAI, @claudeai) as kind "organization".
C) Write digest to "$DIGEST": "# X digest — $DATE" + one-line counts; then one
   "## <Author> (@handle)" section PER PERSON with >=1 new SIG post — a synthesized
   2-4 sentence summary of what they're doing/thinking (rolled up, NOT per-post) +
   "_sources: ..._". Omit people with nothing significant. Footer: nothing-significant
   handles, logged-out/empty handles, engagement summary, and discovered authors.

Finally print one line per handle: new captured / significant / engaged counts.
EOF
)

claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --mcp-config "$DIR/.mcp.json" \
  --allowedTools "mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__evaluate_script,mcp__chrome-devtools__click,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__new_page,Read,Write" \
  2>&1 | tee "$DIGEST_DIR/run-$RUNID.log"

# GROW people-db from this run (refresh scanned; add discovered people). Working
# copy only — review/commit the people-db repo separately.
if [[ -f "$PEOPLE_DB" && -f "$UPDATE_TOOL" ]]; then
  echo ">> Updating people-db..."
  python3 "$UPDATE_TOOL" --people "$PEOPLE_DB" --platform x --today "$DATE" --raw "$RAWFILE" --disc "$DISCFILE" || echo "WARN: people-db update failed" >&2
fi

echo ">> Done. Digest: $DIGEST  Raw: $RAWFILE  Actions: $ACTFILE (engagement: $ENGAGE_DESC)"
