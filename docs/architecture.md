# Architecture Notes

## Observed behavior

`headroom wrap codex` injects a `headroom` custom model provider and changes
the active provider. It does this because Codex WebSocket traffic needs a
provider configured with WebSocket support to pass through the local proxy.

Codex persists session data in two relevant places:

- `sessions/**/*.jsonl`: immutable-like conversation transcripts and metadata.
- `state_*.sqlite`: resume-picker index, including `threads.model_provider`.

The current Headroom workaround retags SQLite rows from `openai` to `headroom`
on wrapping, then reverses that tag on unwrap. Codex versions in the affected
range also inspect session metadata during resume, so rewriting the index alone
is not a reliable cross-provider history solution.

## Non-mutation requirement

The production integration must not rename, edit, retag, reorder, or delete
live session files or their index rows to make history visible. It also must not
rewrite global `~/.codex/config.toml` while a raw Codex client is open.

Any strategy that cannot meet those requirements stays in the lab.

## Candidate directions

1. Provider-preserving transport: validate whether Codex can proxy both HTTP
   and WebSocket traffic while retaining the built-in `openai` provider.
2. Upstream fix: track Codex support for provider-agnostic session discovery.
3. Isolated runtime: separate Headroom state/config with an explicitly tested,
   read-only view of canonical session data.

The existing provider-retag workaround is not an acceptable production design.
