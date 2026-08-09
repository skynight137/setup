# Portable agent setup

This directory is a provider-neutral agent workspace. Copy `.agents/` into
another project to reuse the same agents, skills, commands, rules, hooks,
plans, chats, and documentation.

## Layout

```text
.agents/
├── agents/<owner>/     # specialized subagents
├── skills/<owner>/     # reusable workflows loaded on demand
├── commands/<owner>/   # maintained command shims
├── rules/<owner>/      # opt-in project and language standards
├── hooks/<owner>/      # runtime automation and enforcement
├── scripts/            # setup, repair, sync, orchestration, and checks
├── docs/               # setup and operating guides
├── plans/              # project plans
├── chats/              # conversation notes
└── memory/             # durable lessons and decisions
```

The updater intentionally does not create provider-specific directories,
credentials, integrations, or runtime state. A project can use any compatible
agent runtime without changing this layout. Optional public sources that are
unavailable are reported and skipped so the other sources can still update.

## Copy to a project

From this repository:

```bash
git clone <setup-repository-url> /tmp/agent-setup
rsync -a /tmp/agent-setup/.agents/ /path/to/project/.agents/
```

The `.agents/` directory is the portable unit. Copying it does not require
copying the setup repository's application files.

## Update shared content

Run from any project that contains this setup:

```bash
.agents/scripts/updater.sh
```

The script discovers the project root from its own location, checks out public
source repositories in `/tmp/agent-sources`, and synchronizes their content
into the owner/category directories above. Override the temporary checkout
location when needed:

```bash
AGENTS_SOURCE_ROOT=/tmp/my-agent-sources .agents/scripts/updater.sh
```

Source-owned directories are mirrored with `rsync --delete`; local changes in
those directories should be made upstream or kept outside the synchronized
owner directory. Project-local plans, chats, memory, docs, and scripts are not
managed by the updater.

## Requirements

- `bash`
- `git`
- `rsync`
- network access when a source repository is not already cached