---
name: shark
slug: shark
version: 0.1.0
summary: "The Shark Pattern — non-blocking agent execution. Spawn remoras for slow tools, keep the main agent swimming. A shark that stops swimming dies."
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
1. Spawn a remora (`sessions_spawn` with `mode: "run"`)
2. Continue reasoning immediately
3. Incorporate remora results when they arrive

You are **never** in I/O wait. You are **always** reasoning about something.

## The Pattern

### Bad (Ralph-style blocking):
```
think → call slow tool → WAIT 60s → think → call slow tool → WAIT 45s → ...
```

### Good (Shark-style non-blocking):
```
think → spawn remora(slow tool) → think about something else
     → spawn remora(another tool) → synthesize partial results
     → receive remora result → incorporate → swim on
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

### 2. Spawn remoras

```
sessions_spawn({
  task: "Do the slow thing and return the result",
  mode: "run",
  runtime: "subagent",
  streamTo: "parent"  // optional: stream output back
})
```

Spawn multiple remoras in parallel when possible — don't serialize unless there's a data dependency.

### 3. Keep the main fin moving

After spawning, immediately continue:
- Plan the next step
- Work on a different part of the task
- Summarize what you know so far
- Prepare to incorporate results

### 4. Incorporate results

When remora results arrive, weave them in and continue. Never re-do work a remora already completed.

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
> 🦈 **Shark mode** — spawning [N] remoras for [tasks], continuing...

### Progress bar (chat-friendly, Unicode only — no images needed)

Use this format after each remora or pilot fish completes. Works in Telegram, Discord, Signal, iMessage — anywhere.

```
🦈 3 remoras · 1 pilot fish

◉ [A] task name here    ████████████ ✅ 9s
◉ [B] task name here    ████████████ ✅ 33s
○ [C] task name here    ░░░░░░░░░░░░ pending
◈ [P] Pilot fish        ██████░░░░░░ ~14s left

↳ continuing...
```

**Symbols:**
- `◉` = remora (completed)
- `○` = remora (pending)
- `⊙` = remora (running)
- `◈` = pilot fish (time-bounded)
- `████████████` = done bar (12 blocks)
- `██████░░░░░░` = partial (filled = elapsed / total budget)
- `░░░░░░░░░░░░` = not started

**Progress fill:** `filled = round(elapsed / timeout * 12)` blocks of `█`, remainder `░`

Only post an update when something changes (remora completes or pilot fish starts/ends). Don't spam — one update per event.

### Final synthesis
After all remoras done:
> 🦈 **All fins in** — synthesising [N] results + pilot draft

Then deliver the report.

## The Pilot Fish Sub-Pattern

> *Pilot fish swim alongside sharks doing prep work. When you have idle time, use it.*

When one remora returns early and others are still running:

1. **Spawn a pilot fish** — a time-bounded analysis sub-agent
2. **Give it only the partial results so far** + a hard timeout equal to the estimated remaining wait
3. **Let it pre-validate, pre-analyse, find patterns, draft conclusions**
4. **Kill it** (or it self-terminates) when the last primary remora completes
5. **Incorporate** whatever the pilot fish produced into the final synthesis

```
remora A ──────► result (early)
remora B ────────────────────────────► result
remora C ──────────────────────────────────► result

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
// remoras A (fast) and B (slow) both spawned
// A finishes in 10s, B will take another 30s

// Spawn pilot fish with 25s budget:
sessions_spawn({
  task: "Pre-analyse these results from remora A. 
         Validate the data, note any gaps, draft the structure 
         of the final report. Stop after 25 seconds.",
  runTimeoutSeconds: 25,
  mode: "run"
})

// Main agent continues doing other work
// When B finishes → kill pilot fish → synthesise A + B + pilot draft
```

## Decision Tree — When to Spawn

Before every tool call, ask: **"Will this take more than 10 seconds?"**

```
Estimated time < 10s?  → run inline
Estimated time ≥ 10s?  → spawn remora
Unknown latency?        → spawn remora (assume slow)
Data dependency on another remora? → wait, then inline
Already at 8 remoras? → queue, don't stack
```

**Always spawn:** web search/fetch, SSH, build/test, coding agents, CI triggers, API calls with unknown latency
**Always inline:** file read, memory lookup, string ops, math, local config reads

---

## Error Handling

remoras **will** fail, timeout, or return garbage. Plan for it.

### remora timeout
```
◉ [A] task    ████████████ ⏱ 30s [timeout]
```
- Treat as partial result — use whatever was returned
- Do **not** re-spawn the same task (wastes time, likely to timeout again)
- Note the gap in synthesis: "A timed out — data may be incomplete"
- If A's result is critical, spawn a smaller-scoped follow-up shark

### remora crash / error
```
◉ [A] task    ████████████ ❌ [error: connection refused]
```
- Log the error inline in the progress bar
- Continue synthesis without that result
- Mention the failure in the final report
- Optionally file an issue / alert if it's infrastructure

### Partial results (most common)
- Most useful — a remora that timed out at 28s has 28s of work in it
- Always check if partial output is usable before discarding
- Progress bar: `⏱` = timeout with partial, `❌` = hard error with nothing

### All remoras failed
- Fall back to sequential execution for the most critical task only
- Do not spawn another full fleet — you're likely hitting a systemic issue

### Pilot fish killed mid-run
- Normal and expected — whatever it produced is still useful
- Incorporate partial pilot fish output into synthesis
- Don't wait for it or re-spawn it

---

## Terminology

- **remora** = a `sessions_spawn` call with `mode: "run"`, `runtime: "subagent"`, and `runTimeoutSeconds` set. A remora is specifically a *timed* sub-agent — untimed subagents are not remoras.
- **Pilot fish** = a remora spawned *after* another remora completes, with a short timeout sized to the estimated remaining wait. Purpose: pre-analysis only, never primary work.
- **Fleet** = the full set of remoras spawned for one task
- **Fin moving** = the main agent is doing useful work (not waiting)

### `runTimeoutSeconds` — confirmed real
Verified against OpenClaw source: `runTimeoutSeconds: z.number().int().min(0).optional()` — maps to the subagent wait timeout. Use it. Hard-kills the sub-agent process after N seconds, partial output returned.

---

## Pilot Fish Sizing Formula

```
pilotFishTimeout = min(estimatedRemaining * 0.8, 25)
```

- `estimatedRemaining` = how long you think the slowest remaining remora will take
- Cap at 25s so pilot fish always finishes before the main synthesis turn
- If you don't know: use 20s as default

Example: slowest remaining remora estimated at 30s → pilot fish timeout = min(24, 25) = 24s

---

## Hard Limits

- **Never** use `yieldMs` > 30000 in exec calls — this holds the main turn hostage
- **Never** `process(action=poll, timeout > 20000)` in the main session — same reason
- **Never** add `sleep` or wait loops in the main thread
- **Always** set `runTimeoutSeconds` on remoras — unbound sub-agents are not sharks
- **Max** 8 concurrent remoras — beyond this, context overhead exceeds the gain
- **Never stack pilot fish** — one at a time, no pilot fish spawning pilot fish
- **Spawn tasks ≤ 3 sentences** — longer task descriptions need decomposition first

## Enforcing the 30-Second Timeout

The 30s cap isn't just a guideline — here's how to actually enforce it per runtime.

### OpenClaw subagents
```js
sessions_spawn({
  task: "...",
  mode: "run",
  runtime: "subagent",
  runTimeoutSeconds: 30   // hard kill after 30s — agent gets SIGTERM
})
```
`runTimeoutSeconds` is enforced by the OpenClaw runtime — the sub-agent process is killed if it exceeds it. Partial output is still returned.

### exec calls (shell, SSH, scripts)
```js
exec({
  command: "some-slow-command",
  timeout: 30,        // hard kill in seconds
  background: true,   // don't block the main agent turn
  yieldMs: 500        // poll back quickly to check
})
```
`timeout` kills the process. `background: true` means the main agent doesn't wait — it gets a session handle and can check back with `process(poll)`.

### Gemini CLI via exec
```bash
timeout 30 gemini -p "task here"
# or on Windows:
Start-Process gemini -ArgumentList '-p "task"' -Wait -Timeout 30
```
Wrap the CLI invocation with OS-level `timeout` / `Start-Process -Timeout`.

### Pilot fish — always use `runTimeoutSeconds`
```js
sessions_spawn({
  task: "pre-analyse partial results, draft structure, flag gaps",
  mode: "run",
  runTimeoutSeconds: estimatedRemainingMs / 1000,  // die before the last remora
})
```
Set it to *slightly less* than your estimated remaining wait — so the pilot fish always finishes before you need to synthesise.

### What happens when timeout fires
- Sub-agent/process is killed
- Whatever output was produced so far is returned
- Main agent treats it as a partial result — still useful for synthesis
- Log: `[timeout]` in the progress bar instead of `✅`

```
⊙ [A] slow task    ████████████ ⏱ 30s [timeout — partial result]
```

### The LLM turn itself
You can't hard-kill an LLM mid-turn, but you can:
1. **Keep prompts tight** — don't ask for exhaustive analysis in one turn
2. **Use `thinking: "none"`** for fast sub-tasks that don't need deep reasoning
3. **Break large tasks** into smaller shark-able chunks upfront

Rule of thumb: if a task description is >3 sentences, it probably needs to be split into remoras.

## Compatibility — Claude, Codex, Gemini CLI

The Shark Pattern is **runtime-agnostic**. remoras can be any agent type.

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
spawn remora A → Codex (coding task)
spawn remora B → Gemini (web search / analysis)
spawn remora C → Claude subagent (reasoning)
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

