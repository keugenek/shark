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

### Announce on start
> 🦈 **Shark mode** — spawning [N] sub-sharks for [tasks], continuing...

### Progress bar (chat-friendly, Unicode only — no images needed)

Use this format after each sub-shark or pilot fish completes. Works in Telegram, Discord, Signal, iMessage — anywhere.

```
🦈 3 sub-sharks · 1 pilot fish

◉ [A] task name here    ████████████ ✅ 9s
◉ [B] task name here    ████████████ ✅ 33s
○ [C] task name here    ░░░░░░░░░░░░ pending
◈ [P] Pilot fish        ██████░░░░░░ ~14s left

↳ continuing...
```

**Symbols:**
- `◉` = sub-shark (completed)
- `○` = sub-shark (pending)
- `⊙` = sub-shark (running)
- `◈` = pilot fish (time-bounded)
- `████████████` = done bar (12 blocks)
- `██████░░░░░░` = partial (filled = elapsed / total budget)
- `░░░░░░░░░░░░` = not started

**Progress fill:** `filled = round(elapsed / timeout * 12)` blocks of `█`, remainder `░`

Only post an update when something changes (sub-shark completes or pilot fish starts/ends). Don't spam — one update per event.

### Final synthesis
After all sub-sharks done:
> 🦈 **All fins in** — synthesising [N] results + pilot draft

Then deliver the report.

## The Pilot Fish Sub-Pattern

> *Pilot fish swim alongside sharks doing prep work. When you have idle time, use it.*

When one sub-shark returns early and others are still running:

1. **Spawn a pilot fish** — a time-bounded analysis sub-agent
2. **Give it only the partial results so far** + a hard timeout equal to the estimated remaining wait
3. **Let it pre-validate, pre-analyse, find patterns, draft conclusions**
4. **Kill it** (or it self-terminates) when the last primary sub-shark completes
5. **Incorporate** whatever the pilot fish produced into the final synthesis

```
sub-shark A ──────► result (early)
sub-shark B ────────────────────────────► result
sub-shark C ──────────────────────────────────► result

main:   spawn A, B, C
        A done → spawn pilot-fish(A's result, timeout=est_remaining)
        pilot-fish: pre-analyse A, draft partial report, validate data...
        B done → pilot-fish still running, feed B's result in (or kill+reuse)
        C done → kill pilot-fish, synthesise A+B+C+pilot-fish draft
```

### Pilot Fish Rules

- **Always time-bounded** — pass `runTimeoutSeconds` equal to estimated remaining wait
- **Never blocks** — spawned async, main agent continues
- **Opportunistic** — if it finishes early, bonus; if killed mid-run, partial output is still useful
- **One at a time** — don't stack pilot fish on pilot fish
- **Task:** pre-validate data, find gaps, draft structure, flag anomalies, prepare questions

### Example

```
// Sub-sharks A (fast) and B (slow) both spawned
// A finishes in 10s, B will take another 30s

// Spawn pilot fish with 25s budget:
sessions_spawn({
  task: "Pre-analyse these results from sub-shark A. 
         Validate the data, note any gaps, draft the structure 
         of the final report. Stop after 25 seconds.",
  runTimeoutSeconds: 25,
  mode: "run"
})

// Main agent continues doing other work
// When B finishes → kill pilot fish → synthesise A + B + pilot draft
```

## Hard Limits

- **Never** use `yieldMs` > 30000 in exec calls
- **Never** call `process(action=poll, timeout > 20000)` in the main session
- **Never** add `sleep` or wait loops in the main thread
- **Always** spawn for operations with unknown or high latency
- **Max** 8 concurrent sub-sharks (avoid context explosion)

## Compatibility — Claude, Codex, Gemini CLI

The Shark Pattern is **runtime-agnostic**. Sub-sharks can be any agent type.

### OpenClaw (Claude / Sonnet / Opus)
```
sessions_spawn({
  task: "...",
  mode: "run",
  runtime: "subagent",
  runTimeoutSeconds: 30   // hard cap for pilot fish
})
```

### Codex
```
sessions_spawn({
  task: "...",
  runtime: "acp",
  agentId: "codex",
  mode: "run",
  runTimeoutSeconds: 30
})
```

### Gemini CLI
Gemini CLI is a local process — spawn via exec with a timeout:
```
exec({
  command: "gemini -p \"task description here\"",
  timeout: 30,            // hard cap in seconds
  background: true,       // don't block main agent
  yieldMs: 500            // check back quickly
})
```
For Gemini sub-tasks, use `exec` with `timeout` + `background: true` rather than `sessions_spawn`. Treat the process handle the same way — continue working, collect output when it lands.

### Mixed fleets
You can mix runtimes in the same shark run:
```
spawn sub-shark A → Codex (coding task)
spawn sub-shark B → Gemini (web search / analysis)
spawn sub-shark C → Claude subagent (reasoning)
spawn pilot fish  → Claude subagent (pre-analysis, time-bounded)
```

### Which to use when

| Task type | Best runtime |
|-----------|-------------|
| Code generation / editing | Codex |
| Web search / summarise | Gemini CLI |
| Multi-step reasoning | Claude subagent |
| File ops / SSH / shell | exec (background) |
| Pre-analysis / drafting | Claude subagent (pilot fish) |

## References

- Ralph Loop (sequential baseline): ghuntley.com/ralph/
- OpenClaw sessions_spawn docs: spawn with `mode: "run"`, `runtime: "subagent"`
- Gemini CLI: `npm install -g @google/gemini-cli`
- The name: sharks use ram ventilation — they literally die if they stop moving
