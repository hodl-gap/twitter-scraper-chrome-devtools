#!/usr/bin/env bash
#
# scan-twitter.sh — unattended X/Twitter activity reader.
#
# Drives a logged-in X session (via the chrome-devtools MCP) with a headless
# `claude -p` agent. For each handle it opens the user's profile timeline,
# scrolls to load posts, reads them, and writes a dated markdown digest.
#
# Sibling of linkedin-scraper. Same mechanism, X-adapted. The point of using
# the logged-in browser (vs. the old read-only Playwright scraper) is that the
# SAME session can later LIKE and FOLLOW to tune your For-You algorithm.
#
# Usage:
#   ./scan-twitter.sh                 # read handles.txt, default 20 posts
#   ./scan-twitter.sh -n 30           # up to 30 posts per handle
#   ./scan-twitter.sh karpathy dwarkesh_sp   # ad-hoc handles (with or without @)
#   ./scan-twitter.sh -f my-list.txt  # a different handle list
#
# Prereqs (see README.md):
#   - chrome-devtools MCP configured (see .mcp.json)
#   - You have logged into X ONCE in that Chrome profile
#   - No other Chrome is holding the profile dir (only one at a time)
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

NPOSTS=20
HANDLES_FILE="handles.txt"
OUTDIR="output"
HANDLES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) NPOSTS="$2"; shift 2 ;;
    -f) HANDLES_FILE="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) HANDLES+=("${1#@}"); shift ;;   # strip a leading @ if present
  esac
done

# Build the handle list: explicit args win, else read the file (skip blanks/#).
if [[ ${#HANDLES[@]} -eq 0 ]]; then
  [[ -f "$HANDLES_FILE" ]] || { echo "No handles file: $HANDLES_FILE" >&2; exit 1; }
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs)"; line="${line#@}"
    [[ -n "$line" ]] && HANDLES+=("$line")
  done < "$HANDLES_FILE"
fi
[[ ${#HANDLES[@]} -gt 0 ]] || { echo "No handles to scan." >&2; exit 1; }

mkdir -p "$OUTDIR"
DATE="$(date +%Y-%m-%d)"
STAMP="$(date '+%Y-%m-%d %H:%M %Z')"
OUTFILE="$OUTDIR/twitter-digest-$DATE.md"
HANDLE_LINES="$(printf '  - @%s\n' "${HANDLES[@]}")"

echo ">> Scanning ${#HANDLES[@]} handle(s), up to $NPOSTS posts each."
echo ">> Output -> $OUTFILE"

PROMPT=$(cat <<EOF
You are reading X (Twitter) on the owner's behalf using the chrome-devtools MCP
tools. The browser is already logged in. Work slowly and human-paced; do NOT
hammer the site.

For EACH of these handles:
$HANDLE_LINES

Do the following, one handle at a time:
1. Navigate to "https://x.com/<handle>" (their profile timeline) using
   mcp__chrome-devtools__navigate_page with a generous timeout (e.g. 60000).
   X is a heavy SPA: navigate_page often REPORTS a timeout even though the page
   actually loaded, and content streams in after load. If it reports a timeout,
   ignore it and proceed. If you land on a login wall, record that the session
   is logged out and STOP (do not attempt to log in).
2. Take a mcp__chrome-devtools__take_snapshot. To load more than the first few
   posts, use mcp__chrome-devtools__evaluate_script to scroll
   (window.scrollTo(0, document.body.scrollHeight)) several times with short
   pauses, taking a fresh snapshot, until about $NPOSTS posts are visible or no
   new ones load. (X virtualises the timeline — read posts from each snapshot as
   you scroll; don't expect them all in one final snapshot.)
3. Extract each ORIGINAL post or repost by that account: the timestamp/relative
   age, the full verbatim text, reply/repost/like/view counts if visible, a
   note if it has media (image/video) or links, and whether it's a reply or a
   repost of someone else. Skip promoted/ads and "Who to follow".

Then APPEND a section per handle to the file "$OUTFILE" using the Write tool
(read it first if it already exists so you append rather than overwrite). Format:

  ## @<handle> — <display name>
  _scanned ${STAMP}_

  ### <relative age> — <one-line summary>
  <full verbatim post text>
  > replies: N · reposts: N · likes: N · views: N
  > media: yes/no · links: <urls if any> · reply/repost: <if applicable>

Keep the original language of each post (do not translate). Be faithful and
verbatim. When done, print a one-line summary of how many posts you captured
per handle, and flag any handle whose timeline was empty or logged-out.
EOF
)

claude -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --mcp-config "$DIR/.mcp.json" \
  --allowedTools "mcp__chrome-devtools__navigate_page,mcp__chrome-devtools__take_snapshot,mcp__chrome-devtools__evaluate_script,mcp__chrome-devtools__list_pages,mcp__chrome-devtools__new_page,Read,Write" \
  2>&1 | tee "$OUTDIR/run-$DATE.log"

echo ">> Done. Digest at $OUTFILE"
