---
name: Skill loading
description: Durable rules for selecting reusable agent skills without flooding the session with the full catalog.
---

Skill files are discoverable resources, not automatically active instructions.
The harness, a skill trigger, or an explicit file reference must cause a skill
to be read before its workflow applies.

**Why:** A large `.agents/skills/` tree is useful as a library, but loading every
skill creates context bloat and overlapping instructions. Contradictory hard
gates can also make an agent stop, ask unnecessary questions, or follow the
wrong process.

**How to apply:** At session start, load only the bootstrap routers
`obra/using-superpowers` and `addyosmani/using-agent-skills` when present. Use
them to select the smallest applicable process and domain skills. Prefer one
canonical skill when owners overlap; add another only for a distinct concern.