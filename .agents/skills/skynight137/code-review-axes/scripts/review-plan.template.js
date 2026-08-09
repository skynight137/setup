// =====================================================================
// PLAN: .agents/plans/YYYY-MM-DD-<SLUG>.js
//
// Copy this file to .agents/plans/YYYY-MM-DD-<slug>.js and fill in:
//   DATE, SLUG, PROJECT_CONTEXT, MODE, and the review scope.
//
// MODE:
//   "sequential" — await each axis before starting the next.
//   "parallel"   — start all pending axes together; output paths are unique.
//
// RESUME:
//   ls .agents/plans/YYYY-MM-DD-<slug>-*.md 2>/dev/null
//   Put completed axis IDs in DONE_IDS, then paste this whole file into a
//   CodeExecution block. Do not use filesystem checks inside this script.
// =====================================================================

const WORKSPACE = "/home/runner/workspace";
const PLAN_DIR = `${WORKSPACE}/.agents/plans`;
const DATE = "YYYY-MM-DD"; // set this
const SLUG = "<slug>"; // e.g. "rss-hardening"
const MODE = "sequential"; // "sequential" or "parallel"
const DONE_IDS = []; // e.g. ["01-correctness", "02-performance"]
const FINAL_DONE = false; // set true only after FINAL.md is confirmed

const PROJECT_CONTEXT = `
## Project Context
Stack: <language, framework, database, runtime, test/lint commands>
Branch or review range: <branch and commit range, or working tree>
Relevant memory:
  .agents/memory/MEMORY.md
Scope and changed files:
  <paste git diff --stat output and the relevant file list here>
`;

const AXES = [
  ["01-correctness", "Correctness", "bugs, edge cases, incorrect assumptions, regressions"],
  ["02-performance", "Performance", "bottlenecks, unnecessary work, latency, memory, hot paths"],
  ["03-scalability", "Scalability", "failure or degradation under growth, concurrency, larger inputs"],
  ["04-infra-fit", "Infrastructure fit", "existing project wiring, boundaries, and operations"],
  ["05-library-hygiene", "Library hygiene", "dependencies, supported APIs, versions, and usage"],
  ["06-security", "Security", "input handling, auth, secrets, injection, SSRF, XSS, abuse"],
  ["07-data-concurrency", "Data integrity and concurrency", "atomicity, idempotency, races, ordering, retries"],
  ["08-observability", "Observability", "logs, metrics, traces, alerts, diagnostics, failure visibility"],
  ["09-maintainability", "Maintainability", "coupling, cohesion, change risk, duplication, architecture"],
  ["10-readability", "Readability", "naming, control flow, local comprehension, cognitive load"],
];

const doneSet = new Set(DONE_IDS);
const tasks = AXES.map(([id, name, focus]) => {
  const out = `${PLAN_DIR}/${DATE}-${SLUG}-${id}.md`;
  return {
    id,
    out,
    name: `${SLUG}-${id}`,
    task: `${PROJECT_CONTEXT}
## Assigned axis: ${name}
Focus only on: ${focus}.

Read the complete relevant files, not only diff hunks. Do not modify application
source. Write your complete findings to this exact path:
${out}

Use this frontmatter and table shape:
---
id: ${DATE}-${SLUG}-${id}
name: ${SLUG} — ${name} findings
kind: plan
category: review
status: done
reusable: false
description: Findings from the ${name} review.
tags: [code-review, ${id.replace(/^\\d+-/, "")}]
---

**Scope:** <the exact scope reviewed>
**Axis:** ${name}

| ID | Severity | Location | Finding | Why it matters | Recommended fix | Status |
|---|---|---|---|---|---|---|

An empty result is valid, but state that no findings were found and identify the
reviewed scope. Every finding must include what is wrong, location, impact,
recommended fix, and severity: CRITICAL, HIGH, MEDIUM, or LOW.

After actually writing the file with WriteFile, end your response with exactly:
FILE_WRITTEN: ${out}
Do not include that marker unless the file exists.`,
  };
});

function confirmed(result, out) {
  return (result?.text ?? "").includes(`FILE_WRITTEN: ${out}`);
}

function reportResult(task, result) {
  const text = result?.text ?? "";
  console.log(text || `(no response from ${task.id})`);
  if (confirmed(result, task.out)) {
    doneSet.add(task.id);
    console.log(`✓ ${task.id} confirmed: ${task.out}`);
    return { id: task.id, ok: true };
  }
  console.log(`⚠ ${task.id} unresolved: missing FILE_WRITTEN marker`);
  return { id: task.id, ok: false, reason: "missing FILE_WRITTEN marker" };
}

async function dispatch(task) {
  return subagent({
    name: task.name,
    task: task.task,
    config: { $kind: "general" },
  });
}

console.log(`Review: ${DATE}-${SLUG}`);
console.log(`Mode: ${MODE}`);
console.log(`Already confirmed: ${doneSet.size}/${tasks.length}`);

const pending = tasks.filter((task) => !doneSet.has(task.id));
const unresolved = [];
let stoppedOn = null;

if (MODE === "parallel") {
  // Safe only because every task has a unique output path and reviewers do not
  // edit application source. allSettled lets independent axes report failures.
  const results = await Promise.allSettled(pending.map(dispatch));
  results.forEach((settled, index) => {
    const task = pending[index];
    if (settled.status === "fulfilled") {
      const result = reportResult(task, settled.value);
      if (!result.ok) unresolved.push(result);
    } else {
      unresolved.push({ id: task.id, reason: String(settled.reason) });
      console.log(`✗ ${task.id} threw: ${String(settled.reason)}`);
    }
  });
} else if (MODE === "sequential") {
  for (const task of pending) {
    console.log(`Dispatching ${task.id} sequentially...`);
    try {
      const result = reportResult(task, await dispatch(task));
      if (!result.ok) unresolved.push(result);
    } catch (error) {
      stoppedOn = task.id;
      console.log(`✗ ${task.id} threw: ${error?.message ?? error}`);
      console.log("Stopping. Re-check DONE_IDS and paste this plan to resume.");
      break;
    }
  }
} else {
  throw new Error(`MODE must be "sequential" or "parallel", got: ${MODE}`);
}

if (stoppedOn) {
  console.log(`Stopped on ${stoppedOn}; no FINAL aggregation will run.`);
} else if (unresolved.length) {
  console.log("Unresolved axes:");
  unresolved.forEach(({ id, reason }) => console.log(`- ${id}: ${reason}`));
  console.log("Fix the cause or independently confirm files, then resume.");
} else if (doneSet.size === tasks.length && !FINAL_DONE) {
  const finalOut = `${PLAN_DIR}/${DATE}-${SLUG}-FINAL.md`;
  const summary = await subagent({
    name: `${SLUG}-summary`,
    task: `You are aggregating a ten-axis code review.

Read all ten source files:
${tasks.map((task) => `- ${task.out}`).join("\n")}

Write a deduplicated final report to ${finalOut}. Sort the master findings table
by severity, group concrete priority work items, and include context for the
next agent. Use valid frontmatter:
---
id: ${DATE}-${SLUG}-FINAL
name: ${SLUG} — final review
kind: plan
category: review
status: done
reusable: false
description: Merged outcome of the ten-axis ${SLUG} review.
tags: [code-review]
---

After actually writing the file with WriteFile, end your response with exactly:
FILE_WRITTEN: ${finalOut}`,
    config: { $kind: "general" },
  });
  if (confirmed(summary, finalOut)) {
    console.log(`✓ Final aggregation confirmed: ${finalOut}`);
  } else {
    console.log(`⚠ Final aggregation unresolved: missing FILE_WRITTEN marker`);
  }
} else if (FINAL_DONE) {
  console.log("All ten axes and FINAL.md are already confirmed.");
}