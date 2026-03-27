---
name: build-sync
description: "ALL compilation MUST go through the remote build server — local compilation is forbidden. Use for ANY compile/build/make request, remote sync, or build-server log collection. Scope: sync only `src/duapp/` plus `src/components/callp/*/Makefile`. Output: verified remote build evidence or a failing command with actionable logs."
---

# Build Sync

## Overview

This skill owns deterministic build-server mechanics for this repo. **All compilation must happen on the remote build server — local compilation is strictly forbidden.** The local machine is for editing and IDE indexing only.

Use the helper script instead of rewriting `rsync` and `ssh` commands inline.

Primary entrypoint:

```bash
.agents/skills/build-sync/scripts/build-sync.sh --help
```

## When To Use

Use this skill for:

- **Any compilation request** — all `make`, `build`, `compile` operations must route here
- Push local code to the build server
- Run `make -j8 do_strip=1` remotely
- Pull code back from the build server when the user explicitly asks for it

## Do Not Use

Do not use this skill for:

- Local IDE checks
- Source-file registration in NMK Makefiles

## Forbidden Actions

- **Never compile locally** — no `make`, `gcc`, `g++`, `cmake --build`, or any other local compilation command. All compilation goes through the remote build server via this skill.
- If a user asks to "compile" or "build" without specifying remote, assume remote and use this skill.

## Hard Constraints

- Sync only `src/duapp/` and `src/components/callp/`
- Under `src/components/callp/`, sync only `Makefile` files
- Never sync the whole `src/` tree
- Never use `rsync --delete`
- Never run `make clean`, `make clean_<mod>`, or any other clean target
- Never pull from server to local unless the user explicitly requested pull/sync-back behavior

## Workflow

1. **Check settings**: The helper script scans `docs/archive/index.md` for a context file containing build-server settings (Build Server IP, User, Remote project, Local project), then reads that `context_xxx.md` file.
2. **Missing settings**: If no matching context file exists, ask the user for the missing values and use the `docs-archive` skill to archive them as a new context entry. Then retry.
3. **Execute**: Use the helper script for the deterministic step
4. **Report**: Report the exact command or subcommand used and the resulting evidence

## Commands

```bash
.agents/skills/build-sync/scripts/build-sync.sh print-env
.agents/skills/build-sync/scripts/build-sync.sh push
.agents/skills/build-sync/scripts/build-sync.sh build
.agents/skills/build-sync/scripts/build-sync.sh pull
```

`pull` is allowed only on explicit user request.

## Output Contract

Successful runs must report:

- Which subcommand ran (push, build, or pull)
- The verification result (exit code, build output summary)

Failing runs must report:

- The subcommand that failed
- The failing log excerpt or error summary
- The next required action if obvious

## References

- Helper script: `scripts/build-sync.sh`
