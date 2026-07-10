#!/usr/bin/env bash
set -euo pipefail

codex_home="${CODEX_HOME:-$HOME/.codex}"
state_db="$(find "$codex_home" -maxdepth 1 -name 'state_*.sqlite' -type f -print -quit)"

printf '%s\n' 'Routing keys:'
grep -nE 'model_provider|openai_base_url|\[model_providers\.headroom\]|127\.0\.0\.1' "$codex_home/config.toml" || true

printf '%s\n' 'Session files:'
find "$codex_home/sessions" -type f -name '*.jsonl' 2>/dev/null | wc -l

if [ -n "$state_db" ]; then
  printf '%s\n' 'Thread providers:'
  sqlite3 -header -column "$state_db" 'SELECT model_provider, COUNT(*) AS count FROM threads GROUP BY model_provider ORDER BY count DESC;'
fi
