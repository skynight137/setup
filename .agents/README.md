# `.agents` vault

This directory combines reusable agent content with project knowledge that
must survive across sessions.

Read these in order when continuing work:

1. `.agents/chats/current.md`
2. the relevant files in `.agents/plans/`
3. linked files in `.agents/memory/`
4. the source code and current version-control status

Use `chats/` for provenance and handoffs, `plans/` for work records, `memory/`
for reviewed durable lessons, and `skills/` for reusable operating guidance.
Do not recreate an ephemeral state directory.

See `.agents/docs/README.md` for the full vault contract.

To install this complete vault into another project without replacing its
existing agent history, read `.agents/docs/portable-install.md`.