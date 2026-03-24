---
description: "Run shark loop enforcer with a task (OS-level 25s timeout per turn)"
argument-hint: "TASK_DESCRIPTION [--max-loops N] [--timeout S]"
allowed-tools: ["Bash(bash:*)", "Bash(powershell.exe:*)"]
---

# Shark Loop (External Enforcer)

Run the shark loop enforcer script which wraps `claude --print` with a hard OS-level timeout per turn.

## Instructions

Parse the arguments:
- The main text is the TASK_DESCRIPTION
- `--max-loops N` sets SHARK_MAX_LOOPS (default: 50)
- `--timeout S` sets SHARK_LOOP_TIMEOUT in seconds (default: 25)

On Linux/Mac, run:
```sh
SHARK_MAX_LOOPS=<N> SHARK_LOOP_TIMEOUT=<S> bash "$SKILL_DIR/shark.sh" "<TASK_DESCRIPTION>"
```

On Windows (PowerShell), run:
```powershell
$env:SHARK_MAX_LOOPS = "<N>"
$env:SHARK_LOOP_TIMEOUT = "<S>"
& "$SKILL_DIR\shark.ps1" "<TASK_DESCRIPTION>"
```

Report the result when complete.
