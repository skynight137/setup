# Agent setup architecture

## Ownership

Shared content is grouped first by capability and then by source owner:

```text
.agents/<category>/<owner>/
```

This prevents source repositories from overwriting one another and makes it
clear where an update came from. The updater contains an explicit mapping for
each public source rather than guessing from repository contents.

## Synchronization model

1. Resolve the project root relative to `scripts/updater.sh`.
2. Clone or refresh each configured public source in a temporary directory.
3. Mirror only the mapped source directories into `.agents/`.
4. Leave project-local operating material untouched.

The temporary clones are disposable. The checked-in `.agents/` tree is the
portable output and can be copied to another repository without source git
metadata or credentials.

## Project-local material

`plans/`, `chats/`, `memory/`, `docs/`, and `scripts/` belong to the project
using the setup. Do not put temporary session state in the tree. If a detail
is short-lived, keep it in the active conversation or current plan; if it is
a durable lesson, record it in `memory/`.

## Privacy and portability

The setup has no provider-specific runtime dependency, secret, integration, or
environment-variable requirement. Source URLs are public repository URLs, and
the updater does not read credentials from the project or write them into
`.agents/`.