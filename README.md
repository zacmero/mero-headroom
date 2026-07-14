# Mero Headroom

Session-safe Headroom integration for OpenAI Codex CLI. The goal is real tool-result compression without changing Codex's built-in `openai` provider identity or touching the session store.

## Operating Contract

- `codex` is the raw, stable fallback. It never routes through a Headroom proxy.
- `codexh` is the wrapped launcher. It routes only that process through a local Headroom proxy and keeps Codex's provider as `openai`.
- Codex sessions are sacred. The integration must not edit `~/.codex/sessions`, `state_*.sqlite`, or the raw `~/.codex/config.toml` provider routing.
- Headroom remains available as an MCP server, but raw Codex is not permanently proxied.
- Telemetry is off for every proxy started by this launcher.

## Commands

Start wrapped Codex in the default token-compression mode:

```bash
codexh
```

Start wrapped Codex in cache mode:

```bash
codexh cache
```

Start raw Codex with no Headroom proxy:

```bash
codex
```

Show direct per-proxy Codex WebSocket metrics:

```bash
codexh savings
```

`codexh savings` reports three independent values:

- `Codex WS compression`: tokens actually removed from tool-result context.
- `frames`: applied compression frames and failed/fail-open frames.
- `cache reads`: provider cache-read tokens. This is not counted as compression and does not prove a ChatGPT subscription quota reduction.

An example such as `10,515 saved / 40,895 attempted | frames: 29 applied, 0 failed` means Headroom removed 10,515 tokens from 40,895 eligible tool-result tokens. That is working compression.

## Modes

| Command | Mode | Proxy port | Intended use |
| --- | --- | --- | --- |
| `codexh` | `token` | `18996` | Default. Compress eligible tool outputs while retaining provider identity. |
| `codexh cache` | `cache` | `18995` | Prefer stable provider prefixes and cache reuse. |
| `codex` | none | none | Raw stable fallback; no Headroom traffic. |

The launcher starts a proxy only when its selected port is not already healthy. Multiple `codexh` processes can share the matching local proxy without provider-name changes or session-index rewriting.

## How It Works

`~/.local/bin/codex-headroom` delegates to `scripts/codexh-native-provider`. The launcher:

1. Applies the guarded compatibility patch described below.
2. Starts Headroom with `HEADROOM_TELEMETRY=off`, tool-result interception, code awareness, and a 15-second Codex WebSocket compression deadline.
3. Starts Codex with process-only `-c` overrides for the local base URL while explicitly retaining `model_provider="openai"`.
4. Does not write Codex configuration, session JSONL, or SQLite state.

The process-only provider preservation is essential: direct `headroom wrap codex` can inject a `headroom` model provider and fragment Codex resume discovery by provider. Do not replace this launcher with `headroom wrap codex`.

## Headroom 0.31.0 Compatibility Patch

Codex CLI `0.144.1` sends `custom_tool_call_output.output` as an array of `input_text` items. Headroom `0.31.0` originally accepts only a string output in this path, which resulted in zero eligible compression units.

`patches/headroom-0.31.0-codex-array-output.patch` makes the smallest required compatibility changes:

- preserve the output array and compress its largest `input_text` item;
- make the Codex WebSocket compression ceiling configurable;
- use `HEADROOM_CODEX_WS_COMPRESSION_TIMEOUT_SECONDS=15` from the launcher so larger JSON outputs can finish instead of failing open at five seconds.

`scripts/apply-headroom-codex-array-patch` runs before each `codexh` launch. It is intentionally pinned to Headroom `0.31.0` and refuses other versions. This is a safety check, not a current failure.

### After a Headroom Update

Do not bypass the refusal or remove the version check. An update can replace the patched installed file or change its surrounding implementation.

1. Keep using raw `codex` if needed.
2. Validate the new Headroom version and its Codex Responses/WebSocket payload handling in an isolated ephemeral test.
3. Update the patch only if the new code still needs it, or remove it if upstream has fixed the array-output handling.
4. Verify a large JSON or tool-result request yields nonzero `Codex WS compression` with zero failed frames.
5. Only then use `codexh` for production sessions.

## Verification

Run repository checks through RTK:

```bash
rtk bash tests/test-headroom-wrap-mutation.sh
rtk bash tests/test-native-provider-probe.sh
rtk bash scripts/check-live-state.sh
```

Useful live checks:

```bash
codexh savings
headroom --version
```

Current supported baseline: Codex CLI `0.144.1` and Headroom `0.31.0`.

## Repository State

This repository tracks integration scripts and documentation only. It must never contain authentication material, MCP API keys, copied real sessions, or `~/.codex` state. The user controls all Git commits; agents must not commit or stage changes.
