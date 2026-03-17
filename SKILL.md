---
name: shark
slug: shark
version: 0.1.0
summary: "The Shark Pattern — non-blocking agent execution. Spawn sub-sharks for slow tools, keep the main agent swimming. A shark that stops swimming dies."
tags: [async, performance, subagents, non-blocking, concurrency, patterns]
homepage: https://github.com/keugenek/shark-pattern
author: keugenek
---

# 🦈 The Shark Pattern

> *A shark that stops swimming dies. An agent that waits for tools wastes compute.*

## When to Use This Skill

Trigger this skill when the user says:
- "use the shark pattern"
- "non-blocking agent"
- "never wait for tools"
- "spawn background workers"
- "parallel subagents"
- "keep the main agent moving"
- or when you notice you're about to block on a slow tool (web fetch, SSH, build, test run, API call)

## The Rule

**Every LLM turn must complete in under 30 seconds.**

If any operation would take longer:
1. Spawn a sub-shark (`sessions_spawn` with `mode: "run"`)
2. Continue reasoning immediately
3. Incorporate sub-shark results when they arrive

You are **never** in I/O wait. You are **always** reasoning about something.

## The Pattern

### Bad (Ralph-style blocking):
```
think → call slow tool → WAIT 60s → think → call slow tool → WAIT 45s → ...
```

### Good (Shark-style non-blocking):
```
think → spawn sub-shark(slow tool) → think about something else
     → spawn sub-shark(another tool) → synthesize partial results
     → receive sub-shark result → incorporate → swim on
```

## Implementation

When applying the Shark Pattern, structure your work like this:

### 1. Identify blocking operations
Before calling any tool, ask: "Will this take more than 20-30 seconds?"

Slow tools (always spawn):
- Web searches / page fetches
- SSH commands on remote machines
- Build / test / CI runs
- File system scans over large directories
- API calls with unknown latency
- LLM inference calls (coding agents)

Fast tools (run inline, never spawn):
- Reading local files
- Simple calculations
- String manipulation
- Memory lookups

### 2. Spawn sub-sharks

```
sessions_spawn({
  task: "Do the slow thing and return the result",
  mode: "run",
  runtime: "subagent",
  streamTo: "parent"  // optional: stream output back
})
```

Spawn multiple sub-sharks in parallel when possible — don't serialize unless there's a data dependency.

### 3. Keep the main fin moving

After spawning, immediately continue:
- Plan the next step
- Work on a different part of the task
- Summarize what you know so far
- Prepare to incorporate results

### 4. Incorporate results

When sub-shark results arrive, weave them in and continue. Never re-do work a sub-shark already completed.

## Timing Budget

| Operation | Budget | Action |
|-----------|--------|--------|
| File read | < 2s | Inline |
| Web search | 5-30s | Spawn |
| SSH command | 10-120s | Spawn |
| Build/test | 30-300s | Spawn |
| Coding agent | 60-600s | Spawn |
| Memory search | < 3s | Inline |

## Example: Multi-Step Research Task

**Without Shark (blocking):**
```
1. Search web for X        [wait 15s]
2. Search web for Y        [wait 12s]  
3. Fetch page Z            [wait 8s]
4. SSH check server        [wait 30s]
Total: ~65 seconds blocked
```

**With Shark (non-blocking):**
```
1. Spawn: search X         [0s - spawned]
2. Spawn: search Y         [0s - spawned]
3. Spawn: fetch Z          [0s - spawned]
4. Spawn: SSH check        [0s - spawned]
5. Plan synthesis while waiting [15s of actual thinking]
6. All results arrive → synthesize
Total: ~15s of thinking + max(tool times) in parallel
```

## Output Format

When you apply the Shark Pattern, briefly announce it:

> 🦈 **Shark mode** — spawning [N] sub-sharks for [tasks], continuing...

Then proceed immediately without waiting.

## Hard Limits

- **Never** use `yieldMs` > 30000 in exec calls
- **Never** call `process(action=poll, timeout > 20000)` in the main session
- **Never** add `sleep` or wait loops in the main thread
- **Always** spawn for operations with unknown or high latency
- **Max** 8 concurrent sub-sharks (avoid context explosion)

## References

- Ralph Loop (sequential baseline): ghuntley.com/ralph/
- OpenClaw sessions_spawn docs: spawn with `mode: "run"`, `runtime: "subagent"`
- The name: sharks use ram ventilation — they literally die if they stop moving
