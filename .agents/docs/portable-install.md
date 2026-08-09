# Installing the portable `.agents` vault

The portable unit is the complete `.agents/` directory. Do not copy the
repository root, application source, `.git/`, or project secrets.

## 1. Get the base vault outside the target project

```bash
git clone <base-vault-repository-url> /tmp/agent-vault-base
```

Use a temporary directory for the checkout. It is only the source for the
manual copy.

## 2. Preview an additive install

Run this from any shell. Replace `/path/to/target-project` with the project
that should receive the vault:

```bash
rsync -a --dry-run --itemize-changes --ignore-existing \
  --exclude='.git/' \
  --exclude='chats/' \
  --exclude='plans/' \
  --exclude='memory/' \
  /tmp/agent-vault-base/.agents/ \
  /path/to/target-project/.agents/
```

This copies the base vault's reusable agents, commands, skills, rules, hooks,
plugins, tools, docs, and scripts while preserving project-local continuity.

Review the preview before writing. The target is inside `.agents/`; application
files outside `.agents/` are not touched.

## 3. Apply the copy manually

When the preview is correct, remove only `--dry-run`:

```bash
rsync -a --itemize-changes --ignore-existing \
  --exclude='.git/' \
  --exclude='chats/' \
  --exclude='plans/' \
  --exclude='memory/' \
  /tmp/agent-vault-base/.agents/ \
  /path/to/target-project/.agents/
```

`--ignore-existing` means an existing target file is not replaced. New files
are added. If an existing file needs an update, compare it manually first:

```bash
diff -u \
  /path/to/target-project/.agents/path/to/file \
  /tmp/agent-vault-base/.agents/path/to/file
```

Apply only the intended hunk or edit the target manually. Do not change
application source as part of vault installation.

## 4. Check the result

```bash
git -C /path/to/target-project status --short -- .agents
find /path/to/target-project/.agents -maxdepth 3 -type f | sort
```

The target project's `chats/`, `plans/`, and `memory/` remain its own history.
Only merge those directories when their contents are intentionally portable.

## Important safety rules

- Do not use `--delete` for installation.
- Do not use a plain overwrite sync against an existing project vault.
- Do not copy the base repository into the project root.
- Do not copy secrets, credentials, `.env` files, or runtime state.
- The updater script is for refreshing configured source-owned mirrors; it is
  not a replacement for this additive installation procedure.

## After installation

Start a new work session in the target project with:

```text
/skynight137/fresh-session
```

For a review that may span sessions, use the review skill's template:

```text
.agents/skills/skynight137/code-review-axes/scripts/review-plan.template.js
```

Read its delegation reference before choosing a mode:

```text
.agents/skills/skynight137/code-review-axes/references/delegation-modes.md
```