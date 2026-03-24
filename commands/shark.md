---
description: "Run a task using the Shark Pattern (non-blocking, bounded turns). Sub-commands: loop, status, clean, autotune, help"
argument-hint: "TASK_DESCRIPTION | loop TASK | status | clean | autotune | help"
---

<command-name>/shark</command-name>
<command-args>$ARGUMENTS</command-args>Base directory for this skill: $SKILL_DIR

## Sub-command routing

Check if the first word of the arguments matches a sub-command. If it does, route to that sub-command instead of treating the full arguments as a task.

- **`loop <task> [--max-loops N] [--timeout S]`** — Run the external shark loop enforcer. On Linux/Mac: `SHARK_MAX_LOOPS=<N> SHARK_LOOP_TIMEOUT=<S> bash "$SKILL_DIR/shark.sh" "<task>"`. On Windows (PowerShell): `$env:SHARK_MAX_LOOPS="<N>"; $env:SHARK_LOOP_TIMEOUT="<S>"; & "$SKILL_DIR\shark.ps1" "<task>"`. Defaults: max-loops 50, timeout 25.
- **`status`** — Read `$SKILL_DIR/shark-exec/state/pending.json` and report active background jobs (label, command, elapsed time, whether overdue). Check `.shark-done` and `SHARK_LOG.md`. If nothing exists, report "No active shark jobs."
- **`clean`** — Remove state files: `.shark-done`, `SHARK_LOG.md`, `shark-exec/state/pending.json`. Report what was cleaned.
- **`autotune`** — Read `$SKILL_DIR/state/timings.jsonl` and compute p50/p95 turn time, timeout rate, loops to completion, wasted headroom. Recommend optimal SHARK_LOOP_TIMEOUT and SHARK_MAX_LOOPS.
- **`help`** — List available sub-commands and a brief summary of the Shark Pattern.

If the arguments do NOT start with a known sub-command, treat them as a task description and apply the full Shark Pattern below.

---

$SKILL_CONTENT
