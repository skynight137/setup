---
id: code-review-axes
name: code-review-axes
kind: skill
category: review
tags: [code-review, review-axes, readability, resumable, delegation]
reusable: true
enabled: false
description: >-
  Use when reviewing, auditing, or sweeping a commit range, feature, module,
  or working tree and the result must be complete, actionable, and resumable.
---

# Code Review Axes

Use this skill for a structured review that produces durable plan files rather
than a chat-only opinion. It is designed for a portable `.agents` vault that
can be copied into another project without touching application code.

## Fixed review axes

Run all ten axes, including axes with no findings:

| # | Axis | Focus |
|---|---|---|
| 1 | Correctness | Bugs, edge cases, incorrect assumptions, regressions |
| 2 | Performance | Bottlenecks, unnecessary work, latency, memory, hot paths |
| 3 | Scalability | Failure or degradation under growth, concurrency, larger inputs |
| 4 | Infrastructure fit | Existing project wiring, boundaries, operations |
| 5 | Library hygiene | Dependencies, supported APIs, versions, usage |
| 6 | Security | Input handling, auth, secrets, injection, SSRF, XSS, abuse |
| 7 | Data integrity and concurrency | Atomicity, idempotency, races, ordering, retries |
| 8 | Observability | Logs, metrics, traces, alerts, diagnostics, failure visibility |
| 9 | Maintainability | Coupling, cohesion, change risk, duplication, architecture |
| 10 | Readability | Naming, control flow, local comprehension, cognitive load |

Keep Maintainability and Readability separate:

- **Maintainability:** whether future changes are safe and localized.
- **Readability:** whether a developer can understand the current behavior
  without reconstructing hidden intent.

Every finding records:

- what is wrong;
- file and line or symbol;
- why it matters;
- recommended fix;
- severity: `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`.

An empty axis is a completed result. Say explicitly that no findings were
found and include the reviewed scope.

## Establish scope before dispatch

1. Read `.agents/chats/current.md`, when present.
2. Read relevant active or reference plans.
3. Inspect the current checkout and recent commits.
4. Determine the review range or working-tree scope.
5. Read project rules and memory topics relevant to the changed files.

Verify saved handoffs against the current checkout. Never trust a stale branch,
file, commit, or validation claim.

## Use the reusable JS plan

Copy `scripts/review-plan.template.js` to:

```text
.agents/plans/YYYY-MM-DD-<slug>.js
```

Fill in `DATE`, `SLUG`, `PROJECT_CONTEXT`, and the scope/file excerpts. Set:

```js
const MODE = "sequential"; // or "parallel"
```

### Sequential mode

Use when reviewers may compete for shared resources, the repository is large,
or easier-to-follow logs matter more than wall-clock time. The script awaits
one axis before dispatching the next. A thrown dispatch error stops the pass;
resume later from the first missing axis.

### Parallel mode

Use when each axis can independently read the checkout and write its own
distinct output file. The script starts all pending axes with
`Promise.allSettled` and waits for every result while preserving per-axis
failures. Never use parallel mode if reviewers would edit the same source files
or share a mutable output file.

Both modes:

- use `config: { $kind: "general" }`, because reviewers must write files;
- write one file per axis;
- require `FILE_WRITTEN: <exact-path>` as the completion marker;
- treat a missing marker as unresolved, not successful;
- run aggregation only after all ten axes confirm;
- use `DONE_IDS` seeded from a shell `ls` when resuming across sessions.

Before each resume, run:

```bash
ls .agents/plans/YYYY-MM-DD-<slug>-*.md 2>/dev/null
```

Then put only confirmed axis IDs in `DONE_IDS`. Do not infer completion from
chat text alone.

## Output convention

Keep plan files flat:

```text
YYYY-MM-DD-<slug>-01-correctness.md
...
YYYY-MM-DD-<slug>-10-readability.md
YYYY-MM-DD-<slug>-FINAL.md
```

Each axis file uses:

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
```

The final report is a plan artifact. It deduplicates findings, sorts the
master table by severity, groups prioritized work items, and gives the next
agent enough context to act. It does not change application code.

## Portable vault installation

This skill documents review execution only. For copying the complete `.agents`
vault into another project, read
`.agents/docs/portable-install.md`. For choosing sequential or parallel
reviewer dispatch, read
`references/delegation-modes.md`.

## Final validation

After a review pass:

1. Verify all ten axis files and the final report exist.
2. Check frontmatter and relative links.
3. Run applicable tests, lint, type checks, compilation, and build.
4. Run `git diff --check`.
5. Update the session handoff and only durable memory.
6. Do not claim approval while unresolved `CRITICAL` or `HIGH` findings remain.

Keep generated indexes, graph output, caches, and dispatcher scratch files
outside source-of-truth documents or under an ignored generated directory.