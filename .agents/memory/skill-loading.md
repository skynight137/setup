---
name: Skill loading
description: Durable rules for selecting reusable agent skills without flooding the session with the full catalog.
---

Skill files are discoverable resources, not automatically active instructions.
The harness, a task trigger, or an explicit file reference must cause a skill
to be read before its workflow applies.

**Why:** A large `.agents/skills/` tree is useful as a library, but loading every
skill creates context bloat and overlapping instructions. Contradictory hard
gates can also make an agent stop, ask unnecessary questions, or follow the
wrong process.

**How to apply:** At session start, use the task wording, project rules, and
available skill metadata to identify and load only the smallest applicable
process and domain skills. If the active harness supplies a mandatory router,
follow it, but do not hard-code a particular provider or owner as a universal
dependency. Prefer one canonical skill when owners overlap; add another only
for a distinct concern.