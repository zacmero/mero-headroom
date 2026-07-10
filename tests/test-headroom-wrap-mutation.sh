#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/sessions/2026/01/01"
cp "$repo_root/config/codex.raw.template.toml" "$scratch/config.toml"
cp "$repo_root/fixtures/session-meta.jsonl" "$scratch/sessions/2026/01/01/fixture.jsonl"

sqlite3 "$scratch/state_1.sqlite" <<'SQL'
CREATE TABLE threads (id TEXT PRIMARY KEY, model_provider TEXT NOT NULL);
INSERT INTO threads VALUES ('fixture-thread', 'openai');
SQL

CODEX_HOME="$scratch" headroom wrap codex --port 18990 --no-proxy --no-mcp --no-tokensave --help >/dev/null

grep -q 'model_provider = "headroom"' "$scratch/config.toml"
test "$(sqlite3 "$scratch/state_1.sqlite" "SELECT model_provider FROM threads;")" = 'headroom'
grep -q '"model_provider":"openai"' "$scratch/sessions/2026/01/01/fixture.jsonl"

CODEX_HOME="$scratch" headroom unwrap codex --port 18990 --no-stop-proxy >/dev/null

cmp -s "$scratch/config.toml" "$repo_root/config/codex.raw.template.toml"
test "$(sqlite3 "$scratch/state_1.sqlite" "SELECT model_provider FROM threads;")" = 'openai'

printf '%s\n' 'PASS: Headroom mutations are confined to temporary config/index fixtures.'
