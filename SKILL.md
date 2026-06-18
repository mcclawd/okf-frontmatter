---
name: okf-frontmatter
version: 0.1.0
description: >-
  Maintain a repo's Markdown docs (wiki chapters, ADRs, references) under Google's
  Open Knowledge Format (OKF), and find the right doc/schema fast. Two jobs.
  (1) Maintain docs the OKF way — each doc carries a small YAML frontmatter block as
  the single source of truth (type, title, tags, intent, schema_source, documents);
  schema detail links to the authoritative code instead of being copied into prose,
  so docs stop drifting and stop ballooning into thousand-line Markdown.
  (2) Look docs up fast — grep the literal term FIRST; only when grep is ambiguous
  (hits scattered across files / synonym mismatch / zero hits) run find_docs.py to
  rank the doc that owns the topic by frontmatter intent, or resolve a doc's
  schema_source straight to the code. Trigger phrases — "which doc covers X",
  "find the schema this doc points to", "where is endpoint/config-key X documented",
  "add OKF frontmatter to this doc", "lint the docs", "scaffold a new ADR/chapter".
  Run: scripts/run.sh find|schema|index|lint|new (or python3 scripts/find_docs.py
  --repo <path> ...).
---

# okf-frontmatter

Your repo's Markdown docs (wiki chapters, ADRs, references) each start, under **OKF**, with a
YAML frontmatter block that is the *single source of truth* about that doc. Tooling reads the
frontmatter; humans read the prose. The goal: stop maintaining huge prose docs that duplicate
what the code already says — link to the code instead, and let `find_docs.py` do navigation.

Point the script at a repo with `--repo <path>`, or just run it from inside that repo (it
auto-detects the nearest ancestor containing `docs/wiki/`, else uses the working dir). It is
read-only except for docs you explicitly edit. The conventions below use openInvest as the
worked example, but the mechanics (`find` / `schema` / `lint`) work on any repo whose
markdown carries OKF frontmatter.

---

## Job 1 — maintain docs the OKF way

**The rule of thumb:** frontmatter is structured truth; prose is explanation. Anything that
*is* a schema (a Pydantic model, a dataclass, a config key, an endpoint contract) lives in
code — the doc **points** to it via `schema_source` / `documents`, it does not re-type it.
When the code changes, `lint` tells you which doc's pointer went stale. Don't grow a doc past
a few screens of "why / how it fits together"; if you're copying field tables out of code,
stop and add a `schema_source` pointer instead.

### Frontmatter schema

Common to every doc:

| field | required | meaning |
|---|---|---|
| `type` | ✅ | `wiki-chapter` \| `adr` \| `index` \| `reference` \| `report` \| `readme` |
| `title` | rec. | human title (usually the H1) |
| `tags` | opt. | `[api, rest, ...]` — coarse categories |
| `intent` | opt. | one short phrase the lookup ranks on, e.g. `API Contract`, `决策参数`, `部署` |
| `schema_source` | opt. | list of `relpath:Symbol` pointers to the authoritative code, e.g. `connectors/web_api/models.py:PortfolioResponse` |
| `documents` | opt. | `{endpoints: [GET /api/x], config_keys: [a.b], symbols: [Foo]}` — concrete things this doc covers |

ADR-only (lifecycle):

| field | meaning |
|---|---|
| `status` | `proposed` \| `accepted` \| `superseded` (normalizes the old `**状态**` line) |
| `date` | decision date |
| `supersedes` / `superseded_by` | ADR ids, e.g. `[010]` |

Relationships between docs stay as ordinary markdown links in the body (that's the OKF
knowledge graph). `supersedes`/`superseded_by` are typed mirrors `lint` cross-checks.

### Adding / changing a doc
- Scaffold: `run.sh new <type> <name>` prints a frontmatter skeleton to stdout — paste it
  at the top of the new file, fill it in.
- Fill `schema_source`/`documents` from the code the doc describes (grep
  `connectors/web_api/models.py`, `core/schemas.py`, `core/config/`).
- Run `run.sh lint` before committing — fix any `error` (broken link / dangling pointer /
  missing `type`).

See `references/conventions.md` for the full schema + the "no thousand-line prose" rule, and
`references/okf-spec.md` for what OKF is.

---

## Job 2 — find the right doc fast (grep first, script as fallback)

`find_docs.py` is **not** the first move. grep is. The script only pays off when grep can't
tell you which doc is authoritative.

```
1. grep the literal term first (ripgrep) — zero script overhead.
2. grep is decisive? → read that doc, done.
   "decisive" = the term hits one file, or hits a heading / frontmatter (that doc owns it).
3. grep is ambiguous? → run.sh find <query>
   "ambiguous" = hits scattered across ≥3 files / only in prose / 0 hits (synonym mismatch).
```

Why: on a clean literal hit, grep is already optimal and the script just adds a call. The
win comes from **not** calling the script on easy queries — so don't run both in parallel.
The script's real value is matching *intent*, not strings: it ranks the doc whose
frontmatter *owns* the symbol/endpoint/config-key first, even when the literal keyword is
buried. Full decision tree + the benchmark behind it: `references/lookup-strategy.md`.

### Commands
| command | use |
|---|---|
| `run.sh find <query>` | symbol (`PortfolioResponse`), endpoint (`GET /api/holdings`), config key (`verdict.risk_profile`), intent/tag, or keyword → ranked owning docs (JSON, strongest match first) |
| `run.sh schema <doc>` | resolve a doc's `schema_source` and print the real code definitions — read the authoritative schema without opening the prose |
| `run.sh index [--cache]` | dump the whole frontmatter index as JSON (`--cache` writes `docs/.okf-index.json`) |
| `run.sh lint [--ci]` | OKF compliance + drift; `--ci` exits non-zero only on errors (un-migrated docs are info, never a failure) |
| `run.sh new <type> <name>` | print a frontmatter skeleton |

---

## References
| file | when to read |
|---|---|
| `references/okf-spec.md` | what the Open Knowledge Format is (the 1-page version) |
| `references/conventions.md` | this repo's frontmatter schema + maintenance rules |
| `references/lookup-strategy.md` | the grep-first / script-fallback decision tree + benchmark |
