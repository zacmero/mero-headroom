# Agent-90 Headroom profile

`agent-90` is Headroom's internal name for the aggressive profile selected by
`codexh 90%`. It is not a Codex model or reasoning level. The profile targets
roughly 90% prompt reduction where compression is safe; this is a target, not
a guarantee.

## Why it exists

Long-running Codex agents repeatedly send large tool results and accumulated
conversation context. The normal profile remains the portable default because
this repository is used on multiple machines. `codexh 90%` explicitly enables
stronger compression while retaining strict accuracy and recency safeguards.

It sets:

```text
HEADROOM_SAVINGS_PROFILE=agent-90
HEADROOM_ACCURACY_GUARD=strict
HEADROOM_COMPRESS_SYSTEM_MESSAGES=1
HEADROOM_COMPRESS_USER_MESSAGES=1
HEADROOM_FORCE_KOMPRESS=1
HEADROOM_KOMPRESS_MAX_TOKENS=4000
HEADROOM_COMPRESSION_DEADLINE_MS=8000
HEADROOM_TARGET_RATIO=0.10
HEADROOM_MAX_ITEMS=8
HEADROOM_MIN_TOKENS=120
HEADROOM_PROTECT_ANALYSIS_CONTEXT=1
HEADROOM_PROTECT_RECENT=2
HEADROOM_CODEX_WS_COMPRESSION_TIMEOUT_SECONDS=15
```

Eligible compressible material targets a 10% retained size. Analysis and the
two newest messages remain protected, and compression fails open on timeout.
Blocks above approximately 4,000 tokens use the native reducer instead of ML.
Smaller ML jobs have an eight-second cooperative chunk deadline; their remaining
tail is preserved when the deadline expires. A single inference chunk cannot be
preempted, so the deadline is a safeguard rather than a hard CPU-time guarantee.
ONNX uses two intra-op threads and one inter-op thread. These limits can reduce
large-prose savings compared with unbounded ML execution.

## Process isolation

Plain `codexh` sessions share `127.0.0.1:18996`. Sessions started with
`codexh 90%` share a separate proxy on `127.0.0.1:18998`. Separate ports prevent
the first profile started from silently controlling the other profile.

An idle Codex session may have no established socket; it reconnects to its own
configured proxy on the next model request. Sessions started with plain
`codex` bypass Headroom. `codexh cache` uses port `18995`.

## Use

```bash
codexh                 # original Headroom defaults, port 18996
codexh 90%             # agent-90 profile, port 18998
codexh cache           # cache-oriented mode, port 18995
codex                  # raw Codex; no Headroom
codexh savings         # all reachable proxy summaries
headroom savings --days 1
headroom perf --hours 24 --format json
```

The profile is selected when starting the Codex session. Existing sessions
stay connected to the port/profile with which they started.

## Operations

Edit `scripts/codexh-native-provider`, then restart only the affected proxy:
`18996` for defaults or `18998` for `90%`. Do not restart unrelated Codex
sessions. To bypass compression, start a new session with `codex`.

Measure before changing safeguards. Actual savings are lower when requests are
short, already cached, or contain protected/recent context.
