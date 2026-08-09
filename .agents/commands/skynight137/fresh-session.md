---
description: Start or resume work from the project vault, verify it against the current checkout, and complete the next safe work item hands-off.
argument-hint: [optional goal or constraint]
---

# Fresh Session

Use this command at the beginning of a new work session. It is intentionally
short: the vault holds the context, and the current checkout is the authority.

## 1. Orient

### Discover applicable skills

Before exploring the repository or choosing work, use the task wording,
project rules, and any skill metadata provided by the current harness to
identify applicable workflows. If the current harness provides a mandatory
skill-discovery or router procedure, follow it; otherwise select skills from
the task and the available catalog without loading unrelated skill files.

Do not load every skill in `.agents/skills/`. Load only the smallest applicable
process, domain, or implementation skills for the selected work item. Prefer
one canonical skill when multiple owners provide overlapping guidance; use an
additional skill only when it contributes a distinct required concern. Do not
hard-code a particular provider or owner as a universal bootstrap dependency.

Read, when present:

1. `.agents/chats/current.md`
2. the active or most recent relevant files in `.agents/plans/`
3. linked `.agents/memory/` topics
4. relevant project rules

Then inspect:

```bash
git status --short
git branch --show-current
git log -10 --oneline
```

Do not create or use an ephemeral state directory.

## 2. Choose the next concrete item

Prefer, in order:

1. The exact next step in `.agents/chats/current.md`.
2. An `in-progress` plan with an explicit next action.
3. A `todo` or unblocked plan that matches the current checkout.
4. The user-supplied argument, if present.

Verify that the referenced files, symbols, branch, and assumptions still exist.
If the notes are stale, update the handoff or plan before acting. If no safe
work item can be selected, ask one focused question and stop.

### Resuming a multi-axis review

If an active plan contains a `.js` review runner, inspect its `DATE`, `SLUG`,
`MODE`, and scope before acting. Check which axis outputs actually exist:

```bash
ls .agents/plans/YYYY-MM-DD-<slug>-*.md 2>/dev/null
```

Seed the runner's `DONE_IDS` only from confirmed axis files, then paste the
whole runner into a CodeExecution block. Use `MODE: "sequential"` when shared
resources or ordering make concurrency unsafe; use `MODE: "parallel"` only
when every axis has an independent output file and read-only review scope.
The runner itself must await all dispatched reviewers and must not aggregate
until all ten axes confirm their `FILE_WRITTEN` markers.

After `FINAL.md` exists, read it and act on its prioritized findings; do not
rerun completed axes unless the reviewed scope changed.

## 3. Implement guarded

Run autonomously through the complete cycle without pausing between ordinary
steps:

1. Restate the selected goal and acceptance checks internally.
2. Read the affected code and relevant project guidance.
3. Make the smallest coherent change.
4. Re-check the diff after each meaningful edit.
5. Avoid unrelated cleanup and never overwrite unrelated user changes.

Ask before destructive operations, broad migrations, secret changes, or an
ambiguous scope decision. Otherwise continue hands-off.

## 4. Validate

Run only the checks applicable to the detected project:

```bash
git diff --check
```

Also run the available lint, type-check, compile, test, and build commands.
Record exact commands and results. A failed check must be fixed or clearly
reported; never silently downgrade it.

For a substantial code change, use the project review skill with its complete
axis set, including Readability. For docs/config-only changes, perform a
focused correctness and consistency review.

## 5. Commit safely

When implementation and validation pass:

1. Review `git diff` and `git status`.
2. Stage only files belonging to this work item.
3. Create one Conventional Commit-style commit:
   `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `build:`, or `chore:`.
4. Do not push, publish, tag, or create a release unless explicitly requested.

If unrelated changes are already present, leave them unstaged and mention them
in the handoff.

## 6. Handoff

Before finishing:

1. Update `.agents/chats/current.md` with the next unfinished goal or an
   explicit no-active-handoff state.
2. Add or update a dated summary under `.agents/chats/YYYY/` when the session
   produced meaningful decisions or work.
3. Update plan status and durable memory only when warranted.
4. Verify the final diff, commit, and validation results one last time.

Final response format:

```text
Completed: <work item>
Validated: <commands and results>
Committed: <commit subject or not committed with reason>
Next: <next concrete item or no active handoff>
```

If a question or blocker prevented completion, report it precisely and leave a
usable handoff instead of pretending the cycle finished.