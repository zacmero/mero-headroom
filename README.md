# Mero Headroom

Version-controlled integration and regression suite for Headroom with OpenAI Codex.

## Contract

- Never commit `~/.codex`, authentication, MCP API keys, or real session files.
- Never mutate a live Codex session store during development or tests.
- Treat session discovery, provider tags, and resume behavior as compatibility
  contracts that must be tested against every Codex or Headroom upgrade.
- Raw `codex` remains the canonical fallback.

## Current status

Headroom `wrap codex` requires a custom `headroom` provider to route Codex
WebSocket traffic. Codex filters resume history by provider. This repository
exists to develop and validate a non-mutating session-discovery strategy before
it is installed against the live user configuration.

The first regression test runs Headroom against a temporary `CODEX_HOME`. It
documents the current behavior: the wrapper rewrites config and SQLite provider
tags but does not rewrite session JSONL metadata.

`scripts/codexh-native-provider` is the replacement under test. It starts or
reuses a local proxy but launches Codex with temporary CLI overrides that keep
the built-in `openai` provider. No `headroom wrap codex`; no edits to
`~/.codex/config.toml`, `state_*.sqlite`, or `sessions/**/*.jsonl`.

## Commands

```bash
rtk bash tests/test-headroom-wrap-mutation.sh
rtk bash tests/test-native-provider-probe.sh
rtk bash scripts/check-live-state.sh
```

`check-live-state.sh` is read-only. It reports provider routing and session
index counts without changing either.

## Next milestones:

1. Capture an isolated Codex 0.144.1 resume-picker regression.
2. Prototype a provider-preserving WebSocket route without changing live state.
3. Test concurrent raw and wrapped clients against copied state only.
4. Install only after the regression suite demonstrates unchanged session files,
   stable ordering, and cross-mode resume.
