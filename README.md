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

Opt into the aggressive 90% savings target for a new session:

```bash
codexh 90%
```

Plain `codexh` keeps the original default profile. See
[docs/AGENT_90_PROFILE.md](docs/AGENT_90_PROFILE.md) for safeguards,
shared-session behavior, usage, and restart rules.

Start raw Codex with no Headroom proxy:

```bash
codex
```

Show direct per-proxy Codex WebSocket metrics:

```bash
codexh savings
```

`codexh savings` reports the baseline values below plus savings rate, coverage, latency, and the newest matching fail-open error from the proxy log.

Headroom's `/stats` endpoint exposes only an aggregate failure count. `codexh savings` therefore looks for the newest matching error in the existing proxy process log; if no entry remains (for example, after a proxy restart), the cause cannot be reconstructed from that counter alone. It does not enable full message logging.

- `Codex WS compression`: tokens actually removed from tool-result context.
- `frames`: applied compression frames and failed/fail-open frames.
- `cache reads`: provider cache-read tokens. This is not counted as compression and does not prove a ChatGPT subscription quota reduction.

An example such as `10,515 saved / 40,895 attempted | frames: 29 applied, 0 failed` means Headroom removed 10,515 tokens from 40,895 eligible tool-result tokens. That is working compression.

## Modes

`cache` mode is about upstream provider prompt-cache reuse, not “compressing the cache”: it freezes the previously forwarded prefix and compresses only an append-only new delta. Both modes still retain Headroom's ordinary local semantic cache unless `--no-cache` is used.

| Command | Mode | Proxy port | Intended use |
| --- | --- | --- | --- |
| `codexh` | `token` | `18996` | Default. Compress eligible tool outputs while retaining provider identity. |
| `codexh cache` | `cache` | `18995` | Prefer stable provider prefixes and cache reuse. |
| `codex` | none | none | Raw stable fallback; no Headroom traffic. |

The launcher starts a proxy only when its selected port is not already healthy. Startup is serialized with `flock` so simultaneous tabs cannot race to bind the same port. Health checks allow five seconds. If the default token port `18996` is occupied but unresponsive, new launches use recovery port `18994`; existing clients retain their original port. An occupied, unhealthy explicit port (or recovery port) fails with a diagnostic instead of spawning a competing proxy. Inspect ownership with `rtk ss -ltnp` before restarting any process.

Ordinary token/cache proxies set `HEADROOM_DISABLE_KOMPRESS_OPENAI=1` to avoid expensive ML inference on Codex traffic. Native log/JSON/code compression remains enabled. Numerical runtimes are limited to two threads and tokenizer parallelism is disabled. The explicit `90%` profile retains its heavier ML behavior. These settings apply when starting a proxy; reusing an existing proxy does not change its environment.

For an existing `mero-headroom-token.service`, link `config/proxy-default.service.conf` as `~/.config/systemd/user/mero-headroom-token.service.d/cpu.conf`, then run `systemctl --user daemon-reload`. The drop-in takes effect on the next service restart. Restarting a proxy leaves Codex processes alive but disconnects its clients; an in-flight turn may need retrying. ONNX uses two intra-op threads and one inter-op thread, including in the aggressive profile launched by `codexh 90%`.

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

## Install on another machine

Requirements: Git, Bash, RTK, `uv`, the Codex CLI, and a Python environment supported by Headroom.

```bash
rtk git clone https://github.com/zacmero/mero-headroom.git /projects/mero-headroom
cd /projects/mero-headroom
rtk uv tool install --force 'headroom-ai[proxy]==0.31.0'
rtk bash scripts/apply-headroom-codex-array-patch
rtk mkdir -p ~/.local/bin
rtk ln -sfn /projects/mero-headroom/scripts/codex-headroom ~/.local/bin/codex-headroom
rtk ln -sfn /projects/mero-headroom/scripts/codexh-savings ~/.local/bin/codexh-savings
```

Add this function to `~/.bashrc`, then start a new shell:

```bash
codexh() {
  if [ "${1:-}" = "savings" ]; then
    shift
    command ~/.local/bin/codexh-savings "$@"
  else
    command ~/.local/bin/codex-headroom "$@"
  fi
}
```

The launcher resolves its real repository path through symlinks, discovers the installed Headroom package under `~/.local/share/uv/tools`, pins and checks Headroom `0.31.0`, and starts every proxy with `HEADROOM_TELEMETRY=off`. Paths may differ; update the symlink targets accordingly. Do not run `headroom wrap codex` or overwrite `~/.codex/config.toml`.

Verify with an isolated call and the live counters:

```bash
codexh exec --ephemeral --skip-git-repo-check "Reply with exactly: ok"
codexh savings
```

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

Validated on 2026-11-06: Codex CLI `0.166.0` with the patched installed Headroom `0.31.0`. See [the compatibility audit](docs/COMPATIBILITY_AUDIT_2026-11-06.md) before upgrading Headroom.

## Repository State

This repository tracks integration scripts and documentation only. It must never contain authentication material, MCP API keys, copied real sessions, or `~/.codex` state. The user controls all Git commits; agents must not commit or stage changes.
