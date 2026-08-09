# Review delegation modes

The review runner has ten fixed axes and writes one independent Markdown file
per axis under `.agents/plans/`. The output files are the durable state that
allows another session to resume safely.

## Choose a mode

### Sequential: the safe default

Set this in the copied JS plan:

```js
const MODE = "sequential";
```

The runner awaits each reviewer before dispatching the next:

```text
axis 1 → await → axis 2 → await → ... → axis 10 → aggregate
```

Use sequential mode when:

- the repository or tool budget is shared;
- reviewers may contend for the same resources;
- the review needs predictable logs;
- a thrown dispatch error should stop at a clear boundary;
- you are unsure whether parallel execution is safe.

Sequential dispatch is not optional inside this mode. Do not create a
background job and immediately start the next axis.

### Parallel: independent read-only axes

Set this in the copied JS plan:

```js
const MODE = "parallel";
```

The runner starts all pending axes together with `Promise.allSettled`, then
checks every result:

```text
axis 1 ┐
axis 2 ├─ await all results → aggregate only if all ten confirm
...    │
axis 10┘
```

Use parallel mode only when:

- every reviewer has a read-only review scope;
- reviewers do not edit application source;
- each axis writes to its own unique output path;
- no reviewer depends on another reviewer's result;
- the available agent/tool budget can handle ten concurrent jobs.

Never use parallel mode when reviewers share a mutable output file or when one
axis must produce context for another.

## Required dispatch contract

Every axis reviewer must use:

```js
config: { $kind: "general" }
```

Do not use an explore reviewer for an axis that must write a findings file.
Explore reviewers are read-only and can return useful chat findings while
silently failing the file-based review contract.

Each reviewer must:

1. read complete relevant files, not only diff hunks;
2. focus only on its assigned axis;
3. write to its exact `.agents/plans/` output path;
4. end with `FILE_WRITTEN: <exact-path>` only after writing the file.

The runner verifies the marker in the returned text. A missing marker is an
unresolved axis, not a successful one. The final aggregation must not run until
all ten markers are confirmed.

## Cross-session resume

Before rerunning a plan, check the durable output files from the shell:

```bash
ls .agents/plans/YYYY-MM-DD-<slug>-*.md 2>/dev/null
```

Put only the confirmed axis IDs into the copied plan's `DONE_IDS` array:

```js
const DONE_IDS = [
  "01-correctness",
  "02-performance",
];
```

Then paste the complete JS file into a CodeExecution block. The runner skips
those axes and continues with the first missing axis. Do not use an in-script
filesystem loop to infer completion, and do not mark an axis complete from a
chat message without its output file and confirmation marker.

After `YYYY-MM-DD-<slug>-FINAL.md` exists, read it in the next session and act
on its prioritized findings. Do not rerun completed axes unless the review
scope changed.