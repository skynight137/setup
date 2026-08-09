# Portable agent knowledge vault

`.agents/` is a Git-backed, Markdown-first knowledge vault and reusable
automation tree. Copy it into another project when you want the same operating
conventions, reusable content, and cross-session continuity.

## Layout

```text
.agents/
├── agents/<owner>/       # specialized subagents
├── skills/<owner>/       # reusable workflows
├── commands/<owner>/     # maintained command shims
├── rules/<owner>/        # opt-in standards
├── hooks/<owner>/        # runtime automation
├── plugins/<owner>/      # installable plugin packages and manifests
├── tools/                # vault and graph utilities
├── scripts/              # setup, repair, sync, and checks
├── docs/                 # architecture and operating guides
├── chats/                # conversation continuity and handoffs
├── plans/                # findings, designs, and work records
└── memory/               # reviewed durable lessons
```

## Collections

Choose the collection before writing a document:

| Collection | Lifecycle | Use |
|---|---|---|
| `chats/` | short-lived continuity | concise summaries and the next-session handoff |
| `memory/` | long-lived knowledge | reviewed lessons, decisions, and constraints |
| `plans/` | work records | investigations, designs, and implementation history |
| `skills/` | reusable guidance | safe actions and operating procedures |

Markdown remains the source of truth. Indexes, graph JSON, DOT, and HTML views
are derived artifacts and may be regenerated or deleted.

## Frontmatter and links

Use YAML frontmatter for identity and indexing metadata:

```yaml
---
id: stable-slug
kind: memory | plan | skill | chat
category: review | design | action | architecture | module | process | tooling
tags: [lowercase, hyphenated]
reusable: true | false
---
```

Plans additionally use `status`; skills additionally use `enabled`. Use
relative Markdown links or `[[wikilinks]]` for relationships. Keep secrets,
credentials, tokens, private user data, and large logs out of the vault.

## Copy to another project

The complete `.agents/` directory is the portable unit. Use the additive,
manual installation procedure in
[portable-install.md](portable-install.md). It previews the full vault,
preserves the target project's `chats/`, `plans/`, and `memory/`, and never
touches application source outside `.agents/`.

## Refresh reusable content

```bash
.agents/scripts/updater.sh
```

The updater refreshes public source checkouts in `/tmp/agent-sources`, mirrors
their mapped content into owner directories, and mirrors the two local skill
collections into the local skill mirror. Every `.fingerprint` file is
excluded.

Override the temporary checkout directory when needed:

```bash
AGENTS_SOURCE_ROOT=/tmp/my-agent-sources .agents/scripts/updater.sh
```

Source-owned directories are mirrored with deletion enabled. Keep local
changes in `chats/`, `plans/`, `memory/`, `docs/`, and `tools/`; do not edit
source-owned mirrors directly.

## Graph workflow

Generate a Markdown relationship graph on demand:

```bash
python .agents/tools/markdown_graph.py \
  --root .agents \
  --output .agents/.generated/markdown-graph.json \
  --dot-output .agents/.generated/markdown-graph.dot
```

Open `.agents/` as a vault in a Markdown graph application for interactive
backlinks and graph view. The generated graph is useful for scripts and static
views, but it is not a second source of truth.