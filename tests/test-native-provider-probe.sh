#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port=18993
config_before="$(sha256sum "$HOME/.codex/config.toml" | awk '{print $1}')"
threads_before="$(sqlite3 "$HOME/.codex/state_5.sqlite" 'SELECT COUNT(*) FROM threads;')"
sessions_before="$(find "$HOME/.codex/sessions" -type f -name '*.jsonl' | wc -l)"

MERO_HEADROOM_PORT="$port" "$repo_root/scripts/codexh-native-provider" \
  exec --ephemeral --skip-git-repo-check -m gpt-5.6-terra \
  'Reply with exactly: native-provider-test-ok' | grep -qx 'native-provider-test-ok'

config_after="$(sha256sum "$HOME/.codex/config.toml" | awk '{print $1}')"
threads_after="$(sqlite3 "$HOME/.codex/state_5.sqlite" 'SELECT COUNT(*) FROM threads;')"
sessions_after="$(find "$HOME/.codex/sessions" -type f -name '*.jsonl' | wc -l)"

test "$config_before" = "$config_after"
test "$threads_before" = "$threads_after"
test "$sessions_before" = "$sessions_after"
printf '%s\n' 'PASS: built-in provider routed through Headroom without live state mutation.'
