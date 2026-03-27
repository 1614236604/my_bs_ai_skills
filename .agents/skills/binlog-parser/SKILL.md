---
name: binlog-parser
description: >
  Use when the user wants to parse, inspect, or analyze a local binlog file produced by nrMacTest or the DU stack.
  TRIGGER on: parse binlog, read ttilog, show log output, binlog stats, last N log entries, tail binlog.
  Do NOT trigger for: running tests (use nrmactest-runner), building (use build-sync).
---

# binlog-parser

## Overview

Parses binlog binary log files produced by nrMacTest / DU stack using `binlog_parser.py`. Operates entirely locally — no SSH required.

**Parser script:**

```
.agents/skills/binlog-parser/scripts/binlog_parser.py
```

## Mandatory Workflow — Output to File First

**CRITICAL: NEVER pipe parser output directly to terminal for analysis. ALWAYS write to a `.txt` file first, then read/grep/analyze that file.**

The parser always writes to a `.txt` file in the same directory as the input binlog (`<input>.txt`).

### Step 1 — Run parser to produce a full text dump

```bash
python3 .agents/skills/binlog-parser/scripts/binlog_parser.py <binlog-file>
```

This creates `<binlog-file>.txt` alongside the input file.

### Step 2 — Read/grep/analyze the output file

Use `grep`, `head`, `tail`, `wc -l`, or file-read tools to inspect the `.txt` file. This guarantees no data is lost to terminal truncation.

### Example Workflow

```bash
# Parse: creates ttilog.0.00.txt next to the binlog
python3 .agents/skills/binlog-parser/scripts/binlog_parser.py src/components/rootfs/oam/log/ttilog.0.00

# Analyze the output
grep -i "RACH\|CCCH\|msg1" src/components/rootfs/oam/log/ttilog.0.00.txt | head -50
wc -l src/components/rootfs/oam/log/ttilog.0.00.txt
```

## CLI Options

| Option | Description |
|---|---|
| `<file>` | (positional) binlog file path |
| `-o, --output <path>` | Override output file path (default: `<input>.txt` in same directory) |

## Output Contract

- Always writes human-readable log lines to file, one per entry. Stderr prints summary with entry count.
- On missing file: prints error to stderr and exits non-zero.

## Anti-patterns (DO NOT)

- ❌ Pipe parser output to terminal — there is no stdout mode, output always goes to file
- ✅ Run parser, then grep/read the output `.txt` file

## References

- Binary format: `docs/binlog_binary_format.md`
- Event & config: `docs/binlog_event_and_config.md`
- Produce binlog: `nrmactest-runner` skill
- **Screen log companion**: `nrmactest-runner` also pulls back `nrmactest_<test>.log` (screen output with TAG_TRACE/printf/assertions). When debugging, cross-reference the screen log for error context that does not appear in binlog.
- **Progressive diagnosis**: If the default ttilog (GENERAL events only) lacks detail for the subsystem you're investigating, use the **Symptom → Event Selection Guide** in `nrmactest-runner` SKILL.md to pick targeted `--binlog-events` and re-run. Do NOT request `all` events unless targeted runs have already been tried.
