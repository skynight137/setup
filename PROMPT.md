# Task submit
```md
# Start: read in this order
- .agents/state/STATE.md   (what was in flight — pick up here first)
- .agents/plans/PLANS.md   (what's open/in-progress/done)
- .agents/memory/          (already auto-loaded, but open any link topic files relevant to this task)
- git log -20               (recent commits, for anything not yet in the above)

# Task
- 

# Before finishing
- Update .agents/state/STATE.md — clear landed entries, add a short
  handoff note if stopping mid-task
- Update .agents/plans/PLANS.md status for any plan touched
- Add/update .agents/memory/ if a durable lesson or decision came up
- Update any Docs/Skills/Memory/Plans references that changed
```


# Code Review
```md
# Perform `code-review` axes for each task
- Correctness — bugs, edge cases, incorrect assumptions
- Performance — bottlenecks, unnecessary work, inefficient patterns
- Scalability — things that break or degrade under load/growth
- Infrastructure fit — better use of what's already wired in
- Library hygiene — right tool, up to date, used per its own docs
- Security — auth/authz, injection, secret handling, webhooks, rate limiting
- Data Integrity & Concurrency — race conditions, atomicity, idempotency, dangling tasks
- Observability — enough context to debug in prod, failures surface before users report
- Maintainability — readability, complexity, naming

Write all results on .agents/plans/
```
