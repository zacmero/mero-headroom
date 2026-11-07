# Compatibility and CPU incident audit — 2026-11-06

## Final production status

The initial rollout blocker below was resolved: the gated flag enables optional
file-read interceptors, while stable core Responses compression works without
it. The launcher now selects the pinned, versioned `0.43.1` runtime on both
machines. Ordinary and aggressive VM production proxies were migrated without
stopping any of the twelve pre-existing Codex processes. Their connections could
be interrupted by proxy restarts.

Isolated provider/session-safety probes passed locally and on the ARM VM before
promotion. Production probes returned `LOCAL_PRODUCTION_OK` and
`VM_PRODUCTION_OK`. Local default counters recorded one applied frame, 395 saved
tokens, and zero failures. VM aggressive counters recorded two applied frames,
5,638 saved tokens, zero failures, and zero leaked workers after the probes.
These are focused checks, not a sustained-load or general accuracy guarantee.
Earlier sections describe the incident and intermediate migration findings.

## Local incident

Codex was `0.166.0`; the installed Headroom reported `0.31.0` and retained our array-output patch. The owned proxy PID `132074` occupied port `18996` but failed `/livez` and `/health` checks, accumulated queued client connections, and consumed CPU. The launcher treated the failed health check as an absent process, attempted a second bind, and logged `address already in use`.

The precise internal blocking operation was not captured. ML workload is a contributing concern, not a proven stack-level diagnosis. A separate synthetic compression probe also caused substantial CPU consumption.

After verifying process and port ownership, graceful shutdown was attempted. The original PID remained unresponsive and was force-stopped. No Codex process was killed. In-flight requests on the old proxy could fail during recovery.

## Implemented mitigation

- Serialize launchers with a lock, closed before executing Codex or in proxy children.
- Allow five seconds for health checks.
- Use recovery port `18994` for new default token launches if `18996` is occupied and unhealthy. Explicit ports fail closed.
- Disable Kompress for OpenAI traffic in ordinary token/cache profiles; retain native compression. Keep the aggressive profile opt-in.
- Limit OMP, MKL, and OpenBLAS to two threads; disable tokenizer parallelism.
- Fix savings reporting so an absent matching error-log line does not abort the report.

## Verification

The replacement proxy on `18996` returned healthy, with `disable_kompress_openai=true`, no leaked compression threads, and no running/queued compression work after the probes. An idle three-second CPU sample measured 0.00% of one core; this is not a guarantee under load.

An ephemeral Codex synthetic log probe preserved `error_count=7` and `final_balance=12345.67`, saved 8,862 of 8,964 eligible tool-result tokens, applied one compressed frame, and recorded zero failed frames. This tests repetitive logs, not arbitrary content or general accuracy.

The provider probe passed without changes to configuration, stored thread count, or stored session-file count. Launcher recovery and isolated wrap-help fixture tests passed. Wrap help is now read-only in the installed build; that does not establish that actual upstream wrapping is session-safe.

## VM observations

The existing VM at `204.216.172.41` also reports Codex `0.166.0` and Headroom `0.31.0`. Its systemd user service `mero-headroom-token.service` is active. PID `2227` responded to health checks with no queued/running compression work or leaked threads. It accumulated roughly seven minutes of CPU time over four days. OpenAI Kompress was not disabled in that existing service.

The VM's running Codex and Headroom processes were not restarted. Its working tree was clean during the audit. Local launcher changes do not affect its already-running systemd service.

The active wrapped VM clients use `18998` (`agent-90`), rather than the idle default token service. That proxy responded healthy but reports 1,736 compressed frames, 35 failed frames, 3,158,890 saved tokens from 7,063,850 eligible tokens, and 35 leaked compression threads. It is functioning but degraded; a successful health response alone is insufficient. A controlled restart and retest of this profile is warranted when its clients can tolerate reconnecting. Its accumulated CPU average was 3.4%; this is not a current interval measurement.

The separate `mero_terminal` checkout has existing edits in `bashrc`, `profile`, and `codex/config.toml`. The VM's live Codex config is currently a regular file, not the previously configured symlink. Those user changes were preserved; no configuration reconciliation was attempted during this Headroom incident.

## Upstream upgrade assessment

Upstream [v0.43.1](https://github.com/headroomlabs-ai/headroom/releases/tag/v0.43.1), published 2026-11-05, includes ChatGPT HTTP/1.1 streaming fixes and bounded tokenizer/beacon/LiteLLM caches. The [upstream changelog](https://github.com/headroomlabs-ai/headroom/blob/v0.43.1/CHANGELOG.md) also contains changes around compression deadlines, executor saturation, and Codex protocol handling. These warrant a separate migration.

The candidate was installed only in `/tmp/mero-headroom-audit-0431`. Starting it with our required `--intercept-tool-results` flag failed because that feature is unavailable on the stable rollout channel. No canary/emergency override was enabled. Consequently it did not pass an end-to-end compression test and was not installed over the live runtime.

Upstream now handles array-form output and newer Codex tool representations itself. The old version-specific patch must not be applied to it. A migration must reconcile stable-channel interception support, inspect the new timeout mechanism, verify retrieval behavior and provider identity, and rerun a representative isolated compression probe before switching production.

Current [OpenAI WebSocket documentation](https://developers.openai.com/api/docs/guides/websocket-mode) describes incremental inputs and multiplexed streams. That increases the importance of testing stream/session boundaries rather than assuming an old payload patch covers every newer Codex behavior.

Recommendation: retain the validated runtime while recovering operation; migrate upstream in isolation after resolving its interception rollout gate. Do not infer subscription quota savings from compression or provider cache counters.

## Deployment follow-up

The fixes were committed and pulled onto the VM. The default service received
the tracked CPU environment drop-in. Both default and aggressive proxies were
restarted while all twelve pre-existing Codex PIDs remained alive. The restarted
aggressive proxy initially compressed a log probe but recorded one new leaked
worker. Thread limits alone were therefore insufficient. The aggressive launcher
now gates ML blocks at approximately 4,000 tokens and sets an eight-second
cooperative deadline, retaining native reduction for larger inputs. The outer
WebSocket compression timeout remains 15 seconds.
