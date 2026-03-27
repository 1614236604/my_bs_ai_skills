---
name: nrmactest-runner
description: >
  Use when the user wants to run nrMacTest on the remote build server, list available test cases, or pull back binlog files.
  TRIGGER on: run nrMacTest, execute mac tests, list test cases, run unit tests on server, pull binlog after test.
  Do NOT trigger for: building/compiling (use build-sync), parsing binlog files (use binlog-parser).
---

# nrmactest-runner

## Overview

Runs nrMacTest on the remote build server and pulls binlog files back to local.

Primary entrypoint:

```bash
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh --help
```

## When To Use

- List registered test suites/cases on remote server
- Execute nrMacTest (all tests or a specific named test)
- Pull resulting binlog files back to local for inspection

## Do Not Use

- For building the binary — use `build-sync` first
- For parsing binlog content — use `binlog-parser`

## Subcommands

| Subcommand | Description |
|---|---|
| `list` | SSH to remote and list all registered test cases (`nrMacTest list`) |
| `run [--binlog-events EVENTS] [test-name]` | Run all tests (or a specific one); optionally enable binlog and pull back |
| `print-env` | Print resolved remote server settings without executing anything |

## Usage Examples

```bash
# List all available test cases
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh list

# Run a test — default, no extra binlog events
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run PucchSchedulingMgr

# Re-run with targeted binlog events after initial analysis
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events 'mac-ulsch|mac-dlsch' PucchSchedulingMgr

# Print server config
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh print-env
```

## Output Contract

Every `run` invocation pulls **two categories** of log files back to `src/components/rootfs/oam/log/`:

| File | Description | Always present? |
|---|---|---|
| `nrmactest_<test-name>.log` (or `nrmactest_output.log` for all-tests) | Screen output: full stdout+stderr from nrMacTest, including LOGGER_LEVEL=7 debug prints, test pass/fail, assertions | **Yes** |
| `ttilog.*` | Binary binlog files containing structured TTI-level events | **Yes** (may contain only GENERAL events if `--binlog-events` not used) |

### Screen log contents

The screen log (`nrmactest_*.log`) captures everything nrMacTest prints to stdout/stderr at `LOGGER_LEVEL=7`, including:
- Test framework output (pass/fail, assertion messages)
- `TAG_TRACE` / `printf` debug prints from DU code
- Error and warning messages from all subsystems
- UE attach flow progress, scheduling decisions, HARQ feedback

### Pull summary

The script prints a summary at the end showing exactly which files were pulled back:
```
=== Pull Summary ===
Screen log : src/components/rootfs/oam/log/nrmactest_PucchSchedulingMgr.log
Binlog     : src/components/rootfs/oam/log/ttilog.*
===================
```

---

## Progressive Diagnosis Workflow (MANDATORY)

**CRITICAL: DO NOT enable `--binlog-events` on the first run.** Always follow the staged workflow below. Enabling all events upfront produces massive, noisy logs that are harder to analyze and wastes execution time.

### Core Rule For Every Re-run

For every re-run after the baseline, the agent must first state:
- the single validation question for this run
- the exact event set needed to answer that question
- why each selected event is necessary

Then run with the **smallest sufficient** `--binlog-events` set for that question.

Hard rules:
- Do **not** carry forward the previous run's event set by default
- Do **not** add adjacent events "just in case"
- Do **not** mix diagnostic goals in one re-run unless the failure path genuinely spans both subsystems
- Prefer 1 event group when possible; prefer 2-3 only when one hypothesis truly crosses boundaries
- If you broaden the set, explain what new uncertainty forced the expansion

The event set is chosen by the agent's current hypothesis, not by the wrapper script. The script should only pass through the requested value.

### Re-run Response Contract

Before launching any targeted re-run, respond in this compact format and keep it short:

```text
What I learned: <1 line from the previous screen log / GENERAL ttilog>
What remains unclear: <1 line, single uncertainty only>
Chosen events: <event-a>|<event-b>
Excluded to reduce noise: <event-x>, <event-y>
```

Rules:
- Keep it to 4 lines before the command
- Only one remaining uncertainty is allowed per re-run
- If the "Excluded to reduce noise" line is empty, the event set is probably too broad or the reasoning is incomplete
- Do not dump broad binlog plans before running; the point is to constrain the run, not narrate everything you could inspect

### Stage 1 — Baseline Run (no `--binlog-events`)

Run the test without any binlog event flags. This produces:
- Screen log with full `LOGGER_LEVEL=7` output (TAG_TRACE, printf, assertions)
- Default ttilog with GENERAL events only

```bash
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run <test-name>
```

### Stage 2 — Analyze Screen Log + Default Ttilog

**Most problems can be diagnosed here without extra binlog events.** Do this analysis BEFORE considering a re-run:

1. **Check pass/fail and errors in screen log:**
   ```bash
   grep -i 'fail\|error\|assert\|PASSED' src/components/rootfs/oam/log/nrmactest_<test>.log | tail -20
   ```

2. **Parse default ttilog** (use binlog-parser skill):
   ```bash
   python3 .agents/skills/binlog-parser/scripts/binlog_parser.py src/components/rootfs/oam/log/ttilog.0.00
   ```

3. **Search both for clues:**
   ```bash
   grep -i 'rach\|ccch\|msg1\|attach' src/components/rootfs/oam/log/nrmactest_<test>.log | head -30
   grep -i 'rach\|ccch\|error\|warn' src/components/rootfs/oam/log/ttilog.0.00.txt | head -30
   ```

**Decision point:** If the root cause is clear → DONE. If not, proceed to Stage 3.

### Stage 3 — Targeted Re-run with Selective Binlog Events

Only when Stage 2 analysis reveals that you need deeper visibility into a specific subsystem, re-run with **only the relevant events** enabled. Use the symptom-to-event table below to choose.

```bash
# Example: UL scheduling issue → enable only mac-ulsch + mac-ulsch-harq
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events 'mac-ulsch|mac-ulsch-harq' <test-name>
```

Then re-analyze the enriched ttilog alongside the screen log.

**Decision point:** If still unclear after targeted events → consider broadening to adjacent event groups, not jumping to `all`.

### Stage 3A — Write The Validation Target Before Re-running

Before every targeted re-run, write a short note in this form:

```text
Validation target: confirm whether <specific subsystem decision/state> explains <observed symptom>
Chosen events: <event-a>|<event-b>
Why these only: <1 line per event or 1 short sentence>
Excluded on purpose: <nearby but unnecessary events>
```

Example:

```text
Validation target: confirm whether UL grant generation is missing before msg3 decode fails
Chosen events: mac-ulsch
Why these only: need UL scheduling decisions and grant parameters; no HARQ symptom yet
Excluded on purpose: mac-ulsch-harq, mac-dlsch, rlc-srb
```

If you cannot write this note crisply, you do not yet know enough to re-run. Go back to Stage 2 analysis.

### Stage 3B — Rebuild The Event Set From Scratch

Treat each targeted re-run as a fresh selection, not as an incremental append to the previous run.

Good:

```bash
# First targeted run: UL scheduling only
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events 'mac-ulsch' <test-name>

# Second targeted run: discard UL scheduling, now inspect SRB signaling only
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events 'rlc-srb' <test-name>
```

Bad:

```bash
# Keeps piling on unrelated events from prior runs
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events 'mac-ulsch|mac-ulsch-harq|mac-dlsch|rlc-srb' <test-name>
```

The default assumption is that previously enabled events are no longer needed unless the current validation target explicitly still depends on them.

### Stage 4 — Full Events (last resort only)

Use `--binlog-events all` ONLY when:
- The problem spans multiple subsystems and you cannot isolate which one
- Two rounds of targeted events still haven't revealed the cause
- The user explicitly requests full logs

```bash
.agents/skills/nrmactest-runner/scripts/nrmactest-runner.sh run --binlog-events all <test-name>
```

---

## Symptom → Event Selection Guide

Use this table to pick the right `--binlog-events` for Stage 3. Combine with `|` when the symptom spans areas.

| Symptom / Debug Area | Events to Enable | Rationale |
|---|---|---|
| UL scheduling not happening / wrong grants | `mac-ulsch` | UL scheduling decisions, grant parameters |
| UL HARQ failures / retransmissions | `mac-ulsch-harq` | UL HARQ process state, ACK/NACK |
| DL scheduling not happening / wrong grants | `mac-dlsch` | DL scheduling decisions, resource allocation |
| DL HARQ failures / retransmissions | `mac-dlsch-harq` | DL HARQ process state, feedback |
| DL retransmission logic | `mac-dlsch-retx` | Retransmission trigger and parameters |
| UCI / PUCCH issues (SR, HARQ-ACK, CSI) | `mac-uci` | UCI reception and decoding path |
| CSI reporting / CQI problems | `mac-csi` | CSI report processing |
| SRS processing | `mac-srs` | SRS reception and measurement |
| Timing advance / TA commands | `mac-ta` | TA calculation and MAC CE generation |
| DL link adaptation / MCS selection | `mac-dlla` | DL BLER, MCS adjustment |
| UL link adaptation / MCS selection | `mac-ulla` | UL BLER, MCS adjustment |
| DTX detection | `mac-dtx` | DTX detection events |
| RLC SRB (SRB1/SRB2) issues | `rlc-srb` | RLC SRB PDU assembly/reception |
| RLC AM DRB issues | `rlc-drbam` | RLC AM mode data bearer |
| RLC UM DRB issues | `rlc-drbum` | RLC UM mode data bearer |
| UE attach flow (RACH→connected) | `mac-ulsch\|mac-dlsch\|rlc-srb` | Covers msg3/msg4/msg5 + SRB signaling |
| Full HARQ debugging | `mac-ulsch-harq\|mac-dlsch-harq\|mac-dlsch-retx` | Complete HARQ picture |
| Full link adaptation | `mac-dlla\|mac-ulla\|mac-csi\|mac-srs` | All LA-related inputs |

## Validation Goal → Minimal Event Set

Use this section when re-running. The goal is not to capture "everything related"; the goal is to capture only what answers the current question.

| Validation goal | Minimal event set | Usually exclude |
|---|---|---|
| Confirm UL grant was or was not generated | `mac-ulsch` | `mac-dlsch`, `rlc-srb`, `mac-ulsch-harq` |
| Confirm UL HARQ state caused retransmission failure | `mac-ulsch-harq` | `mac-dlsch`, `rlc-srb`, `mac-csi` |
| Confirm DL grant or msg4 scheduling is missing | `mac-dlsch` | `mac-ulsch`, `mac-dlsch-harq`, `rlc-srb` |
| Confirm DL HARQ feedback or retx path is wrong | `mac-dlsch-harq` or `mac-dlsch-retx` | `mac-ulsch`, `rlc-srb` |
| Confirm SRB signaling path is broken after scheduling succeeded | `rlc-srb` | `mac-csi`, `mac-srs`, unrelated HARQ events |
| Confirm attach issue spans msg3 UL + SRB signaling | `mac-ulsch\|rlc-srb` | `mac-dlsch-harq`, LA-related events |
| Confirm attach issue spans msg4 DL + SRB signaling | `mac-dlsch\|rlc-srb` | `mac-ulsch-harq`, LA-related events |
| Confirm link adaptation inputs affect scheduling | only the specific LA set needed: `mac-dlla`, `mac-ulla`, `mac-csi`, or `mac-srs` | `rlc-srb`, unrelated HARQ events |

Selection rules:
- Start from the validation goal, not from the subsystem list
- If one event can answer the question, stop at one
- If you choose two or more, each one must correspond to an explicit causal hop you are validating
- Avoid mixing scheduling, HARQ, RLC, and link-adaptation events unless the current evidence forces a cross-layer hypothesis

## Event Budget Heuristic

Use this budget unless the current evidence justifies more:

| Re-run type | Recommended budget |
|---|---|
| Single-subsystem confirmation | 1 event group |
| Cross-layer causal check | 2 event groups |
| Tight multi-hop investigation | 3 event groups max |
| More than 3 groups | escalate justification in the notes before running |

If you think you need 4+ groups, you are likely collapsing multiple questions into one noisy run. Split them into separate re-runs whenever possible.

## Post-run Evidence Filtering

After a targeted re-run, report only the evidence that answers the stated validation target.

Required behavior:
- Quote or summarize only the binlog events that directly support or refute the chosen hypothesis
- Ignore unrelated event families even if they were also captured
- Prefer a short causal conclusion over a long event dump
- If the result reveals a new uncertainty in a different subsystem, start a new re-run cycle with a new event set instead of continuing to expand the current report

Good:
- "The `mac-ulsch` events show no UL grant emitted for the failing TTI, so the next run should stay in UL scheduling."
- "The `rlc-srb` events show SRB PDUs are queued after msg4, so the attach stall is likely earlier in DL scheduling, not SRB."

Bad:
- dumping all captured `mac-ulsch`, `mac-dlsch`, and `rlc-srb` lines even though the current run only aimed to verify UL grant creation
- surfacing unrelated LA or HARQ details because they happened to appear in the same ttilog

---

## Logging Configuration

All `run` invocations set:
- `LOGGER_LEVEL=7` (DEBUG, most verbose)

### Binlog (ttilog) behavior

**Without** `--binlog-events`: nrMacTest still produces `ttilog.*` with default/GENERAL events. GENERAL events are always recorded regardless of event mask — they cover initialization, warnings, errors, and aggregate statistics.

**With** `--binlog-events`: enables additional TRACE-level events in the ttilog for targeted subsystems. These events carry detailed per-TTI scheduling parameters, HARQ states, and resource allocations that GENERAL events do not include.

When `--binlog-events` is specified, the script also sets:
- `BINLOG_PATH=<remote-src>/components/rootfs/oam/log`
- `BINLOG_EVENTS=<events>`

## Cross-referencing Screen Log and Binlog

Screen log and binlog contain **complementary** information. Always cross-reference:

| Information | Screen log | Binlog |
|---|---|---|
| Test pass/fail result | ✅ | ❌ |
| Assertion failure messages | ✅ | ❌ |
| TAG_TRACE / printf debug | ✅ | ❌ |
| Structured TTI events | ❌ | ✅ |
| Scheduling grant details | ❌ | ✅ (needs event enabled) |
| HARQ process states | ❌ | ✅ (needs event enabled) |
| UE attach flow summary | ✅ | ✅ |
| Error/warning text | ✅ | ✅ (GENERAL, always present) |

## Anti-patterns

- ❌ **Running with `--binlog-events all` as the first step** — produces huge, noisy logs; defeats the purpose of event filtering
- ❌ **Enabling events "just in case"** — identify the subsystem first from screen log + GENERAL ttilog
- ❌ **Appending new events onto the previous run's set without re-justifying each one** — causes noisy logs and hides the signal you were trying to verify
- ❌ **Combining unrelated event families in one re-run** — for example, adding `mac-csi` or `mac-srs` while validating an SRB signaling hypothesis with no LA evidence
- ❌ **Using one re-run to answer multiple independent questions** — split into separate runs with separate event sets
- ❌ **Skipping screen log analysis** — many diagnostic messages (assertions, TAG_TRACE, printf) only appear in screen output
- ❌ **Re-running with events before reading the Stage 2 output** — always analyze what you have before asking for more

## Expected Agent Behavior

When the user asks to re-run a test for more visibility, the agent should respond in this order:

1. State what was learned from the previous screen log and GENERAL ttilog
2. State the single remaining uncertainty
3. Choose the minimal event set that answers that uncertainty
4. Explicitly name nearby events that are being excluded to keep output small
5. Run the test with that event set
6. Parse only the returned evidence relevant to the stated validation target
7. If another subsystem becomes suspect, start a fresh re-run plan instead of appending more events to this one

This keeps the pulled output bounded and avoids drowning the user in unrelated binlog events.

## References

- Build server config: see `docs/archive/index.md` → context entry with 构建服务器
- Binlog parsing: `binlog-parser`
- Build binary: `build-sync`
- Archive memory updates: `docs-archive`
