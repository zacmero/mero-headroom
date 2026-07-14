# Mero Headroom Agent Directives

## Purpose

Maintain a session-safe Headroom integration for Codex CLI. The primary invariant is that Headroom saves context tokens without changing how Codex discovers, orders, resumes, or stores sessions.

## Non-Negotiable Rules

1. Never commit, stage, amend, reset, revert, or otherwise write Git history. The user owns all commits.
2. Treat Codex sessions as immutable user data. Never edit, rename, delete, reindex, copy over, or retag `~/.codex/sessions`, `state_*.sqlite`, session metadata, or resume indexes.
3. Never allow raw `codex` to inherit a Headroom provider or local proxy base URL. Raw Codex must remain a working direct fallback.
4. Never run `headroom wrap codex` against the live user configuration. It can inject a `headroom` provider and break provider-filtered session discovery.
5. Never overwrite `~/.codex/config.toml`. Preserve user-managed MCP servers, profiles, status-line configuration, models, and authentication behavior.
6. Do not kill a Headroom proxy or Codex process until its port/process ownership is verified. Do not disrupt live project work to restart a proxy.
7. Do not report cache reads as token compression or as proven ChatGPT subscription quota savings.

## Required Architecture

- `codex` is raw and never proxied by persistent configuration.
- `codexh` calls `~/.local/bin/codex-headroom`, which delegates to `scripts/codexh-native-provider`.
- The launcher applies only process-scoped Codex overrides:
  - `model_provider="openai"`
  - `openai_base_url="http://127.0.0.1:<port>/v1"`
  - Headroom MCP proxy URL for that process
- Default mode is `token` on port `18996`.
- `codexh cache` uses `cache` mode on port `18995`.
- Proxies launched by this repository must set `HEADROOM_TELEMETRY=off`.
- The active launcher uses `--intercept-tool-results`, `--code-aware`, and `HEADROOM_CODEX_WS_COMPRESSION_TIMEOUT_SECONDS=15`.

Provider identity must remain `openai` in both raw and wrapped sessions. This prevents the session resume list from splitting by provider.

## Headroom Compatibility Patch

The installed Headroom `0.31.0` handler requires `patches/headroom-0.31.0-codex-array-output.patch` for Codex CLI `0.144.1` array-form `custom_tool_call_output` payloads. `scripts/apply-headroom-codex-array-patch` applies it before startup.

- Keep the patch version-pinned and fail closed on a different Headroom version.
- Do not bypass the version refusal just to make `codexh` launch.
- After any Headroom update, validate in an isolated `codex exec --ephemeral` run before changing live launcher behavior.
- A successful validation requires nonzero `codex_ws.frame_tokens_saved_sum`, applied frames, and zero failed frames for a representative large tool result.
- Preserve the array structure when modifying `custom_tool_call_output`; never replace protocol objects wholesale.

## Validation and Monitoring

Use `rtk` as the prefix for all shell commands.

Run repository checks before broad launcher changes:

```bash
rtk bash tests/test-headroom-wrap-mutation.sh
rtk bash tests/test-native-provider-probe.sh
rtk bash scripts/check-live-state.sh
```

Use `codexh savings` to inspect live proxy counters. Interpret them precisely:

- `frame_tokens_saved_sum / frame_attempted_tokens_sum`: actual Codex WebSocket tool-result compression.
- `frames_compressed_total`: successful compression applications.
- `frames_failed_total`: compression work that failed open; investigate before claiming a mode is healthy.
- `cache_read_tokens`: provider cache activity only, not compression.

Never use ordinary interactive Codex sessions as regression tests. Use ephemeral Codex calls and isolated proxy ports. Do not log or retain user prompts, code, secrets, or session payloads in the repository.

## Change Scope

Keep changes limited to this repository's launcher, guarded patch, tests, and documentation unless the user explicitly authorizes a global shell or Codex configuration change. Before any modification outside this repository, create a timestamped backup when applicable and explain the expected behavioral effect.

When updating documentation, keep `README.md` aligned with the actual ports, launcher flags, modes, telemetry policy, compatibility version, and `codexh savings` semantics.
