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

## Validated direction

Codex 0.144.1 can route through Headroom while preserving the built-in `openai`
provider when launched with temporary overrides:

```text
model_provider = "openai"
openai_base_url = "http://127.0.0.1:<port>/v1"
```

An ephemeral live probe through Headroom succeeded with `provider: openai` and
left the live config hash and thread count unchanged. This avoids the custom
provider session-discovery failure.

## Remaining work

1. Validate long interactive resume and Headroom retrieval on copied fixtures.
2. Add shared proxy lifecycle management for parallel wrapped projects.
3. Track Codex support for provider-agnostic session discovery.

The existing provider-retag workaround is not an acceptable production design.
