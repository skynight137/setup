# Conversation archive

Keep concise, searchable summaries of important work and decisions that need
to survive into a later session. Archive summaries, not raw transcripts,
tool output, secrets, credentials, tokens, private user data, or large logs.

## Files

- `index.md` — chronological list of archived conversations.
- `current.md` — short handoff for the next session.
- `YYYY/YYYY-MM-DD-topic.md` — one summary per substantial work session.

## Entry format

Each entry should record:

1. The goal.
2. Important decisions and constraints.
3. Work completed and affected areas.
4. Verification performed.
5. Remaining work and the next recommended action.

When a detail becomes durable engineering knowledge, move it to
`.agents/memory/` instead of repeating it here.

## Session workflow

At the start of a session, read `current.md` and verify it against the current
project state. At the end, archive the session, update `index.md`, and set
`current.md` to the next unfinished goal or an explicit no-active-handoff
state.