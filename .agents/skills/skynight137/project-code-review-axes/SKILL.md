---
id: project-code-review-axes
name: Project Code Review Axes
kind: skill
category: review
tags: [project, code-review, review-axes, readability]
reusable: true
enabled: false
description: >-
  Use for structured review of a commit range, feature, module, or working tree.
  Review ten fixed quality axes, keep findings resumable in plans, and finish
  with an aggregate report that another agent can act on.
---

# Project Code Review Axes

Use this skill when reviewing, auditing, or sweeping a change, feature, module,
or commit range. The review is a technical record, not a chat-only opinion:
write each axis result into `.agents/plans/`, then write one aggregate report.

## Fixed review axes

Always run every axis, even when an axis has no findings:

| # | Axis | Focus |
|---|---|---|
| 1 | Correctness | Bugs, edge cases, incorrect assumptions, and behavior regressions |
| 2 | Performance | Bottlenecks, unnecessary work, latency, memory, and hot paths |
| 3 | Scalability | Failure or degradation under growth, concurrency, or larger inputs |
| 4 | Infrastructure fit | Better use of existing project wiring, boundaries, and operations |
| 5 | Library hygiene | Appropriate dependencies, supported APIs, versions, and usage |
| 6 | Security | Input handling, auth, secrets, injection, SSRF, XSS, and abuse paths |
| 7 | Data integrity and concurrency | Atomicity, idempotency, races, ordering, retries, and dangling work |
| 8 | Observability | Logs, metrics, traces, alerts, diagnostics, and failure visibility |
| 9 | Maintainability | Coupling, cohesion, change risk, duplication, and architectural clarity |
| 10 | Readability | Naming, control flow, local comprehension, comments, and cognitive load |

Maintainability asks whether future changes are safe and localized. Readability
asks whether a developer can understand the code correctly without reconstructing
hidden intent. Keep those findings separate.

For every finding, record:

- What is wrong.
- Where it is, with a file and line or symbol.
- Why it matters.
- The recommended fix.
- Severity: `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`.

## Review lifecycle

### 1. Establish scope

Before dispatching reviewers:

1. Read `.agents/chats/current.md` when it exists.
2. Read relevant active or reference plans.
3. Inspect the current checkout and recent commits.
4. Determine the review range or working-tree scope.
5. Read the project rules and memory topics relevant to the changed files.

Do not trust a saved handoff blindly. Verify referenced files, branches,
commits, and claimed validation against the current checkout.

### 2. Dispatch sequentially

Use one write-capable reviewer per axis. Dispatch reviewers sequentially and
await each result before starting the next. Do not launch the same axis twice.

Each reviewer must:

- Read the complete relevant files, not only diff hunks.
- Focus only on its assigned axis.
- Write a Markdown findings file directly under `.agents/plans/`.
- End its response with `FILE_WRITTEN: <exact-path>` only after the file exists.

The dispatcher must treat a missing confirmation as an unresolved soft failure:
continue with the remaining axes, but do not aggregate until every axis is
confirmed. A thrown dispatch error may stop the pass when it indicates a
systemic failure.

### 3. Resume safely

Axis files use this naming convention:

```text
YYYY-MM-DD-<slug>-01-correctness.md
YYYY-MM-DD-<slug>-02-performance.md
...
YYYY-MM-DD-<slug>-10-readability.md
YYYY-MM-DD-<slug>-FINAL.md
```

Before resuming, list the matching plan files and seed the completed-axis set
from files that are present. Never mark an axis complete from a log message
alone; confirm the file and its required structure.

### 4. Aggregate

Only after all ten axis files are present:

1. Read every axis file.
2. Deduplicate overlapping findings without losing the strongest evidence.
3. Sort the master table by severity.
4. Group recommended work into prioritized fix items.
5. Add a context section for the next agent.
6. Write the `-FINAL.md` report under `.agents/plans/`.

The aggregate is a plan artifact. It does not itself change application code.

## Findings file format

Each axis file should use:

```md
---
id: YYYY-MM-DD-<slug>-<axis>
name: <slug> — <axis> findings
kind: plan
category: review
status: done
reusable: false
description: Findings from the <axis> review.
tags: [code-review, <axis-tag>]
---

**Scope:** <commit range, feature, module, or working tree>
**Axis:** <axis name>

| ID | Severity | Location | Finding | Why it matters | Recommended fix | Status |
|---|---|---|---|---|---|---|

## Notes

<Important context, reviewed files, and explicitly empty checks.>
```

An empty axis is still a completed result. State that no findings were found
and include the reviewed scope.

## Final validation

After the review report is written, the acting agent should:

1. Verify every axis file and the aggregate exist.
2. Check frontmatter and links.
3. Run the project's applicable tests, lint, type checks, compilation, and build.
4. Run `git diff --check`.
5. Update relevant plans, memory, and the session handoff.
6. Do not claim approval when unresolved `CRITICAL` or `HIGH` findings remain.

Keep generated indexes, graph output, caches, and temporary dispatcher files
outside the source-of-truth documents or under an ignored generated directory.