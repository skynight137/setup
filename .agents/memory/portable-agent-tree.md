---
name: Portable agent tree
description: Durable rules for keeping the shared agent setup portable across projects and runtimes.
---

Shared agent content must remain owner-scoped and portable. The portable unit
is `.agents/`, while temporary source checkouts belong outside the project
tree.

**Why:** The setup is copied into unrelated projects, so runtime paths,
credentials, integrations, and session state create privacy leaks and make the
copied structure unreliable.

**How to apply:** Add reusable content under the category/owner layout. Keep
plans, chats, memory, docs, and scripts project-local. If a public source is
temporarily unavailable, skip that source with a visible warning instead of
discarding successful updates from other sources.

When synchronizing a repository that has both registry metadata and installable
packages, map the package directory into `plugins/<owner>`; registry metadata
alone is not the plugin content.

Reusable review runners should write isolated, uniquely named plan files and
keep project-local chats, plans, and memory outside the additive install.

**Why:** A base vault must improve another project's agent behavior without
silently replacing that project's operating history or causing parallel
reviewers to contend for the same output file.

**How to apply:** Preview `rsync --ignore-existing` before copying reusable
content. Use sequential review dispatch when resources or ordering are shared;
use parallel dispatch only for independent read-only axes with distinct outputs.