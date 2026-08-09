# Plans

Plans contain investigations, designs, findings, implementation records, and
historical decisions that explain why the project is shaped as it is.

Use YAML frontmatter for machine-readable identity:

```yaml
---
id: stable-slug
kind: plan
category: review | design | action | architecture | tooling
reusable: false
name: Human-readable identity
status: todo | in-progress | blocked | done | reference
description: One-sentence purpose
tags: [lowercase, hyphenated]
---
```

Do not use a handwritten plan index as a second source of truth. Tools may
derive indexes from frontmatter when a dashboard or static view needs one.