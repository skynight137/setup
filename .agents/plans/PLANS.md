# Plans

Each unit of work is its own file
in this directory with a status field, so any session — this one or a
future one — can open this index and know exactly what's open, in
progress, or done without re-deriving context from chat history.

## Convention
Each plan file starts with frontmatter:
```
---
name: <short title>
status: todo | in-progress | blocked | done | reference
description: <one-line — what this plan is for>
---
```
- `todo` — not started.
- `in-progress` — actively being worked on (this session or a previous one).
- `blocked` — needs something external first (a decision, another plan,
  a secret) — say what, in the file.
- `done` — finished, or for an investigation, concluded — kept for
  history/traceability instead of deleted.
- `reference` — a historical spec/design doc that shaped the app but
  isn't itself an open or closed task (e.g. the original build prompt).

Unlike the old `docs/plans/` convention, finished plans are **not**
deleted — flip `status` to `done` and leave the file in place. That keeps
a full paper trail across sessions instead of losing context on every
completed item. Durable lessons/decisions still go in `.agents/memory/`,
not here; user-facing project documentation still goes in `replit.md`.
This directory is task specs + their status, nothing else.

When you finish a plan, add a one-line "Resolved <date>: ..." note at the
top of its body (see `hpf-lpf-true-filtering.md` for the pattern) so the
outcome is visible without opening the commit history, then update its
status here.

## Index
_Nothing in flight right now._
