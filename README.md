<div align="center">

# okf-frontmatter

**Keep a repo's Markdown docs under the Open Knowledge Format — and find the right doc/schema fast.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![OKF BundleDex](https://bundledex.net/static-badge.svg)](https://bundledex.net)
&nbsp;·&nbsp; pure-Python stdlib &nbsp;·&nbsp; portable agent skill — Claude Code / Codex / any

</div>

---

## Table of contents

- [What it is](#what-it-is)
- [Install](#install)
  - [Claude Code](#claude-code)
  - [Codex](#codex)
  - [Any other agent](#any-other-agent)
- [Background](#background)
- [Does it actually help? I measured it.](#does-it-actually-help-i-measured-it)
- [CLI usage](#cli-usage)
- [Commands](#commands)
- [Frontmatter schema](#frontmatter-schema)
- [Layout](#layout)
- [License](#license)

---

## What it is

**okf-frontmatter** is a portable agent skill: just a `SKILL.md` plus a small script, so any
agent that loads skills can pick it up (or you can run it as a plain CLI). It does two things.

**Keeps docs in OKF shape.** Each doc opens with a little YAML frontmatter — `type`, `title`,
`tags`, `intent`, `schema_source`, `documents`. The parts that *are* code — models, config
keys, endpoints — get a `schema_source: file.py:Symbol` pointer instead of being retyped into
prose. So docs stop drifting from the code and stop ballooning into thousand-line walls.

**Finds the right doc fast.** Hand `find_docs.py` a symbol, an endpoint, a config key, or just
a keyword, and it ranks the doc that actually *owns* the topic (by frontmatter intent). `schema
<doc>` goes one step further and resolves those pointers straight to the code, so the agent
reads the authoritative definition without opening the prose at all.

One thing I want to be straight about: this is **grep-first**. The script isn't a replacement
for grep — it's what you reach for when grep is ambiguous (hits scattered across files, a
synonym mismatch, or nothing at all). On a clean literal hit, plain grep is already the best
move, and the skill tells the agent exactly that. The
[full strategy is here](references/lookup-strategy.md).

---

## Install

No dependencies — pure Python stdlib. It'll use PyYAML if you happen to have it, otherwise a
tiny built-in frontmatter parser kicks in. Pick the install that matches your agent.

### Claude Code

The repo ships a `.claude-plugin/plugin.json` manifest, so it loads as a first-class plugin (not
just a loose skill). Clone into the skills dir; it auto-loads next session as
`okf-frontmatter@skills-dir`:

```bash
git clone https://github.com/longsizhuo/okf-frontmatter.git ~/.claude/skills/okf-frontmatter
# then in a session: /reload-plugins   (or restart Claude Code)
```

### Codex

Codex skills are plain folders under `$CODEX_HOME/skills/`; the same `SKILL.md` works as-is
(no manifest needed, Codex ignores `.claude-plugin/`):

```bash
git clone https://github.com/longsizhuo/okf-frontmatter.git ~/.codex/skills/okf-frontmatter
# picked up on the next Codex session
```

### Any other agent

Works on Cursor, Cline, Gemini CLI, OpenClaw, and the rest — drop it wherever that agent looks
for skills, or just clone it anywhere and call the script directly:

```bash
git clone https://github.com/longsizhuo/okf-frontmatter.git
ln -s "$(pwd)/okf-frontmatter" ~/.claude/skills/okf-frontmatter   # or wherever your agent looks
```

Once it's loaded, the agent follows the grep-first / script-fallback flow from `SKILL.md`. Don't
use a skill runner? Just call `scripts/run.sh` (or `find_docs.py`) from anywhere — it's the same
tool. See [CLI usage](#cli-usage) below.

---

## Background

I let my coding agents maintain the docs — wikis, design notes, postmortems. That's lovely for
the docs and rough on the agent: a repo slowly grows to dozens, sometimes hundreds, of markdown
files, and every "where's the doc about X?" turns into grepping thousands of lines and a few
rounds of `find`. Slow, and a quiet token sink. I looked at standing up RAG for it and it felt
like a cannon to swat a fly. 🦟

Then a colleague pointed me at Google's
[Open Knowledge Format (OKF)](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing/):
give each doc a small structured frontmatter block as its single source of truth, and link the
code-ish details to the code instead of copying them into prose. The thing that clicked for me
was that the same frontmatter makes a great *index* — so I built this.

---

## Does it actually help? I measured it.

Short version: **yes for structured or ambiguous lookups, a wash for clean keyword hits** — and
I'd rather show you the wash than bury it.

The setup: 8 fresh agents, no shared context, the same LLM on both sides (Claude Sonnet 4.6),
read-only, each pinned to one checkout of [openInvest](https://github.com/longsizhuo/openInvest).
Same questions, two states of the repo:

- **baseline** — plain `main`: monolithic docs, no frontmatter, no skill. grep + read only.
- **current** — the same docs with OKF frontmatter, skill available.

Both sides reached the **same correct answer every time**, so this is "same answer, who's
cheaper," not a quality trade-off. The numbers are each agent's own tool-call count, tokens, and
wall-clock.

| Task                                                                             | tool calls       | wall-clock           | tokens                   | what happened                                                                                                            |
| -------------------------------------------------------------------------------- | ---------------- | -------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| **T1** — "fields of the `GET /api/holdings` response + authoritative definition" | **7 → 3** (−57%) | 26.1s → 19.0s (−27%) | 24.9k → 23.8k (−5%)      | OKF's sweet spot: `find` → `schema` jumps straight to `HoldingsListResponse` in code.                                    |
| **T2** — "which config keys are settable at runtime via the API?"                | **7 → 6** (−14%) | 27.0s → 23.5s (−13%) | **40.0k → 29.6k (−26%)** | `schema` prints the `API_SETTABLE` whitelist directly → much less reading.                                               |
| **T3** — "why was the Claude Agent SDK not adopted?"                             | **2 → 2** (0%)   | 23.2s → 21.0s (−9%)  | 31.8k → 24.1k (−24%)     | The honest boundary: `Agent SDK` is a clean keyword, so grep nails the ADR in one shot and the script can't save a call. |

How I read it:

- **Tool calls** is the number I trust most — it doesn't wobble with run-to-run variance.
  Structured queries shed calls; the clean keyword hit ties, exactly because grep already wins
  there.
- **Tokens** mostly drop when `schema` resolves a pointer to the code and the agent skips the
  big prose doc. (These docs are still monolithic, so frontmatter alone doesn't shrink a read —
  splitting docs into per-topic files is a separate, bigger lever I haven't pulled here.)
- **Wall-clock** is here for completeness; it's the noisiest row, since the agents ran in
  parallel.

> The point was never "the script is always faster." On an easy query, calling it is pure
> overhead. The win is that on the *ambiguous* ones it roughly halves the calls — and you only
> get that by not reaching for it on the easy ones.

---

## CLI usage

```bash
# run from inside the repo you want to query (it auto-detects docs/wiki), or pass --repo:
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

---

## Commands

| command             | what it does                                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------------------------------- |
| `find <query>`      | symbol / `GET /api/x` / `a.b.config_key` / intent / keyword → ranked owning docs (JSON, strongest match first) |
| `schema <doc>`      | resolve a doc's `schema_source` and print the real code definitions (via `ast`)                                |
| `index [--cache]`   | dump the whole frontmatter index as JSON (`--cache` writes `docs/.okf-index.json`)                             |
| `lint [--ci]`       | OKF compliance + drift; `--ci` exits non-zero only on errors (un-migrated docs are info, never a failure)      |
| `new <type> <name>` | print a frontmatter skeleton                                                                                   |

---

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

ADRs add a lifecycle block (`status`, `date`, `supersedes`, `superseded_by`). The full schema +
rules live in [`references/conventions.md`](references/conventions.md); a one-page take on what
OKF is in [`references/okf-spec.md`](references/okf-spec.md).

---

## Layout

```
.claude-plugin/plugin.json     Claude Code plugin manifest (lets it load as a plugin, not just a skill)
SKILL.md                       the skill itself (the two jobs + the lookup decision tree)
scripts/find_docs.py           stdlib engine: index | find | schema | lint | new
scripts/run.sh                 thin wrapper
references/okf-spec.md          what OKF is (1 page)
references/conventions.md       the frontmatter schema + maintenance rules
references/lookup-strategy.md   grep-first / script-fallback decision tree + this benchmark
```

---

## License

MIT — see [LICENSE](LICENSE).
