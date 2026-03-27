## Repo Purpose

This repository contains an NTN-focused 5G-NR DU stack based on 3GPP Release 18 specifications. We only work in the DU layer: MAC, RLC, L2App, macphy, tests, and related interfaces.

Key 3GPP 38-series references:

- **TS 38.101** — NR UE radio transmission and reception (RF requirements)
- **TS 38.211** — Physical channels and modulation
- **TS 38.212** — Multiplexing and channel coding
- **TS 38.213** — Physical layer procedures for control
- **TS 38.214** — Physical layer procedures for data
- **TS 38.321** — MAC protocol
- **TS 38.322** — RLC protocol
- **TR 38.821** — NTN solutions for NR

## Skill Routing

Use these local skills by change type:

- `nmk-source-management`: adding, removing, renaming, or rehoming compiled `.c`/`.cc` files or targets under `src/components/callp/`.
- `build-sync`: **ALL compilation must go through the remote build server — local compilation is forbidden.** Use for any compile/build/make request, remote sync, or build-server log collection.
- `docs-archive`: archiving, distilling, or saving conversation-derived insights (corrections, user feedback, project context) to the project's `docs/archive/` directory.

Docs-only edits normally do not require build-related skills unless they change an executable workflow.

## Session Bootstrap (Mandatory)

At the start of every conversation, load `docs/archive/index.md` immediately — before processing any user request. This index contains accumulated project context, design constraints, and lessons learned that inform all subsequent work.

## Context Priority

When skill-level instructions conflict with or duplicate archive content, **skills always win**. Archive entries serve as background knowledge; skills are authoritative for their domains.

## Verification Gate

Before claiming completion, run the relevant verification path with fresh output through the appropriate skill. Do not claim success based only on static inspection.

## References

- Skill authoring rules: `docs/skills-guidelines.md`
