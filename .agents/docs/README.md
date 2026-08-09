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

```bash
git clone <base-vault-repository-url> /tmp/agent-vault-base
```

The `.agents/` directory is the portable unit. Project-specific source code
and application files are not required. Copy only into the target project's
`.agents/` directory; never rsync the base repository into the project root.

For a non-destructive manual install into a project that already has a vault,
preview an additive copy and preserve existing files:

```bash
rsync -a --dry-run --itemize-changes --ignore-existing \
  /tmp/agent-vault-base/.agents/skills/skynight137/code-review-axes/ \
  /path/to/project/.agents/skills/skynight137/code-review-axes/

# Remove --dry-run only after reviewing the preview.
```

To add all reusable vault areas without replacing project-local continuity:

```bash
for area in agents commands docs hooks plugins rules scripts skills tools; do
  rsync -a --ignore-existing \
    "/tmp/agent-vault-base/.agents/$area/" \
    "/path/to/project/.agents/$area/"
done
```

Do not add `--delete`, and do not use a plain overwrite sync when the target
already has an `.agents/` vault. `--ignore-existing` prevents replacing an
existing target file; the dry run makes new and skipped paths visible before
writing.

Do not copy into the project root, and do not automatically replace the target
project's `chats/`, `plans/`, or `memory/`. Merge those directories manually
only when their contents are intentionally portable. If an older skill path
exists, install the new path beside it, verify references, and remove the old
path manually.

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