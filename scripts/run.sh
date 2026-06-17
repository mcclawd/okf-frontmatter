#!/bin/bash
# okf-frontmatter — thin wrapper over find_docs.py (pure stdlib, no deps).
#
# Target repo resolution: pass `--repo <path>`, or just run from inside the repo
# you want to query (find_docs.py auto-detects the nearest ancestor containing
# docs/wiki, else falls back to the current working directory).
#
# Usage:
#   run.sh find <symbol|endpoint|config-key|keyword>   # locate the authoritative doc
#   run.sh schema <doc-relpath>                         # print the code def a doc points to
#   run.sh index [--cache]                              # dump the frontmatter index (JSON)
#   run.sh lint [--ci]                                  # OKF compliance + drift check
#   run.sh new <type> <name>                            # print a frontmatter skeleton
#
# Lookup strategy: grep first. Only call `run.sh find` when grep is ambiguous
# (hits scattered across files / synonym mismatch / zero hits). See
# references/lookup-strategy.md.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PY="$(command -v python3 || command -v python)"
exec "$PY" "$SKILL_DIR/find_docs.py" "$@"
