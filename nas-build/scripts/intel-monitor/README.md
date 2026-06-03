# Intel Monitor

Weekly digest of Hermes Agent releases, ecosystem activity, and adjacent AI-agent ideas.

## Streams

1. **Hermes Agent changes** — pulls the last 5 GitHub releases from `nousresearch/hermes-agent`
2. **Hermes in the wild** — Brave Search for community work referencing Hermes by name
3. **Adjacent ideas worth knowing** — Brave Search, topic-filtered to agent memory, self-improvement, skill frameworks, tool use, agentic workflows, prompt engineering, etc.

Streams 2 and 3 use the Brave Search API. The same `BRAVE_SEARCH_API_KEY` from `~/.hermes/.env` that the agent's web_search tool uses. Cost: ~32 queries/month on the free/credit tier.

## Schedule

Runs weekly via cron: `0 9 * * 1` (Mondays at 09:00 local).

## Output

Posts a digest to the "Felix Intel" Matrix room. Format:

```
📡 Weekly intel — YYYY-MM-DD

🔴 Hermes Agent changes (new):
  • v0.15.2 (2026.5.29.2)
    https://github.com/...
  • ...

🟡 Hermes in the wild (new since last week):
  • Title
    URL
  • ...

🔵 Adjacent ideas worth knowing (new):
  • Title
    URL
  • ...

Filters: stream 3 requires topic match (18 keywords) and excludes listicle titles.
```

When nothing new: `📡 Weekly intel — nothing new this week`

## Setup

The script is self-contained. Just needs:

1. `~/.hermes/.env` with `MATRIX_PASSWORD` and `BRAVE_SEARCH_API_KEY` (already present for the main Hermes agent)
2. The Matrix room ID (hardcoded in the script)
3. A cron entry — see the schedule section

## Tuning

- **Topic keywords** (`STREAM3_TOPIC_KEYWORDS`): add/remove topics based on what shows up in the digests. After a few weeks, you'll see what's hitting and what's missing.
- **Listicle patterns** (`LISTICLE_PATTERNS`): keep tightening these. New listicle formats appear all the time; update the patterns when the digests get spammy.
- **Query rotation** (`all_queries` in `search_adjacent`): currently rotates 4 of 8 queries per week. Add more queries to expand coverage, or reduce to keep the digest focused.

## State

The script maintains a state file at `/root/felix/intel-monitor/state.json` with the list of URLs/release tags already seen. It only announces NEW items. To reset (re-announce everything), delete the state file.

## Delivery

Uses the Matrix Client-Server API directly (login + PUT) instead of the `hermes send` CLI. Reason: the CLI has a bug with encrypted Conduit rooms — its bundled token doesn't have encryption keys for new rooms. Login per run is cheap (~1 HTTP call) and works around the bug.
