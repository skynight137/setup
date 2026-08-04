---
name: Project session state
description: Ephemeral cross-session handoff notes — what's in flight right now, cleared once folded into a commit, plan, or memory note.
---

# State

A short-lived handoff notepad — not durable lessons (`.agents/memory/`) and
not a task spec (`.agents/plans/`). This is for the messy, in-progress
detail a session doesn't want to lose if it runs out of turns mid-task:
what's been tried, what's confirmed, what the very next step is.

## Convention
- Read this file first, before anything else, when starting a session
  that continues prior work in this repo.
- Keep entries dated and short. Reference the relevant plan
  (`.agents/plans/<slug>.md`) or memory topic when one exists — don't
  repeat its content here, just say what's changed since it was written.
- **Clear an entry once its work lands**: either the change is committed
  (done — update the plan's status too), the finding is durable enough to
  become a permanent lesson (move it to `.agents/memory/` and delete it
  here), or the next step is well-defined enough to just live in the
  plan's own body. An entry that survives many sessions with no progress
  means the underlying plan is stuck — say so in the plan file, not here.
- This file should usually be empty or short. If it's accumulating
  permanent-feeling content, that content belongs in `.agents/memory/` or
  `.agents/plans/` instead — move it and clear it here.

## Current
_Nothing in flight right now._
