---
name: nmk-source-management
description: "Use when a change adds, removes, renames, or rehomes a compiled `.c`/`.cc` file or target in the NMK build system for this repo. Scope: `src/components/callp/<module>/Makefile` source registration for MAC/RLC/L2App/macphy/nrmactest/rlctest. Output: the correct Makefile edits plus verification steps for remote build sync."
---

# NMK Source Management

## Overview

The NMK build system uses explicit source registration. If a file is not listed in the right Makefile, it will not compile. If a deleted file remains listed, the remote build will fail.

## When To Use

Use this skill when:

- Adding a new `.c` or `.cc` file that must be compiled
- Removing or renaming an existing compiled file
- Creating a new library or executable target
- Debugging whether a file belongs in `_LIBSRCS` or `_SRCS`

## Do Not Use

Do not use this skill for:

- Ordinary C++ logic changes that do not affect build registration
- Remote build execution without a registration change

## Makefile Map

| Module | Makefile Path | Source Dir (`VPATH`) |
|--------|--------------|----------------------|
| MAC | `src/components/callp/mac/Makefile` | `src/duapp/mac/src` |
| RLC | `src/components/callp/rlc/Makefile` | `src/duapp/rlc/src` + `src/duapp/l2app/src` |
| L2App | `src/components/callp/l2app/Makefile` | `src/duapp/l2app/src` |
| macphy | `src/components/callp/macphy/Makefile` | `src/duapp/macphy/src` |
| nrMacTest | `src/components/callp/nrmactest/Makefile` | `src/duapp/nrmactest/src` |
| rlcTest | `src/components/callp/rlctest/Makefile` | `src/duapp/rlctest/src` |

## Core Rules

- Libraries use `<name>_LIBSRCS`
- Programs use `<name>_SRCS`
- Only filenames go into `_LIBSRCS` / `_SRCS`; `VPATH` resolves the directory
- Keep line continuations valid after removals
- If a new file needs extra headers, update `_CPPFLAGS` or the module include bundle

## Hard Constraints

- Edit only the module Makefile that owns the compiled target unless the change truly spans modules
- Keep `_LIBSRCS`, `_SRCS`, `VPATH`, and include flags internally consistent
- Do not assume a file compiles just because it exists under `src/duapp/`

## Workflow

1. Create, remove, or rename the source file in `src/duapp/<module>/`
2. Update `src/components/callp/<module>/Makefile`
3. Grep for stale includes or symbol references if removing code
4. Use `build-sync` to push and build remotely for proof

## Output Contract

The result must include:

- The Makefile path that changed
- The exact source registration addition, removal, or rename
- The intended remote verification path

## Verification

Required evidence:

- The right Makefile entry exists or was removed
- Remote build succeeded, or the failure now points to a different issue

Use `build-sync` for the final compile proof.

## References

- Remote proof: `build-sync`
