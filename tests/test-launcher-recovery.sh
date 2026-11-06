#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
cat >"$scratch/bin/curl" <<'SH'
#!/bin/sh
case "$*" in *:18994/health*) exit 0;; *) exit 1;; esac
SH
cat >"$scratch/bin/ss" <<'SH'
#!/bin/sh
printf 'LISTEN\n'
SH
cat >"$scratch/bin/codex" <<'SH'
#!/bin/sh
printf '%s\n' "$@"
SH
chmod +x "$scratch/bin/"*
PATH="$scratch/bin:$PATH" XDG_STATE_HOME="$scratch/state" \
  "$repo_root/scripts/codexh-native-provider" --version >"$scratch/result" 2>"$scratch/error"
grep -q 'openai_base_url="http://127.0.0.1:18994/v1"' "$scratch/result"
grep -q 'model_provider="openai"' "$scratch/result"
grep -q 'recovery port' "$scratch/error"
if PATH="$scratch/bin:$PATH" XDG_STATE_HOME="$scratch/state" MERO_HEADROOM_PORT=18996 \
  "$repo_root/scripts/codexh-native-provider" --version >"$scratch/result" 2>"$scratch/error"; then
  printf 'FAIL: explicit occupied port must not fall back\n' >&2
  exit 1
fi
grep -q 'refusing to start a competing proxy' "$scratch/error"
printf 'PASS: unhealthy occupied port recovers safely; explicit ports fail closed.\n'
