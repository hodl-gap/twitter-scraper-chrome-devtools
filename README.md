# twitter-scraper-chrome-devtools

An **unattended X/Twitter activity reader** — the sibling of `linkedin-scraper`,
same mechanism, X-adapted. You log into X once; an agent does the scrolling and
reading for you.

It drives a **real, logged-in X session** via the
[`chrome-devtools` MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp)
with a headless `claude -p` agent that opens each handle's profile timeline,
scrolls, reads the posts, and writes a dated markdown digest.

## Why chrome-devtools and not the old Playwright scraper

The point is **engagement, not just scraping.** A read-only scraper (like the
old `twitter_scraper/` Playwright project) can pull text but can't act on your
behalf. This tool uses your logged-in browser session, so the same pipeline can
later **like and follow** posts/authors to tune your For-You feed for discovery
— which is the whole reason to build it. Pure scraping would be futile for that
goal.

(Reading-only today; like/follow is the planned next step, mirroring
`linkedin-scraper`.)

## Prerequisites

- **WSL2 + Linux Google Chrome** at `/usr/bin/google-chrome-stable`, rendered
  via WSLg. The `--ozone-platform=wayland` flag is **mandatory** (headed Chrome
  crashes with SIGTRAP on the X11 path). Already encoded in `.mcp.json`.
- **Claude Code CLI** (`claude`) on PATH.
- **One-time X login.** Open the chrome-devtools Chrome once, log into X. The
  session persists in the profile dir
  (`~/.cache/chrome-devtools-mcp/chrome-profile`) across runs. This profile is
  shared with `linkedin-scraper`, so logging into both is fine.
- Only **one Chrome at a time** may hold that profile dir. Don't run this while
  another Claude session (or the LinkedIn scanner) is actively driving the same
  browser. Close the other first, or `pkill -f '/opt/google/chrome/chrome'`.

## Usage

```bash
./scan-twitter.sh                      # read handles.txt, up to 20 posts each
./scan-twitter.sh -n 30                # up to 30 posts per handle
./scan-twitter.sh karpathy dwarkesh_sp # ad-hoc handles (@ optional)
./scan-twitter.sh -f my-list.txt       # a different handle list
```

Edit `handles.txt` to set who to watch (one handle per line; `#` comments OK).
Output lands in `output/twitter-digest-YYYY-MM-DD.md` (git-ignored), with a run
log alongside it.

## Scheduling (optional, fully hands-off)

```cron
0 9 * * 1-5  cd /path/to/twitter-scraper-chrome-devtools && ./scan-twitter.sh >> output/cron.log 2>&1
```

Caveat: if X logs you out or throws a checkpoint mid-run, an unattended run has
no human to clear it and will fail — just re-login. Keep the cadence gentle to
avoid tripping anti-automation.

## Notes / gotchas

- X is a heavy SPA: `navigate_page` often **reports a timeout even though the
  page loaded**, and posts stream in after load — the agent is told to ignore
  the timeout and scroll to load more.
- The timeline is **virtualised**: posts are recycled out of the DOM as you
  scroll, so the agent reads each snapshot as it goes rather than expecting all
  posts in one final snapshot.
- Do **not** pass `--viewport` to the MCP (drops the connection on maximized
  WSLg windows); window size is set via `--chromeArg=--window-size`.
- Handles in `handles.txt` are best-guess seeds — verify before relying on them.
- Respect X's Terms of Service. This reads what you can already see when logged
  in; use it for personal research, at a human pace.
