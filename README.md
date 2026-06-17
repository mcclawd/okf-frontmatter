# okf-frontmatter

A [Claude Code](https://claude.com/claude-code) **skill** for maintaining a repo's docs under
the [Open Knowledge Format (OKF)](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing/)
— and for finding the *authoritative* doc/schema fast, instead of grepping through thousands
of lines of prose.

Two jobs:

1. **Maintain docs the OKF way.** Every doc carries a small YAML frontmatter block as the
   single source of truth (`type`, `title`, `tags`, `intent`, `schema_source`, `documents`).
   Schema detail *links to the code* (`schema_source: file.py:Symbol`) instead of being copied
   into prose — so docs stop drifting and stop ballooning to thousand-line markdown.
2. **Look docs up fast** (`find_docs.py`). Given a code symbol, an API endpoint, a config key,
   or a keyword, it ranks the doc that *owns* the topic by frontmatter intent — and can resolve
   a doc's `schema_source` straight to the code, skipping the prose entirely.

The lookup is deliberately **grep-first**: the script is the *fallback* for when grep is
ambiguous, not a replacement for it (see [the strategy](references/lookup-strategy.md)).

---

## Does it actually help? (clean-room benchmark)

The honest answer: **yes for structured/ambiguous lookups, neutral for clean keyword hits.**
We measured it instead of guessing.

**Method.** 8 fresh subagents with **no shared context**, same model (Claude Sonnet 4.6),
read-only, each pinned to one repo checkout. Identical questions asked against two states of
the [openInvest](https://github.com/longsizhuo/openInvest) repo:

- **baseline** — `main` checkout: monolithic prose docs, no frontmatter, no skill (grep + read only).
- **current** — same docs with OKF frontmatter added + this skill available.

Both conditions reached the **same, correct answer** every time — so this is "same answer,
who's cheaper," not a quality trade-off. Metrics are each subagent's reported tool-call count,
tokens, and wall-clock.

| Task | tool calls | wall-clock | tokens | what happened |
|---|---|---|---|---|
| **T1** — "fields of the `GET /api/holdings` response + authoritative definition" | **7 → 3** (−57%) | 26.1s → 19.0s (−27%) | 24.9k → 23.8k (−5%) | OKF's sweet spot: `find` → `schema` jumps straight to `HoldingsListResponse` in code. |
| **T2** — "which config keys are settable at runtime via the API?" | **7 → 6** (−14%) | 27.0s → 23.5s (−13%) | **40.0k → 29.6k (−26%)** | `schema` prints the `API_SETTABLE` whitelist directly → much less reading. |
| **T3** — "why was the Claude Agent SDK not adopted?" | **2 → 2** (0%) | 23.2s → 21.0s (−9%) | 31.8k → 24.1k (−24%) | **The boundary, shown honestly:** `Agent SDK` is a clean keyword — grep nails ADR-002 in one shot, so the script can't cut calls. |

**Read-out:**

- **Tool calls** is the robust signal (independent of run-to-run variance and parallelism).
  Structured queries (T1/T2) drop calls; a clean keyword hit (T3) ties — because grep is
  *already* optimal there, and the skill says so: use grep first.
- **Token savings** come mainly from `schema` resolving a pointer to the exact code definition,
  so the agent never reads the big prose doc. (Note: these docs are still monolithic — frontmatter
  alone doesn't shrink reads; splitting docs into per-topic files is a separate, larger lever.)
- **Wall-clock** is shown for completeness but is the noisiest metric (agents ran concurrently).

> The takeaway isn't "the script is always faster." On an easy literal query, calling the script
> is pure overhead. The win is that on *ambiguous* queries it roughly halves the calls — and you
> only get that by **not** reaching for it on the easy ones.

---

## Quickstart

No dependencies — pure Python stdlib (uses PyYAML automatically if present, otherwise a built-in
minimal frontmatter parser).

```bash
git clone https://github.com/longsizhuo/okf-frontmatter.git

# run from inside the repo you want to query (auto-detects docs/wiki), or pass --repo:
python3 okf-frontmatter/scripts/find_docs.py --repo /path/to/your/repo lint

# locate the doc that owns a symbol / endpoint / config key
./scripts/run.sh find PortfolioResponse
./scripts/run.sh find "GET /api/holdings"
./scripts/run.sh find verdict.risk_profile

# resolve a doc's schema_source straight to the code definition
./scripts/run.sh schema docs/wiki/06-api.md

# scaffold frontmatter for a new doc
./scripts/run.sh new adr 018-some-decision

# OKF compliance + drift check (broken links / dangling schema_source / missing type)
./scripts/run.sh lint --ci
```

### As a Claude Code skill
Symlink (or copy) this repo into your skills dir so the agent auto-loads `SKILL.md`:

```bash
ln -s "$(pwd)/okf-frontmatter" ~/.claude/skills/okf-frontmatter
```

The agent then follows the grep-first / script-fallback strategy described in `SKILL.md`.

---

## Commands

| command | what it does |
|---|---|
| `find <query>` | symbol / `GET /api/x` / `a.b.config_key` / intent / keyword → ranked owning docs (JSON, strongest match first) |
| `schema <doc>` | resolve a doc's `schema_source` and print the real code definitions (via `ast`) |
| `index [--cache]` | dump the whole frontmatter index as JSON (`--cache` writes `docs/.okf-index.json`) |
| `lint [--ci]` | OKF compliance + drift; `--ci` exits non-zero only on errors (un-migrated docs are info, never a failure) |
| `new <type> <name>` | print a frontmatter skeleton |

## Frontmatter schema

```yaml
---
type: wiki-chapter        # REQUIRED. wiki-chapter|adr|index|reference|report|readme
title: Web API Reference
tags: [api, rest]
intent: API Contract      # one short phrase the lookup ranks on
schema_source:            # pointers to the authoritative code (verified by `lint`)
  - connectors/web_api/models.py:PortfolioResponse
documents:                # concrete handles a reader searches for
  endpoints: [GET /api/holdings]
  config_keys: [verdict.risk_profile]
  symbols: [PortfolioManager]
---
```

ADRs add a lifecycle block (`status`, `date`, `supersedes`, `superseded_by`). Full details:
[`references/conventions.md`](references/conventions.md). What OKF is:
[`references/okf-spec.md`](references/okf-spec.md).

## Layout
```
SKILL.md                       agent-facing guide (the two jobs + the lookup decision tree)
scripts/find_docs.py           stdlib engine: index | find | schema | lint | new
scripts/run.sh                 thin wrapper
references/okf-spec.md          what OKF is (1 page)
references/conventions.md       the frontmatter schema + maintenance rules
references/lookup-strategy.md   grep-first / script-fallback decision tree + this benchmark
```

## License
MIT — see [LICENSE](LICENSE).
