# Repo Skill Guidelines

## Purpose

This repo uses skills as executable workflow contracts, not long-form prompt dumps. Keep routing in `CLAUDE.md`/`AGENTS.md`, keep execution guidance in each `SKILL.md`, and move deterministic mechanics into scripts or references.

## Design Layers

1. `CLAUDE.md` / `AGENTS.md`
   - Repo-level triggers and hard constraints.
   - Which skill to invoke for which change type.
   - Completion gates such as verification requirements.
2. `SKILL.md`
   - Activation-specific workflow and decision points.
   - Output contract and escalation rules.
   - Short enough to read on activation without dragging in deep reference material.
3. `references/` and `scripts/`
   - `references/` for large API tables, templates, and examples.
   - Skill-local `scripts/` for repeated shell recipes and deterministic data collection.

## Description Contract

Treat frontmatter `description` as routing metadata.

Every description should answer three questions in one short paragraph:

- When should the skill trigger?
- What repo scope qualifies?
- What artifact or decision should come out of invoking it?

Preferred shape:

```yaml
description: Use when <triggering situation>. Scope: <files/modules/change type>. Output: <artifact or validated result>.
```

Avoid workflow summaries in the description. Those belong in the body.

## Body Structure

Keep `SKILL.md` short and operational:

1. Overview
2. When to use / when not to use
3. Required workflow
4. Output contract
5. References or scripts to load only when needed

If the file starts to become a manual, split the bulky part into `references/`.

## Script-First Rule

If the same shell sequence appears in a skill more than once, convert it into a script.

Put into scripts:

- Fixed `ssh` / `rsync` recipes
- Log capture commands
- Reusable environment setup
- Stable verification pipelines

Default location: `.claude/skills/<skill>/scripts/`. Only promote a script to a repo-level shared location when it is intentionally reused across multiple unrelated skills.

Keep in prose:

- Whether the task actually requires the script
- How to interpret failures
- Tradeoffs, risk assessment, and user-facing explanation

## Verification Contract

Skills that can claim success must define evidence:

- The exact verification command or script
- What a passing result looks like
- What to report when the gate fails

Do not let a skill end with "report success/failure" unless it also defines the proof.

## Local Review Rubric

Use this checklist when adding or editing a skill:

- `description` is trigger-first, not process-first.
- The trigger includes scope, not just vague intent words.
- The expected output or decision is explicit.
- Repo-wide routing rules stay in `CLAUDE.md`, not duplicated in every skill.
- Repeated shell sequences are delegated to scripts.
- Large examples or reference tables live outside `SKILL.md`.
- The skill says when not to use it.
- Verification evidence is defined.
- The wording is specific enough to avoid accidental under-triggering.
- The body is short enough to load without becoming the entire context window.
