---
description: "Run a task using the Shark Pattern (non-blocking, bounded turns). Sub-commands: loop, status, clean, autotune, help"
argument-hint: "TASK_DESCRIPTION | loop TASK | status | clean | autotune | help"
---

<command-name>/shark</command-name>
<command-args>$ARGUMENTS</command-args>Base directory for this skill: $SKILL_DIR

## CRITICAL — Sub-command routing (check FIRST, before reading anything else)

**Look at the FIRST WORD of the arguments above.** If it matches a sub-command below, execute ONLY that sub-command. Do NOT read or apply the Shark Pattern skill content that follows — it is irrelevant for sub-commands.

### Sub-command: `loop`
**Pattern:** `loop <task> [--max-loops N] [--timeout S]`
**Action:** Run the shark.sh shell script. This is your ONLY job — do not manually apply the Shark Pattern.
```sh
# Linux/Mac:
SHARK_MAX_LOOPS=<N> SHARK_LOOP_TIMEOUT=<S> bash "$SKILL_DIR/shark.sh" "<task>"
```
```powershell
# Windows:
$env:SHARK_MAX_LOOPS="<N>"; $env:SHARK_LOOP_TIMEOUT="<S>"; & "$SKILL_DIR\shark.ps1" "<task>"
```
Defaults: `--max-loops 50`, `--timeout 25`. Strip the word "loop" from the args to get the task description. **STOP HERE if args start with `loop`.**

### Sub-command: `status`
Read `$SKILL_DIR/shark-exec/state/pending.json` and report active background jobs. Check `.shark-done` and `SHARK_LOG.md`. If nothing exists: "No active shark jobs." **STOP HERE.**

### Sub-command: `clean`
Remove state files: `.shark-done`, `SHARK_LOG.md`, `shark-exec/state/pending.json`. Report what was cleaned. **STOP HERE.**

### Sub-command: `autotune`
Read `$SKILL_DIR/state/timings.jsonl` and compute p50/p95 turn time, timeout rate, loops to completion, wasted headroom. Recommend optimal settings. **STOP HERE.**

### Sub-command: `help`
List available sub-commands and a brief summary of the Shark Pattern. **STOP HERE.**

---

**Only if the arguments do NOT start with a known sub-command**, treat them as a task description and apply the full Shark Pattern below:

$SKILL_CONTENT
